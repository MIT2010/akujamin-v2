# Migrating a legacy Flutter app into this starter kit

This is a **permanent, repeatable** guide — it gets used once per feature
for the whole 10–30 screen migration, not once total. Read
[../ARCHITECTURE.md](../ARCHITECTURE.md) first for the target design; this
document is only about getting *old* code into it, one feature at a time.

The migration is **feature-by-feature and incremental**. The legacy app
stays the production app until the migrated surface is large enough to cut
over — there is no big-bang rewrite. Each feature you migrate lands as a
new `packages/feature_<name>` wired into `apps/mobile`, exactly like a
brand-new feature (that's the point: after migration a feature is
indistinguishable from one written fresh).

---

## 0. The golden rule

**Migrate behavior, not structure.** You are not porting the old code's
file layout, base classes, or helpers — you are re-expressing the same
*behavior* in this kit's patterns. If a step feels like "copy the old file
and tweak imports," stop: that smuggles the old architecture in. The
reference for what the output should look like is
[`packages/feature_profile`](../packages/feature_profile) (simple CRUD) and
[`packages/feature_home`](../packages/feature_home) (CRUD + offline cache).
Open one of those side-by-side while migrating.

---

## 1. Classification checklist (run this on every old file)

Before touching a feature, sort each piece of its old code into exactly one
target. This is the same four-way split ARCHITECTURE.md §3/§5 defines,
turned into a repeatable decision:

| If the old code is… | It goes to… | Test |
| --- | --- | --- |
| Pure Dart util, extension, formatter, validator, value type — **no Flutter import** | **`core`** | Could it compile with `flutter` removed from pubspec? Then it's core. |
| A reusable widget, theme, color/spacing token, adaptive layout — UI with **no business logic or network** | **`design_system`** | Would a *different* app want this widget verbatim? Then it's design_system. |
| Network client, router, DI root, or a service used by 2+ features (analytics, crash reporting, feature flags, "current user") | **`shared`** | Do multiple features depend on it? Then it's shared, not a feature. |
| A screen + its bloc + its data access, specific to one product area | **`feature_<name>`** (new package) | Is it one bounded thing a user does? Then it's its own feature package. |

**Package-vs-folder rule (§3):** something becomes a top-level `package`
only if it's reused by 2+ features, needs an independent release boundary,
or needs isolated tests. Otherwise it stays a **folder inside a feature**
(`feature_x/lib/src/widgets/`, `.../utils/`). Don't over-split — a one-off
widget used by a single screen is not a package.

**Watch for hidden `core`/`shared` extractions.** A legacy feature almost
always drags along a `utils.dart`, a `constants.dart`, a base `ApiService`,
or a `AppColors`. Those are *not* part of the feature — pull them out to
`core`/`design_system`/`shared` **first** (or map them to what already
exists there), then migrate the feature on top. Migrating the same helper
five times, once per feature, is the most common way this goes wrong.

---

## 2. Concrete old→new pattern mappings

These are the transformations you will do over and over. Each cites the
kit's reference implementation so you're copying a proven shape, not
inventing one.

### 2a. Cubit that calls `http`/`dio` directly → repository + datasource

**Legacy shape (typical):**

```dart
class ProfileCubit extends Cubit<ProfileState> {
  final Dio dio;
  Future<void> load() async {
    emit(Loading());
    try {
      final res = await dio.get('/profile');
      emit(Loaded(Profile.fromJson(res.data)));
    } catch (e) {
      emit(Error(e.toString()));   // exception leaks straight to UI
    }
  }
}
```

**Target shape** — split into four pieces, mirroring
[`feature_profile`](packages/feature_profile):

1. **Remote datasource** (`data/datasources/`) — the only thing that knows
   the endpoint. Calls `core`'s `ApiClient`, never `dio` directly:
   ```dart
   @injectable
   class ProfileRemoteDataSource {
     final ApiClient _client;
     ProfileRemoteDataSource(this._client);
     Future<Result<Failure, ProfileModel>> getProfile() => _client.get(
       '/profile',
       parser: (json) => ProfileModel.fromJson(json as Map<String, dynamic>),
     );
   }
   ```
