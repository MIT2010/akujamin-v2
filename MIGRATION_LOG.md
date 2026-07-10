# Migration log — AKUJAMIN

Concrete, per-feature tracking for migrating the 13 features found in the
legacy `akujamin-app` (see [AUDIT.md](AUDIT.md) for the full audit this
list comes from) into this repo's `packages/feature_<name>` structure.

This file is **project-specific** — status, dates, who/what's next. For
*how* to actually do each transform (the reusable recipes: `Either` →
`Result`, manual `sl.register` → `@injectable`, when a UseCase is
justified, etc.), see
[docs/MIGRATION_PLAYBOOK.md](docs/MIGRATION_PLAYBOOK.md) — that file stays
generic on purpose so it can be reused for the next migration project, not
just this one. A feature only moves to **done** here once it clears every
box in the playbook's §4 definition-of-done checklist (including the
ADR-010-style `apps/mobile` wiring and being seen rendering in the real
app — "green in its own package" is not "done").

Status values: **belum** (not started) · **proses** (in progress) ·
**selesai** (migrated + wired + verified in the running app).

---

## User-facing features

| Feature | Status | Started | Done | Notes |
|---|---|---|---|---|
| `about` | Selesai (migrasi pipeline terbukti) — **CATATAN: markdown rendering belum ada, `CustomMarkdownWidget` equivalent perlu dibangun di `packages/design_system` sebelum fitur manapun yang kontennya benar-benar pakai format markdown (cek AUDIT.md §3 — `test`/`counseling` kemungkinan butuh ini).** | 2026-07-09 | 2026-07-09 | Pilot, first migrated feature. `packages/feature_about`, wired into `apps/mobile` (ADR-010: pubspec dep, `ExternalModule`, `/about` route, FAQ icon on Home). QA: [docs/qa/about.md](docs/qa/about.md) — real network + widget verification; screenshot-based proof wasn't possible in this environment (session-isolation + a `toImage()` hang, both documented there), so evidence is assertion-based against real data instead. FAQ text currently renders as plain `Text`, not markdown — see Status column. Network-failure/empty-list paths reuse already-tested `core` code and weren't re-exercised. |
| `onboarding` | belum | — | — | Local-only (no network), leaf |
| `dashboard` | belum | — | — | Hub — consumes about/payment/auth; migrate after its dependencies |
| `auth` | belum | — | — | Foundational, highest fan-in — maps onto the kit's existing `authentication` package rather than a new one |
| `splash` | belum | — | — | Likely folds into app bootstrap, not a full package |
| `counseling` | belum | — | — | Realtime (websocket) — migrate late. **Blocker check before starting:** if its content uses markdown formatting, needs `design_system`'s markdown widget first — see `about`'s row, not yet built |
| `payment` | belum | — | — | Large, coupled with dashboard |
| `test` | belum | — | — | Largest, camera+face+websocket+screenshot — migrate last. **Blocker check before starting:** if its content uses markdown formatting, needs `design_system`'s markdown widget first — see `about`'s row, not yet built |

## Infrastructure/service features (become shared/core services, not feature packages)

| Feature | Status | Started | Done | Notes |
|---|---|---|---|---|
| `form_input` | belum | — | — | Resolved to `shared` (schema fetch) + `design_system` (`FormFieldBuilder`) — AUDIT.md §5b. `FormInputLocalService` is dead code, do not port |
| `camera` | belum | — | — | Consumed by auth (selfie) + test (proctoring) |
| `websocket` | belum | — | — | Consumed by counseling + test |
| `notification` | belum | — | — | App-wide, inited in `main` |
| `screenshot` | belum | — | — | Consumed by test only |

---

## Shared foundations extracted so far

Per the playbook's §1 "extract once" rule — track here so a later feature
doesn't re-extract the same helper:

| Extracted | From | Landed in | Date |
|---|---|---|---|
| *(none yet — first extraction happens with the pilot)* | | | |

---

*Started 2026-07-09, the same day this repo was bootstrapped from
[flutter_starter_kit](https://github.com/MIT2010/flutter-monorepo). See
[README.md](README.md) for the bootstrap note.*
