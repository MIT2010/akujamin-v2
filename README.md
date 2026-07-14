# Akujamin

> Bootstrapped from
> [flutter_starter_kit](https://github.com/MIT2010/flutter-monorepo) on
> 2026-07-09 — that repo is the reusable, project-agnostic architecture
> template this one started as a snapshot of (packages, Mason brick, CI
> pipeline, all the ADRs up to the bootstrap date). This repo is now
> **independent**: its own git history, evolves on its own from here, and
> is where AKUJAMIN's actual feature migration happens. See
> [AUDIT.md](AUDIT.md) (the legacy-app audit) and
> [MIGRATION_LOG.md](MIGRATION_LOG.md) (per-feature migration tracking) for
> the AKUJAMIN-specific context; see
> [docs/MIGRATION_PLAYBOOK.md](docs/MIGRATION_PLAYBOOK.md) for the generic
> transformation recipes those two apply (inherited from the starter kit —
> keep it generic here too if you improve it, and consider upstreaming
> fixes back).

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full design (package
boundaries, dependency rules, testing strategy, ADRs) — inherited as-is
from the starter kit and still the source of truth for this repo's
architecture.

## Prerequisites

This repo **requires** [FVM](https://fvm.app/) — it is not optional tooling,
it's enforced (see ADR-006). Right after cloning, and before running
anything else:

```bash
dart pub global activate fvm    # once, if you don't have it yet
fvm use <versi-di-.fvmrc> --pin # installs + pins the exact SDK from .fvmrc
melos run doctor                # verifies the pin actually took effect
```

`melos run doctor` must print `FVM OK` before you touch anything else in
this repo. If it doesn't, fix that first — nothing downstream is trustworthy
until it does.

**Generated code (`*.freezed.dart`, `*.g.dart`, `*.config.dart`,
`*.module.dart`) isn't committed** (ADR-007) — run `melos run get` then
`melos run gen` right after cloning, or nothing will compile yet. The one
exception is hive_ce's `*.g.yaml` schema-migration files, which *are*
committed (see the `gen` row below).

**Per-flavor config (`flavors/*.json`) isn't committed either — copy the
examples before running the app for the first time:**

```bash
cp flavors/development.example.json flavors/development.json
cp flavors/staging.example.json flavors/staging.json
cp flavors/production.example.json flavors/production.json
# edit each flavors/*.json with your real API_BASE_URL/WS_HOST/WS_KEY etc.
```

`run:dev`/`run:staging`/`run:prod` (see the table below) pass the matching
file via `--dart-define-from-file`, one file per flavor instead of a long
list of individual `--dart-define` flags. The real `flavors/*.json` files
are gitignored (`flavors/*.json` except the `.example.json` templates) —
they carry real endpoints/keys, never commit them. **Keep each file's keys
in sync with `packages/core/lib/src/env/env.dart`'s `Env` class**
(`FLAVOR`/`API_BASE_URL`/`API_VERSION`/`WS_HOST`/`WS_PORT`/`WS_KEY`) — a
renamed or missing key here fails silently (the app falls back to `Env`'s
hardcoded defaults) rather than erroring, except `FLAVOR` itself, which
trips `main_staging.dart`/`main_prod.dart`'s own assert if it's ever wrong.

**`melos run <anything>` is already safe** — every script body calls
`fvm flutter`/`fvm dart` internally, so the pinned SDK is used even if you
never type `fvm` yourself. But **ad-hoc commands outside melos scripts**
(`flutter run`, a manual `flutter pub get`, etc.) are not — those still
need you to type the `fvm` prefix by hand:

```bash
fvm flutter <args>   # e.g. fvm flutter pub get, fvm flutter run
fvm dart <args>       # e.g. fvm dart format .
```

## Common tasks

All of these are `melos run <name>` — none need an `fvm` prefix, it's
already baked in (see Prerequisites above).

| Script | What it does | When to use it |
| --- | --- | --- |
| `doctor` | Verifies FVM is installed, pinned, and active | First thing after cloning; whenever something feels "off" version-wise |
| `get` | `fvm flutter pub get` — resolves the whole workspace in one step (Pub Workspaces links every `packages/*` and `apps/mobile` automatically) | After cloning, after pulling changes that touch any `pubspec.yaml`, after `clean` |
| `analyze` | `dart analyze` on every package | Before committing/pushing; CI runs it too |
| `format` | `dart format --set-exit-if-changed` on every package | Before committing; CI runs it too |
| `test` | `flutter test` on every package that has a `test/` folder | Before committing/pushing; CI runs it too |
| `gen` | Codegen (freezed/json_serializable/injectable/hive_ce), ordered so `core` rebuilds before packages that depend on it | Right after cloning (its output isn't committed — ADR-007) and after changing any `@freezed`/`@injectable`/`@JsonSerializable`/`@GenerateAdapters` class |
| `clean` | `flutter clean` on every package, through the pinned SDK | When the build feels stale/corrupted, or before a fresh `get` |
| `upgrade` | `flutter pub upgrade` — bumps deps to the newest version still allowed by `pubspec.yaml` constraints | Deliberately, never as a reflex — see `outdated` first |
| `outdated` | `flutter pub outdated` — reports packages with newer versions outside current constraints, doesn't change anything | Every quarter per §33 of ARCHITECTURE.md (Long-Term Maintenance Strategy) — **read each package's changelog before acting on this, never auto-upgrade blind** |
| `run:dev` / `run:staging` / `run:prod` | Runs `apps/mobile` with the matching flavor and entry point | Manual testing per environment — **`run:prod` talks to the real production API, don't use it for casual testing** |
| `run:dev:web` | Same as `run:dev` but forced to Chrome | Quick web-target smoke testing |

`--flavor dev|staging|prod` pairs with `-t apps/mobile/lib/main_<flavor>.dart`
and `--dart-define-from-file=flavors/<flavor>.json` — see §30 of
ARCHITECTURE.md for the full flavor story, and "Per-flavor config" above
for the JSON file setup this now depends on.

## Scaffolding a new feature (`mason make feature`)

```bash
dart pub global activate mason_cli   # once, if you don't have it yet
mason get                            # once per clone (reads mason.yaml)
mason make feature --feature_name=settings -o .
fvm flutter pub get                  # the hook already added it to workspace:
melos run gen
```

The brick generates the **minimal proven slice** (§14, ADR-009): entity →
repository contract + impl → remote datasource → Cubit → page → test
skeleton, pre-wired to `core`/`design_system`/`shared`, and the post-gen
hook adds the package to the root `workspace:` list automatically.

**It deliberately does NOT generate** a UseCase or local caching — those
are per-feature manual decisions, not boilerplate (§21/ADR-004 and §11):
`feature_profile`'s `UpdateProfileUseCase` is the reference for a justified
UseCase, `feature_home` for the offline-cache flow. Wiring into
`apps/mobile` (pubspec dependency, `GoRoute`, the generated
`Feature<Name>PackageModule` in `injection.dart`) also stays manual — see
[bricks/feature/README.md](bricks/feature/README.md).
