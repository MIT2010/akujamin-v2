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

**1. Login triggers a websocket connect + channel subscribe on success —
scope corrected 2026-07-11, narrower than originally written.** The old
app's `AuthStateCubit.getProfile()` — called right after a successful
login — calls `_connectToWebsocket()`, which does `ConnectUsecase` then
`SubscribeUsecase` to a **`conf.<psychologistId>` channel specifically**
(`lib/src/core/shared/blocs/auth/auth_state_cubit.dart`, read in full) —
used for exam-confirmation/pass-fail push events that can arrive at any
time, not tied to any one screen. The login migration (feature #3)
explicitly defers this side effect — documented in its own QA file, not
silently dropped.

**Correction, found while auditing `counseling` (2026-07-11): this finding
does NOT apply to `counseling`'s own chat channel, and `counseling`'s
migration does not need to "wire this back in."** Read
`ChatStateCubit._connectToWebsocket()` in full: it calls `SubscribeUsecase`
directly, and `WebsocketDatasourceImpl.subscribe()` itself does
`await connect(); // ensure connection` before subscribing — the chat
feature opens its own websocket connection on demand, entirely
independent of whatever `auth`'s login flow does or doesn't do. The
`konseling.<voucher>` channel `counseling` subscribes to is a **different
channel** from the `conf.<psychologistId>` one this finding is actually
about. **This finding stays open and scoped exactly to
`conf.<psychologistId>`** — relevant whenever a future feature needs
app-wide, not-tied-to-one-screen push events (e.g. the exam-confirmation
flow itself, or `dashboard`'s shell-level notification handling, see
finding #6 below) — not to `counseling`, which was verified
self-contained rather than assumed to be.

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

**3. Logging interceptor leaks raw test answers and full counseling
transcripts — confirmed, not hypothetical.** Found while jointly auditing
`payment`/`test`/`counseling`/`websocket` (2026-07-10). The old app's
`LoggerInterceptor` (`lib/src/core/network/interceptors.dart`) does
`logger.d('Data: ${options.data}')` on every POST request and
`logger.d('...Data: ${response.data}')` on every response, unconditionally
— already known from `auth_login.md`'s phone/OTP finding, but this is the
first time it's confirmed to leak genuinely personal *content*, not just
credentials:
- `test`'s `saveTestAnswer` (`POST /api/pertanyaan/savev2`) sends its body
  as a **raw JSON string** (`data: param`, not `FormData`) —
  `QuestionMapper.toJson()`'s output (`kode_voucher`,
  `psikologis_id`/`pengetahuan_umums_id`, `jawaban_*_id`) is a psychological
  test answer, and it prints to the dev console **in full, per question,
  on every submit**.
- `counseling`'s `getChat` (`POST /api/chat/detail-conversation`) response
  is the **entire chat transcript** — caught by the response-side logger
  regardless of how the request itself was sent.
- `sendMessage` uses `FormData.fromMap(...)` — **✅ VERIFIED 2026-07-11,
  no longer an inference.** Read `package:dio`'s own `lib/src/form_data.dart`
  source directly: `FormData` declares no `toString()` override at all, so
  `'Data: ${options.data}'` in the old app's `LoggerInterceptor.onRequest`
  prints only `Instance of 'FormData'` for this call — the message text,
  `sender_id`, and voucher code passed in `sendMessage`'s param map are
  genuinely never reached by that log line. (`getChat`'s *response*, above,
  is still a real leak — that's a `Map`/`List` from Dio's JSON transformer,
  which *does* print its actual contents via `toString()`. Only the
  `sendMessage` *request* side is what's cleared here.)

**Already true, restated so it isn't missed**: this is automatically
avoided the moment `test`/`counseling` go through the kit's own `core`
`ApiClient` + `LoggingInterceptor` (`packages/core/lib/src/network/
interceptors/logging_interceptor.dart`), which only ever logs
method+URI, never bodies — same conclusion as `auth_login.md`, no new
code needed for *that* mechanism.

**New rule this finding adds, not previously written down anywhere:**
when `test`/`counseling` are actually migrated, **never add an ad-hoc
`print`/`debugPrint`/logger call anywhere in that feature's code that
prints a raw answer payload or chat message/transcript, even temporarily
for debugging.** The kit's `LoggingInterceptor` staying body-free doesn't
protect against a developer adding their own one-off debug print inside a
Cubit or repository while working on this feature later — that's a
distinct, easy-to-reintroduce mistake this note exists to head off before
it happens, not after.

**4. Captured face images have no explicit cleanup — mandatory fix, not
a port, when `test` is migrated.** `camera`'s `CameraDatasourceImpl.
captureImage()` returns `file.path` from `CameraController.takePicture()`
— the Flutter `camera` plugin writes this JPEG to the device's OS temp
directory by default. Read `camera`'s and `test`'s Dart source in full:
**no `File(path).delete()` or equivalent cleanup exists anywhere** after
the image is uploaded to `/api/pertanyaan/face-matchv2` (or, for
register's selfie capture, after upload). A face photo — biometric data —
sits in plaintext OS temp storage for however long the platform's own
temp-file lifecycle takes to reclaim it, not because the app decided
that's acceptable, but because nobody wrote the delete call. **Recorded
now, before `test`'s migration starts, so this isn't "discovered" again
mid-implementation**: the migrated version must delete the captured file
after a successful (or failed) upload — this is a correction migration
must make, the same category of decision as `onboarding`'s storage-tier
fix, not a faithful-port question.

**5. ✅ Resolved 2026-07-11 — `AppRouter._redirect` had no rule for a
logged-in user landing on `/`, GoRouter's default `initialLocation`.**
Same class of gap as ADR-011 (a `packages/shared` foundation issue, not
specific to any one feature) — found while wiring `feature_history` into
`apps/mobile`'s route table, but the bug itself predates that feature
entirely and affects the whole app. **Real severity, not a future edge
case**: `apps/mobile` never sets `AppRouter.router`'s `initialLocation`
(confirmed — grepped the whole app), so every cold start lands on `/`
by default; `apps/mobile` also never registers a `GoRoute` for `/` itself
(confirmed). `_redirect`'s existing rules only handled "not logged in,
not on `/login`" and "logged in, on `/login`" — neither covers "logged
in, on `/`, nothing matches `/`" — so it fell through to
`state.topRoute == null`, returned `null` (no redirect), and GoRouter's
`errorBuilder` (`NotFoundPage`) rendered instead. **Concretely: every
user who logs in, fully closes the app, and reopens it hits a 404**
(`AuthCubit._restoreCachedSession()` restores the session from
`SecureTokenStorage` correctly — the session itself was never the
problem, only where the router sends an already-restored session on the
app's default landing location).

Fixed in `packages/shared/lib/src/router/app_router.dart`'s `_redirect`:
added `if (loggedIn && matchedRoute == null && state.uri.path == '/') return
'/home';`, scoped specifically to `/` (not every unmatched location) so a
genuinely bad deep link still shows `NotFoundPage` — verified by a
dedicated regression test that the fix doesn't swallow real 404s.
**Test-first**: a failing test was written and confirmed red *before* the
fix (a route fixture matching `apps/mobile`'s real table — no `/` route —
plus an authenticated session landing on `/`, asserting `NotFoundPage`
was absent; it failed as expected against the pre-fix code), then green
after. Additionally verified with a real end-to-end simulation (real,
non-mocked `SecureTokenStorage`-backed session written *before* the only
`configureDependencies()` call in the test, a fresh `App()` boot, zero
manual `router.go()`/`setAuthenticated()` calls) — confirmed this
specific test also goes red with the fix reverted and green with it
restored, so it's proven to exercise the real bug, not something
adjacent to it. `packages/shared`'s test count: 27 → 29.

**Carry this forward**: any future router change must keep in mind that
`apps/mobile` relies on `AppRouter`'s default `initialLocation` (`/`)
rather than setting one explicitly — a genuinely equivalent fix would
also be "set `initialLocation: '/home'` (or `/login`) explicitly in
`apps/mobile`'s `AppRouter` construction," but the `_redirect`-level fix
was chosen instead because it protects every consumer of `AppRouter`
(this app and the starter kit template both), not just this one call
site. Same fix ported back to
[flutter_starter_kit](https://github.com/MIT2010/flutter-monorepo) (the
template this project was bootstrapped from) with its own ADR, since
`packages/shared`'s `AppRouter` originates there — every project
bootstrapped from the template going forward starts with the fix
already in place.

**6. Raw counseling message content is shown in system notifications —
found while auditing `counseling` (2026-07-11), out of scope for
`counseling`'s own migration, recorded now so it isn't rediscovered when
`notification`/`dashboard` shell are eventually migrated.** The old app's
`dashboard/presentation/widgets/dashboard_layout.dart` (the authenticated
shell, not yet migrated) listens **globally** — regardless of which screen
is on top — for the `sent` websocket event, and when the user isn't
currently on that exact chat page:
```dart
_showNotification(title: 'Konseling', body: payload['message'], ...);
```
`NotificationLocalServiceImpl.show()` passes that `body` straight to
`flutter_local_notifications`, which renders it in a real OS notification
— **lock screen and notification shade included**, a materially more
exposed surface than the in-app chat screen itself for what is
psychological-counseling content. This is a `dashboard`-shell +
`notification`-infrastructure concern, not `counseling`'s — `counseling`'s
own migration (this slice) has no notification code and cannot fix or
inherit this. **Recorded now, before those two are migrated, so this
isn't "discovered" again mid-implementation**: when `notification` and
the dashboard shell are eventually built, the message-content-in-notification-body
behavior needs a **conscious decision, not a faithful port** — recommended
default is a generic body ("Ada pesan baru dari psikolog"), not the raw
message text, the same category of correction as `onboarding`'s
storage-tier fix and permanent finding #4's face-image cleanup.

**7. `CameraGateway` never silently substitutes a camera — approved fix,
found during the camera prerequisite audit (2026-07-12).** The old app's
`CameraDatasourceImpl.initialize()` fell back to `cameras.first` whenever
the requested lens direction (`front`) wasn't found
(`cameras.firstWhere(..., orElse: () => cameras.first)`), and let a
genuinely camera-less device throw an uncaught `StateError` — neither
case was ever caught anywhere in the call chain (`CameraRepositoryImpl.
startDetection()` awaited `camera.initialize()` inside an `async*`
generator with no try/catch, and `FaceDetectorStateCubit.start()`'s
`.listen()` had no `onError`). For proctoring specifically, silently
analyzing the wrong camera's feed invalidates the entire mechanism
without anyone knowing — not just a UX gap. `packages/shared`'s
`CameraGateway.initialize()` now returns `Result<Failure, void>` with a
new `CameraFailure`/`CameraFailureReason` (`noCameraOnDevice`/
`requestedLensNotFound`/`permissionDenied`/`captureFailed`) added to
`core`'s sealed `Failure`; `feature_test`'s `ProctoringCubit` reacts to
any camera failure as an immediate, permanent
`ProctoringState.cameraUnavailable` — never folded into `AttentionStatus`
the way the old app's `noCamera` value was, so messaging stays accurate
per failure reason. Proven directly: `camera_gateway_impl_test.dart`
asserts the datasource's `initialize()` is never even called with the
wrong lens (`verifyNever`), not just that the right `Failure` comes back.

**8. Screenshot protection does not actually engage during the live test
in the old app — found during the camera prerequisite audit
(2026-07-12), relevant to `test`'s own migration, not fixed yet (no
`test`-taking UI exists in this repo to wire it into).** `TestPage.
initState()`'s `sl<DisableScreenshotUsecase>().call();` is commented out
in the old app's source. Three call sites *enable* screenshots back
(`test_routes.dart`'s `DoubleBackToExitWrapper.onBack`, `test_header.
dart`'s back button, `TestStatus.done`'s handler in `test_page.dart`) —
**zero live call sites disable it**. Screenshots are allowed throughout
the entire test in the shipped app, despite the anti-screenshot
infrastructure existing. Flagged now so it isn't silently re-discovered
(or worse, silently re-ported as-is) when `test`'s question/answer flow
is actually built — needs a conscious "fix, don't port" decision like
permanent finding #4, not an assumption that a commented-out line was
intentional.

---

## ✓ Resolved — `payment` status codes (was: open item above)

**Resolved 2026-07-11**, using `PMI-API.postman_collection.json`
(endpoint/request shapes only — the collection has zero saved response
examples or descriptions at any level, confirmed exhaustively) cross-read
against `payment_state_cubit.dart`'s actual branching logic.

**Correction to the original framing: this was never one ambiguous
field — it's three separate status vocabularies that got collapsed into
one question.**

| Field | Source | Confirmed values | Migrated where |
|---|---|---|---|
| `status_ujian` (flat) | `GET /tes/list-voucher` | `'Belum Tes'/'Sedang Tes'/'Konseling'/'Lulus'/'Tidak Lulus'/'Selesai'` | Already done — `feature_history`'s `TestHistoryItem.status` (plain `String`, display-only) |
| `info_registrasi.status_ujian` | `GET /tes/cek-voucher` | `'PT'`, `'TP'`, else | **This is what `_mapStatus()` actually branches on** — the real target of the original open item |
| `pembayaran.status` | `cek-voucher`'s `pembayaran` block, `GET /tes/cek-pembayaran` | only `'PAID'` confirmed | Drives the review page's success/pending split |

**`'PT'`/`'TP'`'s literal expansion remains unconfirmed** — the Postman
collection has no response examples or descriptions anywhere, so there is
no source to translate the abbreviation from, only its functional
behavior:

```
'PT'  → PaymentStatus.demography  (isi form + pilih psikolog)
'TP'  → PaymentStatus.payment     (transfer manual + upload bukti)
else  → PaymentStatus.review      (split further by pembayaran.status)
```

**Approved `StatusVoucher` enum** (final, confirmed by user 2026-07-11 —
deliberately not 1:1 with the old app's single `PaymentStatus.review`
catch-all, which itself branched again on `isSuccess` inside the UI):

```dart
enum StatusVoucher {
  needsRegistrationData, // API: 'PT'
  needsPayment,          // API: 'TP'
  underReview,           // API: else, pembayaran.status != 'PAID'
  paid,                  // API: else, pembayaran.status == 'PAID'
}
```

**Approved fix — socket disconnect asymmetry** (confirmed 2026-07-11):
the old app's `disconnectSocket()` skips `unsubscribe`+
`clearPsychologistId` specifically when `state.status ==
PaymentStatus.review`, but still tears down its local listeners and
resets its own `_socketConnected` flag — leaving the channel subscription
alive in the shared `SocketService` with nothing left listening to it.
Not a deliberate design, just an asymmetry. The migrated version always
unsubscribes and clears on dispose regardless of status, relying on
`subscribeIfNotUnsubscribed()`'s idempotency (already proven safe by
`counseling`) if the user re-enters payment later.

---

## User-facing features

| Feature | Status | Started | Done | Notes |
|---|---|---|---|---|
| `about` | Selesai (migrasi pipeline terbukti) — **markdown gap ditutup 2026-07-12**: FAQ text sekarang render lewat `AppMarkdownText`, bukan `Text` polos lagi. | 2026-07-09 | 2026-07-09 (markdown fix: 2026-07-12) | Pilot, first migrated feature. `packages/feature_about`, wired into `apps/mobile` (ADR-010: pubspec dep, `ExternalModule`, `/about` route, FAQ icon on Home). QA: [docs/qa/about.md](docs/qa/about.md) — real network + widget verification; screenshot-based proof wasn't possible in this environment (session-isolation + a `toImage()` hang, both documented there), so evidence is assertion-based against real data instead. Network-failure/empty-list paths reuse already-tested `core` code and weren't re-exercised. **Markdown rendering added 2026-07-12** as `test`'s Prasyarat A (see "Shared foundations" below) — `AppMarkdownText` built fresh in `design_system`, then wired back into `about` closing this tracked gap; proven with a dedicated widget test asserting bold syntax actually formats (`**...**` never shows as literal characters). |
| `onboarding` | Selesai (local-storage layer terbukti, kasus "tanpa UseCase" kedua) — **CATATAN: auto-tampil sebelum login (splash→onboarding→login gating dari app lama) BELUM direplikasi, hanya reachable manual dari Home; asset visual asli (logo/ikon KTP) diganti Material Icon, copy text asli dipertahankan.** | 2026-07-10 | 2026-07-10 | Second migrated feature. `packages/feature_onboarding`, wired into `apps/mobile` (ADR-010: pubspec dep, `ExternalModule`, `/onboarding` route, icon on Home). Proves `shared_preferences` (a storage tier no prior feature touched) and `CacheFailure` (declared in `core` since day one, unused until now) for the first time. **Real architectural correction, not a faithful port**: old app stored this flag in `flutter_secure_storage` (wrong tier for a non-sensitive bool per ARCHITECTURE.md §24) — migrated to `shared_preferences`. QA: [docs/qa/onboarding.md](docs/qa/onboarding.md) — real, unmocked local-storage round-trip + real widget verification; same screenshot-proof environment constraints as `about`, documented there. |
| `dashboard` | belum (partial: `account_page` + `history` tabs resolved) | — | — | Hub with 3 bottom-nav tabs (Beranda/Riwayat/Akun). **`Akun` tab (`account_page.dart`) migrated 2026-07-10** — see permanent findings above and [docs/qa/account.md](docs/qa/account.md); landed as `packages/feature_profile`'s new content, not a new package. **`Riwayat` (history) tab migrated 2026-07-11** — landed as a new package, `packages/feature_history` (not folded into `feature_profile`, since this data comes from `payment`'s `/tes/list-voucher`, not `auth`'s `/auth/me`); see [docs/qa/history.md](docs/qa/history.md). `Beranda` (home feed) tab still belum — the hub's own 3-tab bottom-nav shell (`DashboardLayout`/`CustomBottomNavBar`) is also still belum, since the kit's `apps/mobile` currently uses AppBar-icon navigation instead; migrate after `about`/`payment`/`auth` dependencies as originally planned |
| `auth` | Selesai (send-OTP + verify-OTP login, **project's first genuine "yes, UseCase is justified" case** — see below) — **CATATAN: countdown/expiry UI dan websocket-connect-on-login BELUM direplikasi (lihat catatan permanen di atas); register/KTP/selfie tetap di luar cakupan.** | 2026-07-10 | 2026-07-10 | Feature #3, foundational/highest fan-in — extends the kit's existing `authentication` package additively (new `SendOtpUseCase`/`VerifyOtpUseCase`/`OtpLoginCubit`/`OtpLoginPage`, all parallel to the existing email/password `LoginUseCase`/`LoginCubit`/`LoginPage`, which are untouched). **Resolves the open UseCase decision** (see above): both new usecases are justified by real ported validation (phone/OTP non-empty, `62` country-code prefix) from the old app's `AuthStateCubit`, not invented structure — the first two real "needs a UseCase" cases after `about`/`onboarding`'s two "doesn't" cases. `OtpLoginPage` is reached via `Navigator.push` from `LoginPage`, not a new `GoRoute` — avoids a real redirect-loop bug found in `AppRouter._redirect` (exact-match on `/login`, would reject a sibling route like `/login/otp`); `shared` was not touched. 30-test `authentication` baseline stayed exactly green, 28 tests added (58 total) — verified by name, not just count. **Extended again same day** to resolve the `dashboard`/`account_page` finding (see above): `SessionProfile` (`avatar`/`name`/`nik`) added as an entity separate from `User`, deliberately — `User` flows into `CrashReporter.setUserId`/`AnalyticsService.setUserId` (unwired today, but that's their whole purpose), and NIK must not travel there by accident. Stored alongside `User` in `SecureTokenStorage` (own key), cleared by the same `clear()` — verified with a real (non-mocked) storage backing, not assumed. `authentication` test count: 58 → 62. QA: [docs/qa/auth_login.md](docs/qa/auth_login.md) — sensitive-data checklist + real network/router/interactive-tap-through verification, including a real (not mock-server-only) login run through to `/home` with `/profile` and `/about` confirmed still reachable; [docs/qa/account.md](docs/qa/account.md) — the `SessionProfile`/NIK checklist and the real-storage clear() proof. |
| `splash` | belum | — | — | Likely folds into app bootstrap, not a full package |
| `counseling` | Selesai (session list + realtime chat thread, **first feature with a real websocket integration**) — **CATATAN: koneksi Pusher wire-level tidak diuji terhadap server sungguhan di sandbox ini (lihat docs/qa/counseling.md § Environment constraints); logika reconnect/backoff/filter event sepenuhnya diuji lewat fake gateway.** | 2026-07-11 | 2026-07-11 | Audited in full before any code (see the corrected permanent finding #1 above: chat is self-contained — `subscribe()` calls `connect()` itself, does **not** depend on `auth`'s deferred connect-on-login, which stays scoped to `conf.<psychologistId>` only), permanent finding #3's now-VERIFIED `sendMessage`/`FormData` safety, and the new permanent finding #6 (raw message content in system notifications — a `dashboard`/`notification` concern, not `counseling`'s). Markdown checked directly: **not used anywhere** in counseling. No image/attachment support exists in the old app's chat at all — confirmed by reading `ChatEntity`, `sendMessage`'s params, and `InputChatField`'s UI; nothing to migrate there. **Four approved design corrections, not faithful ports**: bounded exponential-backoff reconnect (`packages/feature_counseling/lib/src/realtime/reconnect_backoff.dart`, old app retried immediately, unconditionally, forever); explicit unsubscribe (and, if it's the last channel, disconnect) in `ChatCubit.close()` when the session hasn't ended (old app leaked the channel+socket for the rest of the app's life otherwise); the `sent`-event filter checks `kode_voucher` matches the open chat in addition to `sender_type != 'participant'` (old app only checked the latter — a latent cross-channel bug that matters here specifically because the socket gateway is a shared singleton, unlike the old app's per-feature instance); `ChatMessageStatus` only has `pending`/`sent`/`failed` — no fabricated `delivered`/`read`, since the old app's own `MessageStatus` enum with those values was purely decorative. No UseCase — all three endpoints are thin passthroughs, same conclusion as `about`/`onboarding`/`history`. `"Konseling"` on `feature_history`'s history tile now navigates to the real chat page (was a placeholder). QA: [docs/qa/counseling.md](docs/qa/counseling.md) — sensitive-data checklist for transcripts (same tier as raw test answers), the optimistic-send/echo-filter regression test, real network + real router verification. `feature_counseling` test count: 31 (new package). |
| `payment` | Selesai (voucher creation + manual bank-transfer write-path, **first feature with real camera + realtime + local-storage-fix all together**) — **CATATAN: Pusher wire-level tidak diuji terhadap server sungguhan di sandbox ini (sama seperti counseling), logika reconnect/backoff/clear-on-parent-change/disconnect-fix sepenuhnya diuji lewat fake gateway dan mock.** | 2026-07-11 | 2026-07-11 | Large, coupled with dashboard. Full endpoint/entity map done in the joint `payment`/`test`/`counseling`/`websocket` audit (2026-07-10), status-code vocabulary resolved and write-path re-audited 2026-07-11 (see "✓ Resolved" section above). `getVouchers`/`VoucherEntity` confirmed redundant with `feature_history`'s `list-voucher` read, not migrated here. `form_input` built first as a hard prerequisite (`packages/shared`+`design_system`, see "Shared foundations" below) — payment's demography step is its second real consumer. **Five approved corrections, not faithful ports**: (1) cascading-select fields clear their stale value when their parent changes (`clearDependentFields`, applied iteratively) — the old app never did, which is both a write-path data-integrity bug and a proven `DropdownButtonFormField` `AssertionError` crash; (2) `StatusVoucher` enum splits the old app's single `PaymentStatus.review` into `underReview`/`paid`; (3) socket `disconnectSocket()` always unsubscribes + clears, no "skip if review" exception, unlike the old app's asymmetry that left a channel alive in the shared gateway; (4) `PaymentLocalDataSource` uses a prefixed secure-storage key (`com.akujamin.mobile.payment_psychologist_id`), fixing the same ADR-011-class vulnerability as `SecureTokenStorage`'s own fix; (5) the captured/picked proof-of-payment image is deleted after a successful upload (best-effort), a second independent instance of permanent finding #4's class of gap, this time for a financial document. iOS/Android camera permission gap (previously flagged only under `test`'s row, zero permission strings in the old app on either platform) fixed as part of this slice — `apps/mobile`'s `Info.plist`/`AndroidManifest.xml`. No UseCase — all 9 old usecases were pure passthroughs, same conclusion as `about`/`onboarding`/`history`/`counseling`. `feature_payment` test count: 24 (new package). Full workspace: 285/285 passing. QA: [docs/qa/payment.md](docs/qa/payment.md) — sensitive-data checklist with a dedicated financial-data section (proof-of-payment photo), real DI/router wiring verification. |
| `test` | belum (partial: read-only certificate view resolved; camera/proctoring prerequisite built and tested 2026-07-12) | — | — | Largest, camera+face+websocket+screenshot — migrate last. **`certificate_page.dart` (read-only PDF viewer) migrated 2026-07-11** as part of the "Riwayat + sertifikat" slice, landed in `packages/feature_history` — see [docs/qa/history.md](docs/qa/history.md). **Markdown blocker resolved 2026-07-12**: `AppMarkdownText` built (see "Shared foundations" below), confirmed by reading `test_info_container.dart` that intro/instruction content genuinely uses markdown (`CustomMarkdownWidget`), not just question text (plain, unaffected). **Face-match endpoint conflict resolved 2026-07-12**: `test`'s own `MatchFaceUsecase`→`TestRepository.matchFace()` chain is dead code — registered in DI, never called anywhere in the presentation layer (exhaustive grep). Only `camera`'s live periodic in-stream implementation is real; migrated as `feature_test`'s `FaceMatchDatasource`, `test`'s own chain not ported. **Camera prerequisite audited and built 2026-07-12** (packages/shared's `CameraGateway` + `packages/feature_test`'s proctoring slice — see "Shared foundations" below and permanent finding #7). **Still open before the rest of `test` starts**: full flow map (TestEntity→SectionEntity→QuestionEntity→AnswerEntity structure, `saveTestAnswer` orchestration decision, screenshot-block lifecycle — a real, confirmed gap found already, see permanent finding #8) and the sensitive-data checklist (raw test answers, proctoring face images, face-match confidence scores) — Langkah 3-4 of the write-path audit, in progress. |

## Infrastructure/service features (become shared/core services, not feature packages)

| Feature | Status | Started | Done | Notes |
|---|---|---|---|---|
| `form_input` | belum | — | — | Resolved to `shared` (schema fetch) + `design_system` (`FormFieldBuilder`) — AUDIT.md §5b. `FormInputLocalService` is dead code, do not port |
| `camera` | belum | — | — | Consumed by auth (selfie) + test (proctoring). No native permission strings found for camera on either platform (native inventory, 2026-07-10) — real gap in the old app, not something to faithfully port. Captured images have no explicit temp-file cleanup — see permanent finding #4 above |
| `websocket` | belum | — | — | Consumed by counseling + test. Also connected-to right after a successful login in the old app — see the permanent findings section above before assuming this is only counseling/test's concern |
| `notification` | belum | — | — | App-wide, inited in `main` |
| `screenshot` | belum | — | — | Consumed by test only |

---

## Shared foundations extracted so far

Per the playbook's §1 "extract once" rule — track here so a later feature
doesn't re-extract the same helper:

**Design principle, made explicit 2026-07-11 (the `form_input` decision):**
"used by 2+ features" (§1) is the trigger to extract, but *when* to place
a capability in `shared`/`design_system` splits into two different
situations — the reasoning should stay consistent across future
migrations instead of being re-litigated ad-hoc each time:

- **Generic by design from day one** — the capability's own shape doesn't
  reference any one feature's domain at all. A server-driven dynamic-form
  renderer driven purely by a schema + a caller-supplied endpoint string
  is exactly as generic for `auth`'s KYC form as for `payment`'s
  pre-payment questionnaire — neither reading makes it "belong" to
  either one. `form_input` is this case: placed in `packages/shared` +
  `design_system` now, on the strength of the *design itself* being
  generic, even though only one real consumer (`payment`) is being built
  in this repo right now — the old app already proves a second unrelated
  consumer exists (`auth`'s register/KYC flow), and nothing about the
  design would change if it had one consumer instead of two.
- **Starts feature-specific, promoted only once reuse is proven** —
  `websocket`'s reconnect/backoff logic (permanent finding #1 above)
  began as `counseling`'s own self-contained gateway, deliberately *not*
  generalized into `shared` up front, because at the time only one
  feature needed it and its exact shape (channel naming, event set,
  reconnect tolerance) wasn't yet known to generalize correctly.
  `payment`'s own websocket usage (`conf.<psychologistId>`) will be the
  second consumer — extraction into `shared` should wait until that's
  actually built and the two usages' real commonality is visible, not be
  designed speculatively now.

**Rule of thumb for future migrations:** ask "does this capability's
shape reference this feature's domain, or would it read identically if
written for any other feature?" — if the latter, extract to `shared`
even with only one confirmed consumer today (like `form_input`); if the
shape is still feature-flavored and reuse is only hypothetical, keep it
self-contained until a second real consumer forces the generalization
(like `websocket` did).

| Extracted | From | Landed in | Date |
|---|---|---|---|
| `form_input` (dynamic form schema, cascading options, clear-on-parent-change) | `auth`'s register flow + `payment`'s demography step (old app) | `packages/shared` (domain/data) + `packages/design_system` (`DynamicFormField`) | 2026-07-11 |
| `AppMarkdownText` (markdown rendering) | `about`'s FAQ text + `test`'s intro/instruction content (old app's `CustomMarkdownWidget`, confirmed via `test_info_container.dart`) | `packages/design_system` (`markdown_widget`-backed, not `flutter_markdown` — verified discontinued before choosing) | 2026-07-12 |
| `CameraGateway` (initialize/captureImage/dispose/controller only — no streaming, no face detection) | `auth`'s selfie capture + `test`'s proctoring feed (old app's `CameraDatasourceImpl`) | `packages/shared` — deliberately narrow scope; the ML Kit detection wrapper and the proctoring state machine stayed in `packages/feature_test` (self-contained, zero confirmed second consumer for either — same reasoning as `websocket`) | 2026-07-12 |

---

*Started 2026-07-09, the same day this repo was bootstrapped from
[flutter_starter_kit](https://github.com/MIT2010/flutter-monorepo). See
[README.md](README.md) for the bootstrap note.*
