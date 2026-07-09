# feature

Scaffolds a new `packages/feature_<name>` following this repo's proven
Clean Architecture slice — the pattern validated manually by
`feature_home` and `feature_profile` before this brick existed (§14,
ADR-009 in the root ARCHITECTURE.md).

## Usage

From the repo root:

```bash
mason make feature --feature_name=settings -o .
```

Then, as the post-gen hook reminds you:

```bash
fvm flutter pub get   # resolve the new workspace member
melos run gen         # generate freezed/json/injectable output
```

## What it generates (and deliberately does NOT)

Generated — the minimal proven slice, ~12 files:
entity, repository contract + impl, remote datasource, model, DI
micro-package marker, Cubit + sealed State, page, barrel export,
pubspec (pre-wired to core/design_system/shared, `resolution: workspace`),
repository test skeleton. The root pubspec's `workspace:` list is updated
automatically by the post-gen hook.

NOT generated — deliberate manual decisions per feature:

- **UseCase** — only when a method really orchestrates something
  (§21/ADR-004). `feature_profile`'s `UpdateProfileUseCase` is the
  reference for when one is justified; its `getProfile()` path is the
  reference for when it isn't.
- **Local cache / offline flow** — only when the feature needs it (§11).
  `feature_home` is the reference implementation.
- **Route + composition-root wiring** — the four `apps/mobile` edits that
  make the feature actually reachable (pubspec dependency, `ExternalModule`
  in `injection.dart`, `GoRoute` in `app.dart`, and a UI entry point to
  navigate to it). This is a **mandatory separate step**, not optional
  polish: a package that's green in CI but not wired in is invisible to
  users. See **ADR-010** in the root ARCHITECTURE.md — it's the step most
  likely to be skipped precisely because everything else already looks
  "done."
