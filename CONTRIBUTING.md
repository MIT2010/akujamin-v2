# Contributing

This is one of the four docs the project is designed around
([ARCHITECTURE.md](ARCHITECTURE.md) for the design and ADRs,
[README.md](README.md) for setup and day-to-day commands,
[docs/MIGRATION_PLAYBOOK.md](docs/MIGRATION_PLAYBOOK.md) for porting legacy code, and this file for how
to work in the repo). Read the README's Prerequisites first — nothing here
works until FVM is set up and `melos run doctor` prints `FVM OK`.

---

## 1. Ground rules (the ones that bite if ignored)

- **FVM is enforced, not optional (ADR-006).** `melos run <name>` is always
  safe (fvm is baked into every script). Ad-hoc commands are not — type
  `fvm flutter …` / `fvm dart …` yourself for anything outside a melos
  script. Never a bare `flutter`/`dart`/`melos`.
- **Generated code is not committed (ADR-007).** After cloning or pulling
  anything that touches a `pubspec.yaml` or an annotated class, run
  `melos run get` then `melos run gen`. `*.freezed.dart`, `*.g.dart`,
  `*.config.dart`, `*.module.dart` are gitignored; the one exception is
  hive_ce's `*.g.yaml` schema file, which **is** committed.
- **Never bypass the data→domain error boundary (§7).** Exceptions become
  `Result<Failure, T>` at the repository and never travel above the data
  layer. Presentation pattern-matches a `Result`; it never `try/catch`es.
- **Features never import each other (§5).** Cross-feature communication
  goes through `shared` (router, DI-resolved services) or `core` (shared
  value types). Navigation between features is by route string in
  `apps/mobile`, not by one feature importing another's page.

---

## 2. Naming conventions

Follow what's already in the repo — consistency beats any individual
preference. Concretely:

| Thing | Convention | Example |
| --- | --- | --- |
| Package | `feature_<snake_case>` for features; `core`/`design_system`/`shared` for foundations | `feature_profile` |
| File | `snake_case.dart`, named after its primary class | `profile_repository_impl.dart` |
| Entity (domain) | `PascalCase`, no suffix | `Profile` |
| DTO (data) | entity name + `Model` | `ProfileModel` |
| Repository contract / impl | `XRepository` (abstract) / `XRepositoryImpl` | `ProfileRepository` / `ProfileRepositoryImpl` |
| Remote datasource | `XRemoteDataSource` | `ProfileRemoteDataSource` |
| Cubit / State | `XCubit` / `XState` (+ named union constructors) | `ProfileCubit` / `ProfileState.saving(...)` |
| UseCase | `VerbNounUseCase` | `UpdateProfileUseCase` |
| Page / View | `XPage` (DI wrapper) + `XView` (testable inner widget) | `ProfilePage` / `ProfileView` |
| DI micro-package marker | `feature_<name>_module.dart` → `configureFeature<Name>Module()` | `feature_profile_module.dart` |
| Public barrel | `<package_name>.dart` at `lib/` root, `export`-only | `feature_profile.dart` |

