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

## ✅ Resolved: write-path + UseCase (§21/ADR-004) — `auth` (feature #3)

**Resolved 2026-07-10.** `auth`'s `SendOtpUseCase` and `VerifyOtpUseCase`
(send-OTP + verify-OTP login) are the first genuine "yes, this needs a
UseCase" cases in this project — both justified by real validation logic
ported from the old app's `AuthStateCubit._validatePhone()`/
`_validateOtp()` (non-empty checks, `62` country-code prefixing), not
invented to force a UseCase into existence. See `auth`'s row below and
[docs/qa/auth_login.md](docs/qa/auth_login.md). Kept below for the
history of *why* this took two features to land on real evidence.

<details>
<summary>Original open-decision text (resolved, kept for context)</summary>

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

</details>

---

## ⚠ Permanent findings — carry these into later migrations, don't rediscover them

Found while scoping `auth`'s login migration (feature #3). Same treatment
as the voucher trap (AUDIT.md §6): recorded here so they surface *before*
the relevant future migration starts, not mid-way through it.

**1. Login triggers a websocket connect + channel subscribe on success.**
The old app's `AuthStateCubit.getProfile()` — called right after a
successful login — calls `_connectToWebsocket()`, which does
`ConnectUsecase` then `SubscribeUsecase` to a
`conf.<psychologistId>` channel (`lib/src/core/shared/blocs/auth/auth_state_cubit.dart`,
read in full). **`auth` is not cleanly separable from `websocket`/`counseling`
in the old app**, even though `AUDIT.md` classifies them as three separate
concerns. The login migration (feature #3) explicitly defers this side
effect — documented in its own QA file, not silently dropped. **When
`websocket` or `counseling` is migrated later, this is the connection
point to wire back in** — check whether login's migrated version needs a
follow-up change at that point (e.g. an optional post-login hook) rather
than assuming `counseling`'s migration is fully self-contained.

**2. `dashboard/presentation/pages/account_page.dart` — ✅ Resolved
2026-07-10.** Audited in full, then migrated. Real findings: `AccountPage`
is **read-only** (avatar/name/NIK, zero `TextField`s) plus a logout
button — not an edit form. The "Ganti Password" button visible in its
source is commented-out dead code with no usecase/repository/endpoint
behind it anywhere in the old codebase (grepped, confirmed). It reads
straight from `AuthStateCubit.state.user` — the *same* `/api/auth/me`
fetch `auth`'s login (feature #3) already migrated, not a second
endpoint. Compared against the kit's synthetic `feature_profile`
(`name/email/bio/phoneNumber`, full edit form): almost no real overlap —
`bio` doesn't exist anywhere in the old app's real user data, and the
fields `AccountPage` actually shows (`avatar`, `nik`) don't exist in the
synthetic entity at all. **`feature_profile`'s content was replaced**
(package name kept) with a faithful read-only migration — see the `auth`
row below for the `SessionProfile` architecture decision this required,
and [docs/qa/account.md](docs/qa/account.md) for the full QA record.
`register`/KTP/selfie (`isRegistered` gating, `HomePage._makeProfile()`)
is a separate flow, confirmed unrelated to `AccountPage` — stays out of
scope.

---

## User-facing features

| Feature | Status | Started | Done | Notes |
|---|---|---|---|---|
| `about` | Selesai (migrasi pipeline terbukti) — **CATATAN: markdown rendering belum ada, `CustomMarkdownWidget` equivalent perlu dibangun di `packages/design_system` sebelum fitur manapun yang kontennya benar-benar pakai format markdown (cek AUDIT.md §3 — `test`/`counseling` kemungkinan butuh ini).** | 2026-07-09 | 2026-07-09 | Pilot, first migrated feature. `packages/feature_about`, wired into `apps/mobile` (ADR-010: pubspec dep, `ExternalModule`, `/about` route, FAQ icon on Home). QA: [docs/qa/about.md](docs/qa/about.md) — real network + widget verification; screenshot-based proof wasn't possible in this environment (session-isolation + a `toImage()` hang, both documented there), so evidence is assertion-based against real data instead. FAQ text currently renders as plain `Text`, not markdown — see Status column. Network-failure/empty-list paths reuse already-tested `core` code and weren't re-exercised. |
| `onboarding` | Selesai (local-storage layer terbukti, kasus "tanpa UseCase" kedua) — **CATATAN: auto-tampil sebelum login (splash→onboarding→login gating dari app lama) BELUM direplikasi, hanya reachable manual dari Home; asset visual asli (logo/ikon KTP) diganti Material Icon, copy text asli dipertahankan.** | 2026-07-10 | 2026-07-10 | Second migrated feature. `packages/feature_onboarding`, wired into `apps/mobile` (ADR-010: pubspec dep, `ExternalModule`, `/onboarding` route, icon on Home). Proves `shared_preferences` (a storage tier no prior feature touched) and `CacheFailure` (declared in `core` since day one, unused until now) for the first time. **Real architectural correction, not a faithful port**: old app stored this flag in `flutter_secure_storage` (wrong tier for a non-sensitive bool per ARCHITECTURE.md §24) — migrated to `shared_preferences`. QA: [docs/qa/onboarding.md](docs/qa/onboarding.md) — real, unmocked local-storage round-trip + real widget verification; same screenshot-proof environment constraints as `about`, documented there. |
| `dashboard` | belum (partial: `account_page` tab resolved) | — | — | Hub with 3 bottom-nav tabs (Beranda/Riwayat/Akun). **`Akun` tab (`account_page.dart`) migrated 2026-07-10** — see permanent findings above and [docs/qa/account.md](docs/qa/account.md); landed as `packages/feature_profile`'s new content, not a new package. `Beranda` (home feed) and `Riwayat` (history) tabs still belum — the hub's own 3-tab bottom-nav shell (`DashboardLayout`/`CustomBottomNavBar`) is also still belum, since the kit's `apps/mobile` currently uses AppBar-icon navigation instead; migrate after `about`/`payment`/`auth` dependencies as originally planned |
| `auth` | Selesai (send-OTP + verify-OTP login, **project's first genuine "yes, UseCase is justified" case** — see below) — **CATATAN: countdown/expiry UI dan websocket-connect-on-login BELUM direplikasi (lihat catatan permanen di atas); register/KTP/selfie tetap di luar cakupan.** | 2026-07-10 | 2026-07-10 | Feature #3, foundational/highest fan-in — extends the kit's existing `authentication` package additively (new `SendOtpUseCase`/`VerifyOtpUseCase`/`OtpLoginCubit`/`OtpLoginPage`, all parallel to the existing email/password `LoginUseCase`/`LoginCubit`/`LoginPage`, which are untouched). **Resolves the open UseCase decision** (see above): both new usecases are justified by real ported validation (phone/OTP non-empty, `62` country-code prefix) from the old app's `AuthStateCubit`, not invented structure — the first two real "needs a UseCase" cases after `about`/`onboarding`'s two "doesn't" cases. `OtpLoginPage` is reached via `Navigator.push` from `LoginPage`, not a new `GoRoute` — avoids a real redirect-loop bug found in `AppRouter._redirect` (exact-match on `/login`, would reject a sibling route like `/login/otp`); `shared` was not touched. 30-test `authentication` baseline stayed exactly green, 28 tests added (58 total) — verified by name, not just count. **Extended again same day** to resolve the `dashboard`/`account_page` finding (see above): `SessionProfile` (`avatar`/`name`/`nik`) added as an entity separate from `User`, deliberately — `User` flows into `CrashReporter.setUserId`/`AnalyticsService.setUserId` (unwired today, but that's their whole purpose), and NIK must not travel there by accident. Stored alongside `User` in `SecureTokenStorage` (own key), cleared by the same `clear()` — verified with a real (non-mocked) storage backing, not assumed. `authentication` test count: 58 → 62. QA: [docs/qa/auth_login.md](docs/qa/auth_login.md) — sensitive-data checklist + real network/router/interactive-tap-through verification, including a real (not mock-server-only) login run through to `/home` with `/profile` and `/about` confirmed still reachable; [docs/qa/account.md](docs/qa/account.md) — the `SessionProfile`/NIK checklist and the real-storage clear() proof. |
| `splash` | belum | — | — | Likely folds into app bootstrap, not a full package |
| `counseling` | belum | — | — | Realtime (websocket) — migrate late. **Blocker check before starting:** (1) if its content uses markdown formatting, needs `design_system`'s markdown widget first — see `about`'s row, not yet built; (2) see permanent findings above — login's websocket-connect-on-success side effect was deferred during `auth`'s migration and needs to be reconnected here |
| `payment` | belum | — | — | Large, coupled with dashboard |
| `test` | belum | — | — | Largest, camera+face+websocket+screenshot — migrate last. **Blocker check before starting:** if its content uses markdown formatting, needs `design_system`'s markdown widget first — see `about`'s row, not yet built |

## Infrastructure/service features (become shared/core services, not feature packages)

| Feature | Status | Started | Done | Notes |
|---|---|---|---|---|
| `form_input` | belum | — | — | Resolved to `shared` (schema fetch) + `design_system` (`FormFieldBuilder`) — AUDIT.md §5b. `FormInputLocalService` is dead code, do not port |
| `camera` | belum | — | — | Consumed by auth (selfie) + test (proctoring) |
| `websocket` | belum | — | — | Consumed by counseling + test. Also connected-to right after a successful login in the old app — see the permanent findings section above before assuming this is only counseling/test's concern |
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