2. **Model** (`data/models/`) — freezed DTO with `fromJson`/`toEntity`
   (add `fromEntity`/`toJson` only if you also write it back).
3. **Repository contract** (`domain/repositories/`) — abstract, returns
   `Result<Failure, Entity>`.
4. **Repository impl** (`data/repositories/`) — `@LazySingleton(as: Contract)`,
   maps model→entity.
5. **Cubit** — depends on the repository (or a UseCase), never on
   `dio`/`http`. See 2c for whether it needs a UseCase.

`ApiClient` (`packages/core/lib/src/network/api_client.dart`) already
converts every `DioException` into a typed `Failure`, so **the datasource
and repository never write a `try/catch`** — that's the whole point of 2b.

### 2b. `try/catch` that reaches the UI → `Result<F,S>` at the data boundary

The one invariant (§7, §8): **exceptions become `Result` at the repository,
and never travel above the data layer.** Presentation code pattern-matches
a `Result`; it never catches an exception.

- Old `try/catch … emit(Error(e.toString()))` → gone. The datasource
  returns `Result<Failure, Model>` (via `ApiClient`), the repository maps it
  to `Result<Failure, Entity>`, the Cubit does
  `result.fold((failure) => emit(Error(failure)), (data) => emit(Loaded(data)))`.
- Old ad-hoc error strings → typed `Failure` subclasses from
  [`packages/core/lib/src/error/failure.dart`](../packages/core/lib/src/error/failure.dart):
  `ServerFailure(message, statusCode)`, `NetworkFailure`, `CacheFailure`,
  `ValidationFailure`, `UnauthorizedFailure`. The UI shows `failure.message`.
- `Result`/`Ok`/`Err` and `.fold`/`.isOk`/`.isErr` live in
  [`packages/core/lib/src/result/result.dart`](../packages/core/lib/src/result/result.dart)
  (§21, ADR-001 — hand-rolled, not `dartz`). Import `package:core/core.dart`
  directly in the Cubit even if the repository already pulls it in — `.fold`
  is an extension method and needs the extension in scope (§15).

### 2c. Whether a migrated Cubit method gets a UseCase (§21/ADR-004)

Do **not** reflexively create a UseCase per method just because Clean
Architecture diagrams show one. The rule:

- **Plain pass-through** (Cubit calls one repository method, no extra
  logic) → **no UseCase.** Cubit calls the repository directly. Reference:
  `feature_profile`'s `getProfile()` — the Cubit calls
  `_repository.getProfile()` and that's it.
- **Real orchestration** (combines repositories, logs analytics, applies a
  business rule, chains calls) → **UseCase.** Reference:
  `feature_profile`'s `UpdateProfileUseCase` — it calls
  `repository.updateProfile()` *and then* `analytics.logEvent('profile_updated')`
  on success, so the orchestration earns a named UseCase.

Legacy code often has a fat Cubit method doing several things; when you
migrate it, that's exactly the method that *should* become a UseCase. A
thin one shouldn't.

### 2d. State classes → freezed 3.x `sealed`/`abstract` (ADR-005)

| Legacy | Target |
| --- | --- |
| `class State extends Equatable` with manual `props` | freezed. Single-shape data → `@freezed abstract class`; a union of states (initial/loading/loaded/error) → `@freezed sealed class` matched with `switch` |
| `.when()` / `.map()` / `.maybeWhen()` (freezed 2.x) | native Dart `switch` pattern matching — freezed 3.x removed those methods (ADR-005) |
| hand-written `copyWith`, `==`, `hashCode` | generated by freezed |

Model separate UX states as separate constructors, like
`feature_profile`'s `ProfileState` (`initial`/`loading`/`loaded`/`saving`/
`error` — `saving` is split from `loading` because the UX differs).

### 2e. DI