**Barrel discipline:** each package exposes its public API through the
`lib/<name>.dart` barrel. Internal files live under `lib/src/` and are not
exported unless they're genuinely public. The `XView` half of a page stays
**un-exported** so widget tests drive it with a fake cubit via
`BlocProvider.value` without going through `get_it` (see any feature's page).

---

## 3. Code standards

- **Effective Dart + the repo's lints.** Feature packages include
  `package:flutter_lints/flutter.yaml`; pure-Dart `core` uses
  `package:lints/recommended.yaml` plus `avoid_dynamic_calls`.
  `melos run analyze` must be clean — it's a CI gate.
- **Formatting is enforced.** `melos run format` runs
  `dart format --set-exit-if-changed` and CI fails on any diff. `melos run
  gen` auto-formats generated output so the check only ever gates
  hand-written code (ADR-008) — you don't format generated files yourself.
- **freezed 3.x syntax only (ADR-005):** `abstract class` for single-shape
  models, `sealed class` for state unions, native `switch` pattern matching
  — never `.when()`/`.map()`.
- **Widgets stay small (§36).** If `build()` scrolls, extract a private
  widget *class* (not a method — a `const` class gets its own rebuild
  optimization and its own golden test).
- **`Failure.message` is user-facing or logged, never a raw
  `exception.toString()` in a SnackBar** (§36).
- **Comments explain *why*, not *what*.** Match the density and voice of the
  surrounding code; a comment should state a constraint the code can't.

---

## 4. Adding a feature

Two routes to the same result. Either way, finish with the ADR-010 wiring —
a feature green in its own package but not wired into `apps/mobile` is
invisible to users.

### Route A — Mason brick (fast path, ADR-009)

```bash
dart pub global activate mason_cli   # once
mason get                            # once per clone
mason make feature --feature_name=settings -o .
fvm flutter pub get                  # the post-gen hook already edited workspace:
melos run gen
```

The brick scaffolds the **minimal proven slice** (entity → repository →
datasource → model → cubit → sealed state → page → repository-test
skeleton, pre-wired to `core`/`design_system`/`shared`) and its hook adds
the package to the root `workspace:` list. It **deliberately does not**
generate a UseCase, local caching, or the `apps/mobile` wiring — those are
manual decisions (see the brick's own
[README](bricks/feature/README.md)).

### Route B — by hand

Copy `feature_profile`'s structure. Use it when you're deviating from the
skeleton anyway (e.g. you know up front you need offline cache like
`feature_home`, or a UseCase).

### Either route — then, always:

1. Replace the `TODO` placeholder fields/endpoints with the real ones.
2. Add a UseCase **only if** there's real orchestration (§21/ADR-004 —
   `feature_profile`'s `UpdateProfileUseCase` is the "yes"; its
   `getProfile()` is the "no").
3. Write tests to standard: repository (success + server-failure), UseCase
   test if present, and a `bloc_test` cubit test.
4. **Wire into `apps/mobile` (ADR-010), all four:**
   - `feature_<name>: path: ../../packages/feature_<name>` in
     `apps/mobile/pubspec.yaml`
   - `ExternalModule(Feature<Name>PackageModule)` in
     `apps/mobile/lib/src/di/injection.dart`
   - a `GoRoute` in `apps/mobile/lib/src/app.dart`
   - a reachable UI entry point from an existing screen
5. `melos run gen && melos run analyze && melos run format && melos run test`
   — all green, whole workspace.
6. **Run the app** (`melos run run:dev`) and see the screen render — not
   just green tests (ADR-010).

---

## 5. Adding a new package (§3)

Don't split reflexively. A folder becomes a **top-level package** only when
at least one is true (§3):

- it's reused by **2+ features** (like `design_system`, `core`), or
- it needs an **independent release boundary** (something you might publish
  or share across apps), or
- it needs **isolated tests** that shouldn't rebuild the whole app.

Otherwise it stays a folder inside a feature (`feature_x/lib/src/widgets/`).
A one-off widget for a single screen is not a package.

When it genuinely is a package:

1. Create `packages/<name>/` with the standard layout (`lib/<name>.dart`
   barrel, `lib/src/…`, `pubspec.yaml` with `resolution: workspace`,
   `analysis_options.yaml`). Copy an existing package's `pubspec.yaml` shape.
2. Add `packages/<name>` to the root `pubspec.yaml` `workspace:` list.
3. If it participates in DI, add an `@InjectableInit.microPackage()` marker
   and fold its generated module into `apps/mobile`'s `injection.dart`
   (same as a feature).
4. Respect the dependency graph (§6): `core` and `design_system` are leaves
   (depend on nothing internal); features may depend on `core`/
   `design_system`/`shared`/`authentication` but never on each other.
5. `melos run get && melos run gen && melos run analyze && melos run test`.

---

## 6. Commits, branches, CI

- CI (`.github/workflows/ci.yaml`) runs on every `push` to `master` and
  every `pull_request`: `gen → analyze → format → test` on a clean-room
  runner. It is the source of truth — "works on my machine" is not enough
  (the ADR-008 saga is why).
- Keep generated files out of commits (they're gitignored; if `git status`
  shows a `*.freezed.dart`/`*.g.dart`, something's misconfigured).
- Don't push straight to `master` for anything non-trivial — branch, open a
  PR, let CI run.

---

## 7. Migrating legacy code

If your feature is a **port of an existing app's screen** rather than net-new,
read [docs/MIGRATION_PLAYBOOK.md](docs/MIGRATION_PLAYBOOK.md) first. It's the same "add a feature" flow
as §4 above, but with the extra step of classifying the old code
(core/design_system/shared/feature) and re-expressing its behavior — not
copying its structure — in this kit's patterns.
