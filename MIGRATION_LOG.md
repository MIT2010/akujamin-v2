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

## ⚠ Open decision: write-path + UseCase (§21/ADR-004) still untested

**Keputusan write-path + UseCase (§21/ADR-004) masih BELUM teruji di
akujamin-v2 setelah 2 fitur (`about`, `onboarding` — keduanya kasus
"tanpa UseCase").** Both landed as plain repository pass-throughs because
that's what their actual old-app usecases were (`GetAboutUsecase`,
`GetIsFirstLaunchUsecase`/`SetIsFirstLaunchUsecase` are all one-line
delegations) — a correct call each time, not an avoidance, but it means
the "yes, this needs a UseCase" branch of §21/ADR-004 has zero real
evidence in this project so far. `feature_profile` in the starter kit has
one (`UpdateProfileUseCase`), but that's a synthetic reference example,
not something proven against this app's actual legacy code.

**Mini-audit fitur #3 WAJIB memprioritaskan kandidat dengan operasi tulis
nyata yang genuinely leaf, bahkan kalau itu berarti menunggu sebagian
kecil dari fitur besar (`auth`/`payment`) siap diekstrak sendiri, bukan
terus menunda.** Concretely: the next mini-audit must treat "does this
candidate have a real network write path" as a harder constraint than
"is this candidate a whole, already-independent feature" — if no whole
feature qualifies again, actively look for an extractable slice (small
POST/PUT endpoint that's genuinely its own bounded thing a user does, not
a step embedded in a bigger flow — the `sendOTP`/voucher candidates
rejected during the onboarding mini-audit failed exactly that test, see
AUDIT.md §6) rather than reaching for another local-only or read-only
feature by default. This line exists so that decision doesn't keep
getting pushed to "next time" indefinitely.

---

## User-facing features

| Feature | Status | Started | Done | Notes |
|---|---|---|---|---|
| `about` | Selesai (migrasi pipeline terbukti) — **CATATAN: markdown rendering belum ada, `CustomMarkdownWidget` equivalent perlu dibangun di `packages/design_system` sebelum fitur manapun yang kontennya benar-benar pakai format markdown (cek AUDIT.md §3 — `test`/`counseling` kemungkinan butuh ini).** | 2026-07-09 | 2026-07-09 | Pilot, first migrated feature. `packages/feature_about`, wired into `apps/mobile` (ADR-010: pubspec dep, `ExternalModule`, `/about` route, FAQ icon on Home). QA: [docs/qa/about.md](docs/qa/about.md) — real network + widget verification; screenshot-based proof wasn't possible in this environment (session-isolation + a `toImage()` hang, both documented there), so evidence is assertion-based against real data instead. FAQ text currently renders as plain `Text`, not markdown — see Status column. Network-failure/empty-list paths reuse already-tested `core` code and weren't re-exercised. |
| `onboarding` | Selesai (local-storage layer terbukti, kasus "tanpa UseCase" kedua) — **CATATAN: auto-tampil sebelum login (splash→onboarding→login gating dari app lama) BELUM direplikasi, hanya reachable manual dari Home; asset visual asli (logo/ikon KTP) diganti Material Icon, copy text asli dipertahankan.** | 2026-07-10 | 2026-07-10 | Second migrated feature. `packages/feature_onboarding`, wired into `apps/mobile` (ADR-010: pubspec dep, `ExternalModule`, `/onboarding` route, icon on Home). Proves `shared_preferences` (a storage tier no prior feature touched) and `CacheFailure` (declared in `core` since day one, unused until now) for the first time. **Real architectural correction, not a faithful port**: old app stored this flag in `flutter_secure_storage` (wrong tier for a non-sensitive bool per ARCHITECTURE.md §24) — migrated to `shared_preferences`. QA: [docs/qa/onboarding.md](docs/qa/onboarding.md) — real, unmocked local-storage round-trip + real widget verification; same screenshot-proof environment constraints as `about`, documented there. |
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