| Legacy | Target |
| --- | --- |
| Manual `getIt.registerX(...)` / service locator setup | Annotate the class (`@injectable` for factories like Cubits/datasources, `@LazySingleton(as: Contract)` for repositories/singletons); `melos run gen` wires it. No manual registration in feature code (§12). |
| `provider` used purely for DI (not for widget-tree state) | Same — move to `@injectable` + `get_it` |
| No DI (manual `new`) | Annotate + inject |

Each migrated feature needs a **micro-package marker**
(`lib/src/di/feature_<name>_module.dart` with
`@InjectableInit.microPackage()`) — copy `feature_profile`'s. That's what
lets `apps/mobile`'s composition root discover the feature's registrations
(§12).

### 2f. Local storage & HTTP client

- **HTTP:** whatever the old app used (`http`, a raw `dio`, a custom
  `ApiService`) → `core`'s single `ApiClient`. Endpoints move into
  datasources; interceptors (auth token, retry, logging, connectivity)
  already exist in `core` and are wired once in `shared`'s `RegisterModule`.
- **Local storage:** only if the feature genuinely needs offline caching.
  Then follow `feature_home`'s §11 flow (Hive CE, write-through +
  stale-fallback-on-`NetworkFailure`-only) — **not** every migrated feature
  gets a cache. Secrets → `flutter_secure_storage` (see `authentication`);
  small flags → `shared_preferences`; structured cache → `hive_ce` (§24's
  storage-choice table). Most migrated CRUD screens need *none* of this and
  look like `feature_profile`.

---

## 3. Sensitive data during migration

Not every feature touches sensitive data, but when one does, the migration
is the highest-risk moment for it — it's exactly the point where "copy the
field into a slightly different model" quietly drops a protection the old
code had. Run this checklist on every feature that touches auth tokens,
PII, payment data, health data, biometrics, or anything else you wouldn't
want in a support-ticket screenshot.

- **Inventory before moving anything.** List every sensitive field the
  feature reads or writes (tokens, passwords, PII, payment instruments,
  biometric templates, session identifiers). If a field doesn't show up in
  this list, don't assume it's clean — grep the old code for where it's
  stored/logged/sent, then decide.
- **Storage tier must not downgrade.** Map each field to the kit's
  storage-choice table (§24 ARCHITECTURE.md): secrets → secure-storage-backed
  storage (`SecureTokenStorage` or its equivalent), non-sensitive flags →
  `shared_preferences`, structured non-secret cache → `hive_ce`. If the old
  app kept something in platform Keychain/Keystore-backed secure storage,
  the migrated version must land in the same tier — not in an unencrypted
  Hive box or `SharedPreferences`, even temporarily "to get it working."
- **Transit stays at least as strong.** Confirm the migrated datasource
  still goes through TLS-only endpoints and any certificate pinning the old
  HTTP client had configured — pinning is easy to silently drop when
  re-wiring interceptors onto `core`'s `ApiClient`.
- **Logging doesn't leak what the old app redacted.** Check the legacy
  logging interceptor for what it excluded (tokens, passwords, full card
  numbers, etc.) and make sure the migrated `AppLogger`/`LoggingInterceptor`
  redacts at least the same fields — dev-only logging is still a leak if a
  crash log or device log capture ships it.
- **Lifecycle: cleared when the old code cleared it.** If logout, session
  expiry, or account deletion wiped a field in the old app, the migrated
  `SecureTokenStorage.clear()` (or feature-specific equivalent) must wipe
  the same field. A field that lingers post-logout because it moved to a
  different storage class you forgot to clear is a regression, not a wash.
- **Third-party SDKs inherit the same bar.** If a legacy feature fed data to
  analytics/crash reporting automatically (a stack trace with a request
  body, a default PII field), the migrated `AnalyticsService`/
  `CrashReporter` implementation needs equivalent-or-better redaction — not
  "whatever the new SDK defaults to," which may capture more than the old
  one did.
