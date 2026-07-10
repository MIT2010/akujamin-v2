# Migration audit — `akujamin`

**Subject:** AKUJAMIN — psychology-test app for migrant workers
(`C:\Users\FX505G\Documents\Flutter projects\akujamin-app`)
**Date:** 2026-07-08 (Tahap 1), updated 2026-07-09 (Tahap 1 follow-up, see §5)
**Scope:** Tahap 1 audit only — read-only assessment, no code migrated.
**Snapshot:** 271 Dart files, 13 features, v1.0.5+6.

> **Bottom line up front:** this is **not** a messy legacy app — it is
> **already feature-first Clean Architecture with almost the same layer
> layout as this starter kit**. Migration is *pattern-alignment and
> repackaging*, not a rewrite. The risk is low and the per-feature recipe
> will be highly repeatable. See
> [docs/MIGRATION_PLAYBOOK.md](docs/MIGRATION_PLAYBOOK.md) for that recipe
> and [CONTRIBUTING.md](CONTRIBUTING.md) for conventions.

---

## 1. Current structure & patterns

| Dimension | What akujamin does | Maps to kit as |
|---|---|---|
| **Folder org** | Feature-first: `lib/src/features/<name>/{data/{datasources,models,repositories}, domain/{entities,repositories,usecases}, presentation/{blocs,pages,routes,widgets}}` + a `lib/src/core/` holding network/theme/shared-widgets/routes/session/usecase | **Nearly identical** to the kit's `packages/feature_*` layout. The one structural change is packaging: their single-app `lib/src/` becomes the kit's **melos monorepo packages** |
| **State mgmt** | `flutter_bloc ^9.1.1` (same major as kit) + **`equatable`** manual states. Cubits with `Init/Loading/Success/Failed` states, re-entry guards, `result.fold(...)` | Cubit pattern maps 1:1. **`equatable` → `freezed` sealed states** (ADR-005) |
| **Error handling** | **`dartz` `Either<ErrorEntity, T>`** end-to-end. `BaseApiService` wraps Dio, catches `DioException` → `ErrorHandler` → `Left(ErrorModel)`. Repos `fold` and check `data['status']` | **`Either<ErrorEntity,T>` → kit's `Result<Failure,T>`** (ADR-001, hand-rolled). `ErrorEntity/ErrorModel` → kit's `Failure` hierarchy. **The error boundary is already in the right place** (data layer), so §7 is already satisfied conceptually |
| **DI** | **`get_it` manual** — one `service_locator.dart` with `setupServices()` → 5 groups (core/api/local/repos/usecases), all `registerLazySingleton` | **Manual `sl.register…` → `@injectable`/`@LazySingleton(as:)` + injectable codegen.** Same get_it underneath (§12) |
| **HTTP** | `dio ^5.9.0` via `DioClient` + `BaseApiService.{get,post,put}Request<T>`, manual Bearer-token injection per call | → kit's **`core` `ApiClient`** (already exists; token via `AuthInterceptor` instead of per-call) |
| **Router** | `go_router ^17.0.1`, `AuthStateCubit` drives `redirect` (splash→onboarding→login gating) via `GoRouterRefreshStream(cubit.stream)` | **This is literally the kit's `AuthSession` + `AuthCubit` + `GoRouterRefreshStream` pattern already built.** Direct map |
| **Local storage** | `flutter_secure_storage ^10.0.0` (tokens), plus per-feature `*LocalService` (onboarding flag, psychologist id, test answers) | Secure storage → `authentication`'s `SecureTokenStorage` (exists). Local caches → `hive_ce`/`shared_preferences` per §24 **only where genuinely needed** |
| **Codegen** | **None** — no build_runner/freezed/json_serializable/injectable. All `fromJson` and states hand-written | Migration **introduces** freezed + json_serializable + injectable (the kit's `melos run gen` pipeline) |
| **Models** | `XModel extends XEntity` (inheritance), hand `fromJson` (maps API keys, e.g. `jenis`→`type`) | Kit uses composition (`XModel` with `toEntity()`), freezed + `@JsonKey` for renames |
| **Tests** | **None real** — see §5, checked 2026-07-09 | Migration tests are the first tests this behavior has ever had — no old-test regression baseline to lean on |

**No blockers.** Same `flutter_bloc` major, same `get_it`, same `dio`, same
`go_router`, same `flutter_secure_storage`. The deltas are all *mechanical,
repeatable transforms* — exactly what
[docs/MIGRATION_PLAYBOOK.md](docs/MIGRATION_PLAYBOOK.md) §2 documents. The
one real gap (not a blocker, but budget for it) is the total absence of
existing tests — see §5.

---

## 2. Feature inventory (13) — with risk

### User-facing features (have pages + routes)

| Feature | Files | Function | Cross-feature deps | Pilot risk |
|---|---|---|---|---|
| **splash** | 3 | Bootstrap/session-check screen | router only | n/a (no data layer — too trivial to be pilot) |
| **onboarding** | 8 | Intro carousel + "first-launch" local flag | router only (leaf) | Low, but **local-only** (no network) → unrepresentative |
| **about** | 9 | FAQ/help content — read-only `GET /api/faq/get` | **leaf** (depends on nothing); *consumed by* dashboard | **★ Lowest** |
| **dashboard** | 13 | Authenticated hub: home/account/history + nav/about/voucher blocs | consumes about + payment(voucher) + auth(profile) | High (hub) |
| **auth** | 32 | Login/OTP/register + selfie/KTP (camera+face) | **everything depends on it** | High fan-in (foundational) |
| **counseling** | 19 | Chat with psychologist — **realtime** | uses websocket | Excluded (realtime) |
| **payment** | 33 | Payment + voucher flow | coupled w/ dashboard | High (large). **§6 finding: "voucher" is not a discount code — do not treat as a small/independent sub-slice** |
| **test** | 42 | The core psych test — face-proctored, timed | uses camera+face+websocket+screenshot | Highest (migrate last) |

### Infrastructure/service features (no pages — cross-cutting)

| Feature | Files | Function | Consumed by |
|---|---|---|---|
| **camera** | 17 | Camera + ML Kit face detection | auth (selfie), test (proctoring) |
| **websocket** | 14 | Pusher realtime channels | counseling, test |
| **notification** | 9 | Local notifications (inited in `main`) | app-wide |
| **screenshot** | 6 | Anti-screenshot (test security) | test |
| **form_input** | 10 | Server-driven dynamic form schema (see §5 — resolved, was "needs closer look") | auth (register), payment |

---

## 3. Classification into the kit's four buckets

**→ `core`** (already exists — mostly **reuse/map, don't port**):
`BaseApiService`+`DioClient`+`interceptors`+`error_handler` → `ApiClient`
(exists); `Usecase<T,P>` → `UseCase` (exists); `ErrorEntity/ErrorModel` →
`Failure` (exists); `env.dart` → `Env` (exists); all `dartz Either` →
`Result`.

**→ `design_system`** (exists — merge/extend): `core/theme/*`
(colors/spacing/typography/tokens) → design_system theme;
`core/shared/widgets/*` — `AppButton`/`AppCard`/`AppTextField`/`AppDialog`/
`AppBottomSheet` already exist (map), while `page_layout`,
`dropdown_input_field`, `form_field_builder`, `custom_markdown_widget`,
`dashed_border`, `show_snack`, `loading_dialog`, `responsive_builder` are
**new additions** to design_system. `form_field_builder` is confirmed here
(not a guess) — see §5.

**→ `shared`** (exists — map): `routes/*` → `AppRouter` +
`GoRouterRefreshStream` (exists); `session/auth_session_manager` +
`shared/blocs/auth/*` → `AuthCubit`/`AuthState`/`AuthSessionAdapter`
(exists); `service_locator.dart` → DI composition root (manual →
injectable). **Service features become shared/core services, not feature
packages:** `notification`, `websocket`, `camera`+face, `screenshot`, and
**`form_input`** — confirmed in §5, not just suspected: it's consumed by
two unrelated features (auth + payment), which is exactly the "used by 2+
features" test for `shared`.

**→ `feature_<name>`** (new packages): `authentication` (map `auth` onto
the existing kit package — foundational), `feature_about` (pilot),
`feature_dashboard`/app-shell, `feature_payment`, `feature_counseling`,
`feature_test`, `feature_onboarding`. `splash` likely folds into bootstrap
rather than a full package.

---

## 4. Recommended pilot: **`about`** (FAQ / Help)

**Why `about`:**

- **Fewest dependencies of any full-stack feature** — a pure leaf (depends
  only on core network; depends on zero other features). Meets the "paling
  sedikit dependency / paling sedikit shared state" criterion decisively.
- **Simplest possible operation** — one read-only `GET /api/faq/get` →
  list. Even *simpler* than `feature_profile` (which also does PUT). For a
  **first** pilot that de-risking is a feature, not a gap.
- **Most representative migration** — despite being tiny, it exercises
  **every transform the other ~12 features need**: `dartz
  Either<ErrorEntity>` → `Result<Failure>`, `BaseApiService.getRequest` →
  `ApiClient.get`, `ErrorModel` → `Failure`, manual `sl.register` →
  `@injectable`, `equatable` entity/states → `freezed`,
  `AboutStateCubit(Init/Loading/Success/Failed)` →
  `AboutCubit(initial/loading/loaded/error)`. Proving the recipe here
  validates it for the whole queue.
- **No offline cache, no realtime, no camera/face/websocket** — matches
  "bukan yang punya cache offline/real-time."

**Two caveats flagged up front (not hidden):**

1. Old `about` is slightly *split*: its Cubit lives in `dashboard`
   (`dashboard/blocs/about`) and the `about_page` is a stateless markdown
   viewer reading route-`extra`. The migrated `feature_about` should **own
   its Cubit and render the list itself** — a small, natural cleanup that
   migration *improves*, not a complication. (In the incremental two-repo
   model this doesn't touch the still-running old app.)
2. It's **read-only**, so the pilot won't exercise the *write path* + "when
   to write a UseCase" decision (§21) — that gets proven on pilot #2 (a
   GET+POST feature). Honest tradeoff; better for the first one to be
   dead-simple.

**Rejected alternatives:** `onboarding` (least-coupled but local-only →
unrepresentative of the dominant network pattern), `splash` (no data
layer), `auth` (foundational & highest fan-in — must migrate early but is
*not* a low-risk pilot), `payment`/`test`/`counseling` (too large /
realtime / heavy device deps).

---

## 5. Follow-up (2026-07-09) — Langkah 4 findings

Two items from Tahap 1 were flagged for closer investigation before pilot
migration starts; both are now resolved.

### 5a. Test coverage: effectively zero

The entire repo has exactly **one** test file,
`test/widget_test.dart` — the unmodified `flutter create` boilerplate
counter-increment smoke test against `MyApp`, not exercising any real
feature. No other `*_test.dart` exists anywhere (the two files matching
`*test*` under `features/test/` — `audio_test.dart`, `video_test.dart` —
are the psychology-test *feature's* widgets, not test code).
`pubspec.yaml`'s `dev_dependencies` has no `mockito`/`mocktail`/coverage
tooling, and there is no `.github/workflows/` at all, so even this one
test never runs anywhere automatically.

**Implication for migration:** there is no regression baseline to diff
against. The tests written per
[docs/MIGRATION_PLAYBOOK.md](docs/MIGRATION_PLAYBOOK.md) §3's
definition-of-done are the *first* tests any of this behavior has ever
had. Correctness during migration has to be verified by manually driving
the old app side-by-side with the new one (screen by screen, input by
input), not by "the old tests still pass." Budget real QA time per
feature, especially for `auth`/`payment`/`test` where a silent behavior
change has real consequences.

### 5b. `form_input`, investigated in full

Not really a product "feature" — a small **server-driven dynamic form**
capability:

- `GetFormsUsecase.call(param: endpoint)` → `FormInputRepository.getForms`
  → `FormInputApiService` (thin `BaseApiService` wrapper) fetches a JSON
  array of field definitions (`label`, `display`, `type` ∈
  `date`/`select`/text, `validate`, `read_only`, `values` for select
  options) from a caller-supplied endpoint.
- Rendering lives in `core/shared/widgets/form_field_builder.dart`
  (already correctly placed outside the feature folder) — one
  `FormFieldBuilder` widget that switches on `type` to render a date
  picker, small dropdown (≤10 options), or a dialog-based searchable
  select/text field.
- **Consumed by two unrelated features**, which is what settles the
  classification: `auth`'s register flow (`GET /api/registrasi/profile` —
  KYC demographic fields) and `payment` (`GET /api/tes/pertanyaan` — a
  pre-payment questionnaire, not literally payment fields). Confirmed
  `shared` (data/domain/usecase side) + `design_system`
  (`FormFieldBuilder`), not its own `feature_<name>` — §3 above updated
  accordingly.
- `FormInputLocalService` is **dead code** — registered in DI
  (`service_locator.dart`) but its only method (`someMethod()`) is an
  empty stub, never called from anywhere. **Do not migrate it.**
- One real code smell worth carrying into the migrated version's design,
  not just noting: `FormFieldBuilder` takes a raw `Cubit cubit` and calls
  `cubit.setInput(...)` on it — a duck-typed dependency with no shared
  interface (`late final dynamic _cubit`) — and the per-type
  input-normalization logic (date parsing, select-value resolution) is
  duplicated near-verbatim between `RegisterStateCubit._normalizeInput`
  and `PaymentStateCubit`'s equivalent. The migrated `design_system`
  widget should take a typed `onChanged` callback instead of a raw Cubit
  reference, and the normalization logic should be extracted once (into
  the shared form service) rather than ported twice — exactly the "hidden
  shared logic dragged along per feature" trap
  [docs/MIGRATION_PLAYBOOK.md](docs/MIGRATION_PLAYBOOK.md) §1 warns about.

---

## 6. Follow-up (2026-07-10) — the "voucher" trap in `payment`

Found while mini-auditing candidates for the second pilot (see
MIGRATION_LOG.md for that decision). `payment`'s voucher usecases
(`getVouchers`/`createVoucher`/`cancelVoucher`/`checkVoucher`, 4 small
files) initially looked like a promising low-risk, real-write-path
sub-slice to extract ahead of the rest of `payment`. **They are not.**

The actual API endpoints give it away — read from
`payment_api_service.dart`, not guessed:
`createVoucher` → `POST /api/tes/create` ("create **test**"),
`cancelVoucher` → `GET /api/tes/batal-tes` ("cancel **test**"),
`checkVoucher` → `GET /api/tes/cek-voucher`. **"Voucher" is not a discount
code — it's the test-session entity itself.** `VoucherEntity`'s fields
confirm it: `psychologist`, `testAttempt`, `testResult`, `certificateUrl`.
Filed under `payment/` folder-wise, but semantically it's the entry point
into the app's core value proposition (taking the psychology test),
entangled with `test` (test attempts/results) and `counseling`
(psychologist assignment) — neither of which exist in this repo yet.

**Why this matters for future audits:** the small usecase/file count made
it *look* like a safe, leaf, independent extraction — it isn't, once you
read what the entity actually models and which endpoints it calls. File
count and usecase count are not reliable proxies for risk; check the
entity's fields and the literal API paths before trusting a "looks small"
read.

**Binding guidance for whenever `payment`/`test`/`counseling` are
audited for real migration:** treat `payment`'s voucher/test-session
concept, `test`, and `counseling` as **one entangled unit for planning
purposes**, not three independently schedulable features. Don't repeat
this mini-audit's near-mistake of treating `payment` as chooseable in
isolation just because its *own* folder's usecases look small.

---

## Reference: concrete code shapes observed

**Network base** (`core/network/base_api_service.dart`) — the crux of the
`Either`→`Result` mapping:

```dart
Future<Either<ErrorEntity, T>> getRequest<T>(String endpoint, {bool addToken = true, ...}) async {
  try {
    final response = await sl<DioClient>().get(endpoint, options: ...);
    return Right(response.data);
  } on DioException catch (e) {
    return sl<ErrorHandler<ErrorEntity, T>>().apiErrorHandler(e);
  }
}
```
→ maps to `core`'s `ApiClient.get(...)` returning `Result<Failure, T>`
(DioException→Failure conversion already lives inside `ApiClient`, and the
token moves to `AuthInterceptor`, so datasources stop passing `addToken`).

**Repository** (`about_repo_impl.dart`):

```dart
Future<Either<ErrorEntity, List<AboutEntity>>> getAbout() async {
  final result = await sl<AboutApiService>().getAbout();
  return result.fold(Left.new, (data) {
    if (data['status'] != 'ok') return Left(ErrorModel(code: 422, message: data['message']));
    final abouts = [for (var d in data['datas']) AboutModel.fromJson(d)];
    return Right(abouts);
  });
}
```
→ becomes a `Result`-returning repo whose datasource returns
`Result<Failure, List<AboutModel>>`, mapping model→entity via `toEntity()`.

**Cubit** (currently in `dashboard/blocs/about/about_state_cubit.dart`):

```dart
class AboutStateCubit extends Cubit<AboutState> {
  AboutStateCubit() : super(InitAboutState());
  void getAbout() async {
    if (state is LoadingAboutState) return;
    emit(LoadingAboutState());
    final result = await sl<GetAboutUsecase>().call();
    result.fold((error) => emit(FailedAboutState(error)), (data) => emit(SuccessAboutState(data)));
  }
}
```
→ becomes `AboutCubit` in `feature_about` with freezed sealed
`AboutState.{initial,loading,loaded,error}` and `@injectable` DI.

---

*This audit precedes any migration code. No pilot migration starts until
the recommended pilot is confirmed.*