- **Treat any downgrade as a blocker, not a follow-up.** For a
  regulated-domain app (ADR-003's fintech/health/gov framing), a
  sensitive-data handling gap found during migration review stops that
  feature's "done" checklist (§4 below) until it's fixed — it doesn't ship
  as a TODO.

This checklist is deliberately generic — it names *what* to verify, not any
one app's fields. Which data is actually sensitive, and which regulations
apply, is a per-project decision (typically made during the Tahap-1-style
audit) applied here feature by feature.

---

## 4. Definition of "done" for one migrated feature

A feature is **not** migrated when it compiles. It's migrated when all of
these hold — the same bar `feature_profile` had to clear, including
ADR-010's wiring requirement:

- [ ] Old code re-expressed in the kit's layers (§4 folder tree), not
      copied. No `dio`/`http`/`try-catch-to-UI`/`Equatable`-state left.
- [ ] Helpers it dragged along were extracted to `core`/`design_system`/
      `shared` (or mapped to existing ones), not duplicated into the feature.
- [ ] `packages/feature_<name>` builds and `melos run gen` produces its
      freezed/json/injectable output (generated files are **not** committed —
      ADR-007).
- [ ] Tests written to the kit's standard: repository test (success +
      server-failure), UseCase test if one exists, and a `bloc_test` cubit
      test (`feature_profile`'s tests are the reference).
- [ ] `fvm dart run tool/verify_fvm.dart` → `FVM OK`.
- [ ] `melos run analyze` clean, `melos run format` clean, `melos run test`
      green — **for the whole workspace**, not just the new package.
- [ ] **Wired into `apps/mobile` (ADR-010 — the step most likely to be
      skipped because everything above already feels "done"):**
  - [ ] `feature_<name>: path: ../../packages/feature_<name>` in
        `apps/mobile/pubspec.yaml`
  - [ ] `ExternalModule(Feature<Name>PackageModule)` in
        `apps/mobile/lib/src/di/injection.dart`
  - [ ] `GoRoute` for it in `apps/mobile/lib/src/app.dart`
  - [ ] a reachable UI entry point (a button/link from an already-reachable
        screen) — a feature the user can't navigate to is not done
- [ ] **Seen rendering in the real running app** (`melos run run:dev`, or
      `run:dev:web`) — driving the actual screen, not trusting analyze/test.
      "Green in CI" ≠ "reachable by users" (ADR-010).
- [ ] CI green on the branch, then merged.

Only when every box is checked does the feature count toward "enough
coverage to cut over."

---

## 5. Suggested order across the whole migration

- **Pilot first:** the feature with the fewest dependencies on other
  features and the least shared state — ideally a simple CRUD screen on par
  with `feature_profile`, **not** one with offline cache or realtime.
  Prove the pipeline end-to-end on something low-risk before touching
  anything load-bearing.
- **High-fan-in features last.** A feature many others depend on (auth,
  "current user", a shared cart) is high-risk to move early — migrating it
  can break everything still on the old code. Migrate leaf features first,
  work inward.
- **Extract shared foundations as you hit them, once.** The first feature
  that needs the network client forces `ApiClient`/`shared` wiring; the
  first that needs a token forces `authentication`'s storage. Do each
  extraction once, then later features reuse it.

Per-feature audit (map the old files with §1, list its cross-feature
dependencies, pick the target packages) happens **before** writing any
migration code for that feature — same as the Tahap 1 audit that precedes
the whole effort.

---

## 6. See also

- [../ARCHITECTURE.md](../ARCHITECTURE.md) — the target design and every ADR
  referenced above (esp. §21/ADR-004 UseCases, ADR-005 freezed, ADR-007
  generated files, ADR-010 wiring).
- [../CONTRIBUTING.md](../CONTRIBUTING.md) — conventions, code standards, and how
  to add a feature/package (a migrated feature follows the exact same
  "add a feature" flow once its old code is classified).
- [`packages/feature_profile`](../packages/feature_profile) — the reference
  for a migrated simple CRUD feature.
- [`packages/feature_home`](../packages/feature_home) — the reference when a
  migrated feature genuinely needs offline caching.
