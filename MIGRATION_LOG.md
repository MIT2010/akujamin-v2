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

**✅ Resolved 2026-07-13 — `dashboard` shell (TAHAP 1-4).** The gap this
finding named — `conf.<psychologistId>`-scoped confirmation events need
to reach a listener that isn't tied to any one screen — is now closed by
`DashboardNotificationListener` (`apps/mobile`), which listens on
`packages/shared`'s app-wide `SocketGateway` (the TAHAP 1 extraction this
finding directly motivated: a dashboard-private gateway would never
receive events already flowing through `counseling`/`payment`'s shared
connection) rather than opening a connection of its own. Same
`conf.<psychologistId>` channel `payment` already subscribes to; the
dashboard listener never calls `subscribe()` itself, matching the old
app's own passive-listener architecture. See
[docs/qa/dashboard.md](docs/qa/dashboard.md) for the full verification.

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

**Re-verified and extended for `test`'s own three calls, 2026-07-12** (Langkah
3-4 of `test`'s audit) — see [docs/qa/test.md](docs/qa/test.md) §3 for the
full derivation: `getTests` and the proctoring `face-matchv2` upload are
both `FormData`-bodied, so the same `toString()` proof clears them too;
`saveTestAnswer`'s raw-`String` body remains the only leaked request. New in
that pass: the **response**-side log line is unconditional regardless of
request shape, so `face-matchv2`'s response (match result + confidence
score) and `getTests`'s response (the entire exam content) both print to
the console too — not previously called out explicitly.

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

**Update, 2026-07-15 — the "stays body-free" mechanism above is no
longer true, by explicit request, not drift.** While live-testing
against the real Development backend, request/response bodies turned
out to be genuinely useful for local debugging (e.g. reading `otp_code`
straight out of a real `send-otp` response instead of a manual
throwaway test). Asked directly whether full body logging was really
wanted given this exact finding's history — the answer was yes,
explicitly, fully aware of the tradeoff. `LoggingInterceptor` now logs
full request/response bodies (`FormData` fields/files listed by name,
not raw multipart bytes; `Map`/`List`/JSON-string bodies pretty-printed)
plus headers, status text, and per-call duration. Two things still hold:
(1) still gated by `enabled`/`Env.isDev` exactly as before — never fires
in staging/prod; (2) the `Authorization` header is still redacted even
here (`Bearer ***`) — a session token is a different risk category
(hijack) than this app's own domain data, and nothing asked for it to
be shown. **This finding's own "new rule" above (never add an ad-hoc
debug print of a raw answer/transcript) is unaffected and still stands**
— it was always about code *outside* this one shared interceptor; this
update only changes what the one, single, reviewed logging chokepoint
itself does.

**Extended for `register`, 2026-07-12** — see
[docs/qa/register.md](docs/qa/register.md) §3: `/registrasi/ktp`'s
**response** body is the extracted KTP fields themselves (full name, NIK,
address, date of birth) — the worst instance of this finding's
response-side pattern found yet, a complete national-ID field set rather
than test content or a confidence score. Same automatic mitigation
(`core`'s body-free `LoggingInterceptor`) and same "never add an ad-hoc
debug print" rule apply, with extra weight given what's at stake.

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

**Scope clarified 2026-07-12**: this finding is about `captureImage()`/
`takePicture()`'s file-writing path specifically (relevant to `register`'s
still-out-of-scope KTP+selfie flow). `test`'s own periodic proctoring
face-match is a *different* code path — `camera_repo_impl.dart`'s
`_startMatch()` reads frames directly from the in-memory `CameraImage`
live-stream buffer and never calls `captureImage()` at all, so no file is
ever written for that flow in the first place. `feature_test`'s already-built
`ProctoringGatewayImpl` was built the same way (verified: it never calls
`CameraGateway.captureImage()`), so it doesn't inherit this gap. See
[docs/qa/test.md](docs/qa/test.md) §1.

**✅ Resolved for `register`, 2026-07-12** — the gap this finding named
as still-open for `register`'s selfie capture is now fixed: the KTP photo
is deleted immediately after `/registrasi/ktp` returns (success or
failure), the selfie photo is deleted only after a successful
`/registrasi/save` submit (it's needed for both calls, so it can't be
cleaned up any earlier). Both best-effort, both proven against real temp
files, not asserted from a comment — see
[docs/qa/register.md](docs/qa/register.md) §2/§4.

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

**Expanded 2026-07-13, during the dashboard-shell audit that preceded
TAHAP 1-4: a second, broader instance of the same pattern, found in
`_handleConfirm` (the `konfirmasi.kelulusan` handler), not just
`_handleSent`.** `_handleConfirm` calls
`_showNotification(payload: payload)` with no `title`/`body` of its own —
since `isStatic` defaults `false`, this spreads the **entire raw event
payload** (`status_lulus`, and whatever else the confirmation event
carries) directly into the notification's data. Same exposed surface as
`_handleSent`'s leak, different (and in this instance, larger) content:
not just one message string, but the full event payload. Recorded here so
both halves of this finding get fixed together, not just the originally-
recorded one.

**✅ Resolved 2026-07-13 (TAHAP 4), both halves.**
`DashboardNotificationListener` (`apps/mobile`) replaces both handlers'
raw content with fixed, generic, non-derived text —
`'Ada pembaruan status kelulusan tes kamu.'` for `confirmationPassed`,
`'Kamu menerima pesan baru dari psikolog.'` for `chatSent` — routed
through `NotificationGateway` (TAHAP 2), never the payload or message
text itself. Proven directly: a widget test pushes a fake event with a
deliberately distinctive payload/message string and asserts the exact
`NotificationGateway.show()` call never contains it. `chatEnded`'s body
was already a safe static string in the old app — ported unchanged. See
[docs/qa/dashboard.md](docs/qa/dashboard.md) §3 for the full before/after.

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

**9. ✅ Resolved 2026-07-14 — `Env.apiUrl` pinned every request to a
`/v1/` path segment that doesn't exist on the real backend at all,
blocking every single migrated feature's network call. Found on the
first-ever request to the real Development backend, this deep into the
migration, because every prior "real network" test used a local
`HttpServer` double that matched the code's own (wrong) assumption
instead of the real server's routing.** `packages/core/lib/src/env/env.dart`'s
`Env.apiUrl` getter computed `'$apiBaseUrl/$apiVersion'` (`apiVersion`
defaulting to `'v1'`) — a versioned-API convention that was never derived
from the old app (`akujamin-app`'s own `env.dart`/`dio_client.dart` have
zero references to "version" anywhere, in a URL or a header) and was
never verified against a real server until a live sanity check against
`flavors/development.json`'s real backend: `GET /v1/faq/get` → 404,
`GET /api/v1/faq/get` → 404, `GET /api/faq/get` (the old app's own exact,
proven convention — see `about_api_service.dart`'s `'/api/faq/get'`) →
`200 OK` with real FAQ data. The real backend has **no API versioning
concept at all** — confirmed by its developer directly, not just inferred
from the negative test. **Fix**: `Env.apiUrl` now always includes the
real `/api` prefix, and only appends an extra version segment when
`apiVersion` is non-empty (`joinApiUrl`, unit-tested for both branches) —
`API_VERSION` stays a real key in every `flavors/*.json` (now blank, not
deleted) so a future backend version bump is a config edit, not a code
change. Blast radius of the fix itself is small (`env.dart` +
`shared/di/register_module.dart`'s `Dio(BaseOptions(baseUrl: env.apiUrl))`
are the only two call sites — every feature's datasource already goes
through the one shared `Dio` instance, §10) even though the bug's own
blast radius was total (100% of network calls, every migrated feature).
See `docs/qa/auth_login.md`/`counseling.md`/`history.md` for the
now-corrected notes on their own `/v1/`-based throwaway test evidence.

**10. ✅ Resolved 2026-07-15 (same live-backend run that found it) —
`GET /auth/me`'s real shape was neither what `UserProfileModel.fromJson`
assumed, and the mismatch crashed login uncaught rather than failing
gracefully.** First real end-to-end OTP login against the Development
backend (`flavors/development.json`), driven through the real DI graph
(`SendOtpUseCase`/`VerifyOtpUseCase`/`AuthRepositoryImpl`, no mocks) —
`send-otp` and `login-otp` both succeeded exactly as the code assumes,
but `VerifyOtpUseCase`'s internal `getProfile()` call threw
`type 'Null' is not a subtype of type 'String'` inside
`UserProfileModel.fromJson`, uncaught, because `ApiClient` (`packages/
core/lib/src/network/api_client.dart`) only catches `DioException` in
its `try`/`on` blocks — a parser/deserialization exception is not a
`DioException` and propagates straight past `_mapDioError`. **Precisely:
the crash was thrown by `id` (the first required field
`json_serializable` reads), not `role` as first suspected** — with the
envelope unwrapped incorrectly, every field the model expected was
`null` at the top level, and `id`'s cast (`json['id'] as String`) is
what `json_serializable` generates first, so it threw before `role`'s
absence ever got the chance to. `role`'s absence was still a second,
independent real bug (see below), just not the one that fired first in
this particular crash — this correction matters because it means the
mismatch was two separate wrong assumptions layered on top of each
other, not one.

Real raw `GET /auth/me` response (test account, fresh phone number,
first-ever login → backend auto-created a new user row, see below):
```json
{
  "status": "ok",
  "message": "Data ditemukan",
  "data": {
    "id": 59, "name": "USER-789233", "email": "-", "nik": "-",
    "alamat": "-", "no_telp": "6281211112222", "avatars": "",
    "birth_date": "-", "wilayah_id": "-", "wilayah_name": "-"
  },
  "is_regis": false
}
```
Concrete mismatches against `UserProfileModel.fromJson`'s assumption
(`packages/authentication/lib/src/data/models/user_profile_model.dart`,
which reads `id`/`email`/`role`/`name`/`avatars`/`nik`/`is_regis` all
flat at the top level):
- Most fields are nested one level under `data`, not flat — **except**
  `is_regis`, which really is top-level, a sibling of `data` itself, not
  inside it. A pure "just add `data`" unwrap is wrong; `is_regis` needs
  special-casing.
- `role` (`required String role` in the model) **does not appear
  anywhere in the `/auth/me` response**, nested or flat — confirmed true
  of the old app's own `UserModel` too (re-read in full: it never had a
  `role` field either). It does exist, but only inside the JWT
  `access_token` returned by
  `/auth/login-otp` (decoded payload: `{"id":59,"name":"6281211112222",
  "phone":"6281211112222","email":"-","role":"peserta","nik":"-",
  "alamat":"-","foto":null,...}`) — so real role data means decoding the
  JWT claims, not reading `/auth/me`, if a role is needed at login time.
- `id` arrives as a JSON **number** (`59`), not a string — the model's
  generated `fromJson` did `json['id'] as String`, a second independent
  cast failure once the envelope-unwrap is fixed (this is the one that
  actually threw first — see the correction above). The old app already
  handled this correctly (`json['id'].toString()`); the migrated model
  had silently dropped that conversion.
- Real response has fields the model doesn't capture at all: `no_telp`,
  `alamat`, `birth_date`, `wilayah_id`, `wilayah_name` — left uncaptured
  deliberately (nothing in the app reads them yet); add them if/when a
  feature needs them, not speculatively.
- The JWT payload uses `foto` for the photo field where `/auth/me` uses
  `avatars` — two different names for (presumably) the same concept
  across the two endpoints, not yet reconciled.
- `access_token`'s JWT confirms the previously-measured ~3600s/1hr TTL
  again (`iat`/`exp` delta = 3600, matches the sibling `"expires_in":3600`
  field) — consistent with the earlier TTL finding, not a new data point.

**Permanent backend data created by this run, for cleanup/awareness**:
phone `6281211112222` (test/dummy number, not a real person's), backend
auto-created user **id `59`** (`name: "USER-789233"`, `is_regis: false`)
on first successful OTP login — this looks like standard OTP-auth
"auto-register on first login" behavior, not a bug, but it is a real,
permanent row in the Development database now.

**Fix** (`packages/authentication`): `AuthRemoteDataSource.getProfile()`
now unwraps the real envelope itself (`{...envelope['data'], 'is_regis':
envelope['is_regis']}`) before handing a flat map to
`UserProfileModel.fromJson`, matching the old app's exact shape.
`UserProfileModel.id` gets a custom `@JsonKey(fromJson: _idFromJson)`
(`value.toString()`) instead of a bare cast, matching the old app's
`json['id'].toString()`. `role` was **removed from `UserProfileModel`
entirely** — it never belonged to this DTO — and `toEntity()` now takes
`{required String role}` as a parameter; `AuthRepositoryImpl` decodes it
from the access token's JWT payload (`_decodeRoleClaim`, a plain
base64Url + `jsonDecode` on the middle segment, no signature
verification — this app never verifies its own backend's tokens) in both
`verifyOtp` (the token it just received) and `refreshProfile` (the
currently-stored token), defaulting to `''` rather than inventing a
value if decoding ever fails. `no_telp`/`alamat`/`birth_date`/
`wilayah_*` and the `ApiClient` parser-exception-safety gap are both left
as explicitly open, separate items — not silently folded into this fix.
**Re-verified against the real backend after the fix**: the exact same
login flow that crashed now succeeds end-to-end through
`VerifyOtpUseCase` — `User(id: 59, email: -, role: peserta,
isRegistered: false)`, `SessionProfile(avatar: , name: USER-569316, nik:
-)`. Incidental finding from this second run: the placeholder display
name for this still-unregistered account changed between the two logins
(`USER-789233` → `USER-569316` for the same `id: 59`) — the backend
appears to regenerate it per session rather than persisting one, not
investigated further since nothing in the app currently depends on it
being stable. Full workspace baseline stayed green (`authentication`:
114/114, whole workspace: all green) after the fix.

**11. 🔴 OPEN, found 2026-07-15 live-backend run — backend bug, not a
migration bug: `POST /tes/create` (`createVoucher`) leaks a raw SQL
error, including internal DB host/port/database/connection-pool name, to
the client, triggered by a real unique-constraint collision in the
backend's own voucher-code generator.** Real end-to-end call through
`PaymentRepository.createVoucher()` (`packages/feature_payment`), real DI,
real Development backend, fully valid form data (fetched live from
`GET /tes/pertanyaan`, all 6 fields populated with real option codes —
`psikologi`, `pendidikan`, `negara_tujuan`, `jenis_pekerjaan`,
`asal_instansi` from that endpoint's own returned options; `kecamatan`
had **zero options returned** for this account, so a placeholder string
was used there, flagged as a separate open question below). The server
returned:
```
Proses gagal: Gagal memproses data peserta. Data Gagal Diproses,
SQLSTATE[23505]: Unique violation: 7 ERROR:  duplicate key value
violates unique constraint "peserta_pkey"
DETAIL:  Key (kode_voucher)=(U2JH8RAHQZ5YYGTE) already exists.
(Connection: db_partner, Host: 192.168.0.80, Port: 5414,
Database: pmi_assesmen, SQL: insert into "peserta" (...) values (...))
```
**Two separate real problems, not one:**
1. **Information disclosure**: the full SQL statement, bound values,
   internal DB host/port/database name, and the named connection pool
   (`db_partner`) are returned verbatim in a client-facing error message
   — this is backend infrastructure detail no client should ever see,
   confirmed backend-side (Laravel/FrankenPHP per finding #9), not
   something this app's code causes or can suppress from its side.
2. **The collision itself**: `kode_voucher` is server-generated (this
   app never supplies one), yet the generator produced a code
   (`U2JH8RAHQZ5YYGTE`) that already exists in `peserta` — either a
   weak-randomness/insufficient-entropy bug in the generator, or the
   table already has enough rows that collisions are becoming likely.
   Not something a retry-on-this-app's-side "fixes" at the root, even
   though a retry would very likely succeed (a fresh call generates a
   new candidate code).

**Confirms the request payload itself was valid**: the interpolated SQL
shows the submitted option codes were correctly resolved server-side to
their display text before the insert was attempted (`pendidikan: '01'`
→ `'Tamat SD/Sederajat'`, `negara_tujuan: '001'` → `'Malaysia'`,
`asal_instansi` → `'AGESA ASA JAYA'`, etc.) — the insert failed **only**
on the unique-constraint collision, not on any field this app sent being
rejected. Also incidentally reveals several fields this app never
submits are filled server-side from the authenticated session/API-key
context, not the request body: `email_partner`, `jenis_kelamin`,
`tujuan_tes`, `sektor_pekerjaan` all appear in the failed insert with
concrete values despite not being in `formData` at all — worth knowing
if a future feature ever needs to display or edit these.

**Corrected after retrying, 2026-07-15 same session: this is NOT a
transient random collision — it's a deterministic, permanent block for
this specific account.** Retried `createVoucher` four more times total
(once immediately, three more in a single follow-up run) across two
separate process invocations several minutes apart: **every single
attempt generated the exact same `kode_voucher=U2JH8RAHQZ5YYGTE`**, down
to the same failed-insert SQL each time. A randomly-generated code would
not repeat identically across five independent calls spanning multiple
processes — the backend's generator is deriving this code
deterministically from something stable about the account (most likely
the user id or phone number), not rolling a fresh random value per
request. That means **no retry from this app will ever succeed for this
account** — `kode_voucher=U2JH8RAHQZ5YYGTE` already exists in `peserta`
for a reason unrelated to this session's calls (a pre-existing row, seed
data, or a prior partially-completed attempt), and the deterministic
generator will keep recomputing the same colliding value every time.
Unblocking this account requires backend-side intervention (fixing the
generator's determinism, or resolving whatever already occupies that
code) — not something retried past from the client. No voucher was
created by any of the five attempts; nothing was committed to the
database.

**Definitively confirmed backend-wide, not account-specific, 2026-07-15
same session**: logged in as a **second, independent test account**
(phone `6281211113333`, backend auto-created user **id `60`**, a
different row entirely from id 59) and called `createVoucher` with a
freshly-built, valid `formData`. **Identical result: the exact same
`kode_voucher=U2JH8RAHQZ5YYGTE`, same collision, same SQL error.** Two
different user accounts producing the identical "randomly generated"
code rules out any per-account derivation (id, phone, hash of either) —
the generator is returning a fixed/stuck value regardless of who calls
it, and that value already occupies a row in `peserta`. **`POST
/tes/create` is currently broken for every account on this backend**,
not a one-off. LANGKAH 2.5 (counseling, needs an active session) and
LANGKAH 2.6 (test-taking, needs a ready voucher) are both unreachable as
a direct consequence — there is no way to obtain a working voucher on
this backend right now, from any account, until the backend developer
fixes the generator.

**Open, unrelated to the finding above**: `kecamatan`'s zero
returned options from `GET /tes/pertanyaan` — either this field
genuinely has no configured options for this backend/account yet, or its
real options are meant to come from a cascading follow-up call this
session didn't discover (the other 5 fields all returned populated
option lists from the same single call). Not investigated further here.

**12. ✅ Resolved 2026-07-16 — `SendOtpUseCase`/`VerifyOtpUseCase` never
stripped a leading `0` before prefixing the phone number with `62`,
malforming the number for the single most common way an Indonesian
phone number is actually typed.** Found via real UI testing (Claude in
Chrome against the actual Chrome browser, not the sandboxed preview —
see finding #14 below for why that distinction mattered): typing
`081211112222` into the OTP login field (the natural way, leading `0`)
produced a real `send-otp` request with `"phone_number":
"62081211112222"` — 14 digits, not the correct 13-digit
`6281211112222` — because both use cases did `'62$phone'`
unconditionally, with zero normalization of whatever the user actually
typed. **Real, severe consequence, not cosmetic**: the backend silently
accepted the malformed number (200 OK) and created a permanent account
under it. This dev backend echoes the OTP directly in its response
(no real SMS/WhatsApp delivery), which is the only reason login still
"worked" during testing — in production, with real OTP delivery, this
would send the code to a phone number that doesn't exist, breaking
login outright for most real users, not just mangling a display string.
**Fix**: a new pure function, `normalizePhoneNumber()`
(`packages/authentication/lib/src/domain/normalize_phone_number.dart`)
strips a leading `0` before prefixing with `62`, leaves a number that
already starts with `62` untouched (defensive against a pasted
already-prefixed number), and both use cases now call it instead of
inlining `'62$phone'`. **Verified two ways**: 5 new/updated unit tests
(leading `0`, no leading `0`, already-`62`, whitespace), and a live
re-run of the exact scenario that broke against the real Development
backend — `send-otp` for `081211112222` now sends
`"phone_number": "6281211112222"`, confirmed via the detailed request
logging finding #3 already added. Full workspace baseline stayed green.

**13. ✅ Resolved 2026-07-16 (two fix attempts; the first did not
actually work) — the transient `AuthInitial` loading screen threw a
caught-but-noisy "Could not navigate to initial route: '/login'"
Flutter framework exception on every render.** Found the same session
as finding #12 (browser console, real Chrome). Root cause:
`apps/mobile/lib/src/app.dart`'s `AuthInitial` branch (added
2026-07-14 to fix a real login-flash bug, see the file's own doc
comment) builds a **bare `MaterialApp`** — not `.router` like the rest
of the app — while `AuthCubit._restoreCachedSession()` is still
resolving, and only declares `home` for `"/"`. **First fix attempt
(wrong, verified only via `analyze`/`test`, never live)**: added
`initialRoute: '/'`, on the assumption that Flutter's `Navigator`
resolves its initial route from `PlatformDispatcher.defaultRouteName`
only when `initialRoute` is left unset. Re-tested live after the user
hot-restarted and a *genuinely* hard-reloaded browser (confirmed via
`read_network_requests` showing a fresh 1000+-script fetch, not a
same-origin hash-only navigation) — **the exact same exception still
fired**, proving the diagnosis was incomplete. Root-caused for real by
reading Flutter 3.44.4's own pinned SDK source
(`packages/flutter/lib/src/widgets/app.dart`,
`_WidgetsAppState._initialRouteName`):

```dart
// If window.defaultRouteName isn't '/', we should assume it was set
// intentionally via `setInitialRoute`, and should override whatever is in
// [widget.initialRoute].
String get _initialRouteName =>
    WidgetsBinding.instance.platformDispatcher.defaultRouteName != Navigator.defaultRouteName
    ? WidgetsBinding.instance.platformDispatcher.defaultRouteName
    : widget.initialRoute ?? WidgetsBinding.instance.platformDispatcher.defaultRouteName;
```

Flutter **deliberately discards `MaterialApp.initialRoute`** whenever
the browser's current URL isn't `/` — intentional deep-linking support,
not a bug in Flutter. Since this app boots straight into `#/login`
(hash routing), `initialRoute: '/'` was silently ignored every time,
and the platform's own `/login` kept getting handed to
`defaultGenerateInitialRoutes`, which still only had `home` for `/` and
kept throwing. **Effect was already harmless** (`home` renders
regardless, the fallback to `/` is silent to the user) — this was a
real but low-severity defect, fixed for console cleanliness and code
correctness, not because anything visible was broken. **Real fix**:
replaced `initialRoute: '/'` with a catch-all `onGenerateRoute` on that
same `MaterialApp`, so *any* requested route name — "/login", "/home",
whatever the browser's URL happened to be — resolves to the loading
screen instead of failing route-table lookup. Verified via
`melos run analyze` (0 issues, 13 packages), `melos run test` (all
green), and — unlike the first attempt — a genuine live re-check: two
independent hard-reloads (`Ctrl+Shift+R`, each confirmed by a fresh
1819-script DDC load and a fresh console timestamp) on `#/login`,
neither producing the exception.

**14. Environment note, not a code finding — live UI testing became
possible for the first time this session via Claude's own "Claude in
Chrome" connector (the user's real, separately-installed Chrome
browser), not the sandboxed Browser-pane preview used throughout the
rest of this session.** The sandboxed preview's Skia/CanvasKit
rendering hangs indefinitely in this specific environment (documented
repeatedly earlier in this project's session history, e.g.
`docs/qa/about.md`) — real Chrome has no such limitation and rendered
and accepted input normally. Findings #12 and #13 above were only
discoverable through actual UI interaction (typing into the phone
field the way a real user would, reading the live console) — the
DI-level "LANGKAH 1B" fallback pattern used everywhere else in this
project's live-backend testing cannot surface UI-layer bugs like these
by construction, only backend/wiring-layer ones (see findings #9-#11).

**15. ✅ Resolved 2026-07-16 — a failed email/password login (wrong
credentials, real 401) left the Login button's spinner stuck forever,
with no error SnackBar ever shown.** Found the same session as findings
#12-#13 (real Chrome, live login attempt with intentionally-wrong
credentials against the real Development backend). `LoginCubit`,
`LoginState`, and `LoginPage`'s `BlocConsumer` were all read and
confirmed correct — the bug was never reachable that far. **Root
cause**: a genuine `Future` deadlock inside
`packages/core/lib/src/network/interceptors/refresh_token_interceptor.dart`.
`RefreshTokenInterceptor` is registered on the one app-wide `Dio`
singleton (`packages/shared/lib/src/di/register_module.dart`), and its
own `onRefreshToken` callback (`tokenRefresher.refresh` →
`AuthCubit.refresh()` → `AuthRepositoryImpl.refreshToken()` →
`AuthRemoteDataSource.refreshToken()`) makes its `/auth/refresh` HTTP
call through that exact same `Dio` instance — so a 401 on `/auth/login`
triggers `onError`, which starts awaiting a single in-flight refresh via
`_refreshing ??= _refresh()`; that refresh's own `/auth/refresh` call
then also 401s, which re-enters the same interceptor's `onError` on the
same instance, which itself tries to await the very `_refreshing` Future
it is a dependency of. Neither `onError` invocation ever calls
`handler.next()/resolve()/reject()`, so Dio's request Future for
`/auth/login` never settles — never throws, never resolves — hanging
`ApiClient.post()` → `AuthRemoteDataSource.login()` →
`AuthRepositoryImpl.login()` → `LoginUseCase` → the
`await _loginUseCase(...)` line in `LoginCubit.submit()`, which is why
`result.fold(...)` is never reached and the state never leaves
`loading()`. Matches the live console evidence exactly: 401 on
`/auth/login`, then 401 on `/auth/refresh`, then total silence — no
third network call, because the interceptor is permanently parked
mid-`await`. **Fix**: added a static `_excludedPaths` set
(`/auth/login`, `/auth/refresh`, `/auth/send-otp`, `/auth/login-otp` —
endpoints that never carry an access token in the first place) checked
before the refresh branch in `onError`; `/auth/refresh` being in that
set is what actually breaks the deadlock, since the refresh call's own
401 now short-circuits straight to `handler.next(err)` instead of
re-entering the awaited-`_refreshing` branch. Also flagged, not fixed
this round: `register_module.dart`'s `Dio(BaseOptions(baseUrl: ...))`
sets no `connectTimeout`/`receiveTimeout` anywhere, which is why the
spinner hung *forever* rather than for some bounded number of seconds —
a real gap, deliberately left out of scope here since the interceptor
fix addresses the actual defect. Verified via two new regression tests
in `refresh_token_interceptor_test.dart`: one confirms `/auth/login`'s
401 never triggers a refresh attempt at all, the other reproduces the
exact re-entrant scenario end-to-end (a real second `Dio` call to
`/auth/refresh` through the same instance, also 401ing) wrapped in a
5-second `.timeout()` so a regression fails fast instead of hanging the
suite — both pass, and the deadlock test completes near-instantly, not
anywhere near its timeout. Full workspace baseline (`melos run
analyze`, `melos run test`) stayed green. **Live re-verification
confirmed 2026-07-16**: real Chrome, hard reload, login with
intentionally-wrong credentials — exactly one `POST /auth/login` call
in the console (401), no `/auth/refresh` call at all (previously always
followed by a second, also-401ing call), Login button returned to its
normal state instead of staying stuck, and a SnackBar appeared. Finding
#16 below documents a second, separate bug this same live check
surfaced.

**16. ✅ Resolved 2026-07-16 — the SnackBar shown on a failed login
always read "Session expired", even for a fresh login attempt with
wrong credentials that had never had a session to expire.** Found
during finding #15's live re-verification: the real backend's 401 body
for the wrong-credentials attempt was `{"status": "nok", "message":
"Email atau password salah"}`, but the user only ever saw the generic
"Session expired" text. Root cause:
`packages/core/lib/src/error/failure.dart`'s `UnauthorizedFailure` took
no message parameter at all (`const UnauthorizedFailure() : super
('Session expired')`), and `ApiClient._mapDioError`'s 401 branch always
constructed a bare `UnauthorizedFailure()`, discarding the response
body entirely — unlike the neighboring 500 branch, which already
extracted the server's own message via `_extractMessage`. **Fix**: gave
`UnauthorizedFailure` an optional message parameter defaulting to
`'Session expired'` (a super parameter, `[super.message = 'Session
expired']`, so every existing `const UnauthorizedFailure()` call site
in tests keeps its old behavior unchanged), and made the 401 branch
pass `_extractMessage(e.response?.data) ?? 'Session expired'` through
the same way the 500 branch already did. A genuinely expired session on
a protected endpoint (401 body with no message) still falls back to the
generic text; a 401 that does carry a specific reason — wrong
credentials or otherwise — now shows that reason instead. Two new
`api_client_test.dart` cases cover both paths. Full workspace baseline
(`melos run analyze`, `melos run test`) stayed green.

**17. ✅ Resolved 2026-07-16 — four high-priority gaps from a full
akujamin-app vs akujamin-v2 comparison audit, each a real, user-visible
capability loss rather than a cosmetic simplification.** The audit
(design system, navigation/auth-gating, and the four highest-risk
features — auth/payment/test/counseling — each explored in depth and
cross-checked against current source, not just against this log) is
summarized in a published report; these four findings were the ones
flagged "sangat direkomendasikan" and fixed the same session:

- **OTP resend/countdown had no counterpart at all.** `OtpLoginState`
  already carried `expiresAt`, but the screen never rendered a
  countdown or a resend control — a delayed/failed first SMS left the
  user with no way to retry from that screen. Fixed with a
  self-contained `_ResendCountdown` widget (own `Timer`, ticks off
  `expiresAt`) and a new `OtpLoginCubit.resendOtp()` that updates
  `expiresAt` in place without emitting the disruptive `sendingOtp`
  state (commit `6c3fb15`).
- **Resuming a payment with an already-uploaded proof skipped the
  server call entirely.** The old app's `PaymentStateCubit.
  submitPayment` always calls `/tes/kirim-pembayaran` in this case too,
  passing a null file — if that endpoint does anything server-side
  beyond storing a file, this app silently never triggered it. Fixed by
  making `sendPayment`'s `imagePath` nullable end to end and making the
  network call in `submitPayment` unconditional (commit `04d351f`).
- **No early-warning signal during proctoring's 2–10s grace window.**
  `ProctoringCubit` already emitted `showWarning` at 2s, but nothing
  rendered it — the only feedback was `ViolationOverlay`'s full-screen
  block at 10s, giving a drifting participant zero chance to self-
  correct before a violation was recorded. Fixed with a persistent
  `ProctoringStatusIndicator` icon plus a one-shot `BlocListener` toast
  on the rising edge, matching the old app's `BlinkingFaceStatus` +
  `showSnack` pair (commit `1bdc738`).
- **The mandatory first-launch onboarding gate wasn't replicated.** The
  old app's router forces every not-yet-logged-in route to
  `/onboarding` on a genuine first launch — including the real
  camera/KTP consent copy on its last slide — before a guest ever
  reaches `/login`. This app only ever reached `/onboarding` manually,
  from an already-authenticated Home icon, meaning a real first-time
  user never saw it. Fixed with a new `FirstLaunchGate` abstraction in
  `shared` (same cross-package pattern as `AuthSession`), adapted by
  `feature_onboarding`'s existing `OnboardingLocalDataSource`; `AppRouter.
  _redirect` now gates on it exactly while `!loggedIn && isFirstLaunch`
  (commit `09b6ac8`).

All four verified via new unit/widget tests (cubit-level and, for the
onboarding gate, a real fully-DI-wired app-boot test proving an unseeded
first launch actually lands on the carousel) plus a full workspace
baseline (`melos run gen`/`analyze`/`test`) after each. Not fixed this
round, deliberately deferred as lower-priority per the audit: the design
system's color/typography/token/asset gap (needs real brand assets, not
something to synthesize), and the cosmetic per-screen styling losses
(branded page header, dashed upload border, colored history-card status).

**18. ✅ Resolved 2026-07-16 — `ApiClient` (`packages/core`) only ever
caught `DioException` in all five methods, leaving finding #10's actual
root cause open for every endpoint except the one it was found on.**
Finding #10 fixed the crash in `UserProfileModel` alone, explicitly
leaving "the `ApiClient` parser-exception-safety gap" open as a separate
item at the time. Any other endpoint whose real response shape doesn't
match its model's assumption — not yet exercised against a real backend
— would crash the exact same uncaught way. **Fix**: every method
(`get`/`post`/`put`/`delete`/`multipart`) now has a second `catch (e)`
clause around the `parser` call, converting `TypeError`/
`FormatException`/anything else non-`DioException` into
`Result.Err(ParsingFailure)` — a new `Failure` subtype — instead of
letting it propagate. The message keeps the underlying exception's own
description for logs/diagnostics; safe to do since that text originates
entirely from this app's own Dart type-cast machinery, never from the
response body (unlike finding #11's raw-SQL disclosure, which is the
opposite problem). Seven new `api_client_test.dart` cases prove every
method converts a parser exception into a handleable `Result` instead of
crashing. Full workspace baseline stayed green.

**19. ✅ Resolved 2026-07-17, found from live web testing — `Image.file`
crashed outright on Flutter Web, hit first in the register flow's
selfie preview, confirmed by grep to also exist in payment's
bukti-pembayaran preview.** `Image.file` asserts `!kIsWeb` internally
(`packages/flutter/lib/src/widgets/image.dart:545`) and throws
`"Image.file is not supported on Flutter Web"` — both
`register_page.dart`'s `_CameraOrPreview` (selfie, after
`SelfieCameraCubit`/`camera` package captures it) and
`payment_method_view.dart` (bukti pembayaran, after `image_picker`
picks it) built `Image.file(File(path))` unconditionally, with no
`kIsWeb` branch at all. On web, `path` was never a real filesystem path
to begin with — the `camera` and `image_picker` packages' own web
implementations hand back an `XFile` backed by a `blob:` URL. **Fix**: a
new `LocalImagePreview` widget in `design_system`
(`src/widgets/media/local_image_preview.dart`) — `Image.network(path)`
on web (a `blob:` URL loads the same way an `http(s):` one does),
`Image.file(File(path))` everywhere else — replacing both call sites.
`kIsWeb` is a compile-time constant fixed by the test runner's target
(the Dart VM, never the web compiler), so the web branch itself can't be
exercised by `flutter test`; two new tests cover the native branch
(path/fit/dimensions all render correctly), with the web-branch gap
named explicitly in both the widget's doc comment and the test file
rather than faked. Full workspace baseline stayed green.

**20. ✅ Resolved 2026-07-17, found from a live web registration submit
— `dart:io`'s `File` was still being read/deleted directly at four call
sites, throwing `"Unsupported operation: _Namespace"` the instant any of
them actually ran on Flutter Web.** Finding #19 fixed the `Image.file`
*build-time* crash (an assertion hit while widgets render); this is the
same root defect's *runtime* half — `dart:io`'s filesystem classes are
stub implementations on web that throw the moment any real method is
invoked, and `path` is a `blob:` URL there to begin with (the `camera`/
`image_picker` packages' own web implementations), never a real
filesystem path. Grepping the same pattern class after the reported
crash found it in four places, not one: `authentication`'s
`resize_image.dart` (`resizeImageBytes`, called from KTP-scan
preprocessing) and `register_cubit.dart`'s `submit()` both read the
selfie via `File(path).readAsBytes()`; `register_cubit.dart`'s
`_deleteFileQuietly` and `feature_payment`'s `payment_cubit.dart`'s
`_cleanupProofImage` both called `File(path).exists()`/`.delete()` for
best-effort local cleanup; `feature_payment`'s
`payment_remote_datasource.dart` uploaded the proof-of-payment image via
`MultipartFile.fromFile(imagePath)`, which reads through `dart:io`
internally the same way. **Fix**: the two read call sites now use
`XFile(path).readAsBytes()` (`package:cross_file`, re-exported by
`image_picker`) — `dart:io`'s `File` under the hood on native, a
`blob:`-URL fetch on web — and the upload call site now reads bytes the
same way and sends them via `MultipartFile.fromBytes` instead of
`.fromFile`. The two best-effort cleanup call sites are now `kIsWeb`-
guarded no-ops on web: there is no local file to delete there at all
(the browser garbage-collects the blob on its own once nothing
references it), so the correct fix is to skip the attempt entirely, not
to catch the exception it would throw. Two new test files
(`resize_image_test.dart`, `payment_remote_datasource_test.dart`) prove
the `XFile`/`fromBytes` behavior against real temp files; all existing
tests exercising these call sites on the native/VM test environment
(where `XFile` delegates straight to `dart:io.File`) continued passing
unchanged. Full workspace baseline stayed green.

**21. ✅ Resolved 2026-07-17, found from live testing — two separate bugs
reported together: a successful registration submit didn't reach Home
(landed back on the selfie step instead), and a 404 from `GET
/tes/cek-voucher` left the payment page loading forever.**

*Registration nav.* `RegisterCubit.submit()`'s success branch called
`_refreshRegisteredFlag()` — which emits a new `AuthState` through
`AuthCubit.setAuthenticated()` — *before* emitting `RegisterStatus.
success`. `AppRouter`'s `refreshListenable`
(`GoRouterRefreshStream.notifyListeners()`, called unconditionally on
every stream event, no diffing) fires on that `AuthState` emission,
triggering a `go_router` redirect re-evaluation while still on
`/register` — before the page had a chance to pop. That rebuilt
`RegisterPage` from scratch mid-flow, resetting straight back to its
default state (the selfie step) instead of ever reaching
`Navigator.pop(true)`. **Fix**: reordered — `success` is emitted first
(popping the page essentially immediately, since `emit()`+stream
delivery is microtask-speed with no real I/O), and the best-effort
profile refresh runs after, unaffected by the reorder since it was
already fire-and-forget by design. A new regression test observes the
cubit's own emission order relative to the `refreshProfile()` call (not
just the final state) — confirmed to fail against the pre-fix ordering
before being locked in.

*Payment 404.* `PaymentCubit._checkVoucher()`'s failure branch only set
`isFailed`/`error`, never touching `step` — which defaults to, and on
failure stayed at, `PaymentStep.checking` forever. `PaymentView`'s
`BlocBuilder` only rebuilds `when p.step != c.step`, so the screen
stayed on the loading spinner permanently; a `SnackBar` (driven by
`isFailed`/`error`, which *did* change) flashed the error message once,
easy to miss, with nothing else on screen ever changing. A 404
specifically means "no voucher exists yet for this user" — mirrored
from the old app's `PaymentStateCubit.initialize()`, which calls
`_checkVoucher` with `showError: false` and then unconditionally falls
through to `loadForms()` (→ `PaymentStatus.demography`) whenever the
check didn't resolve to an existing voucher's status. **Fix**: a 404
`ServerFailure` now moves `step` to `PaymentStep.demography` and loads
the form schema, same as the existing `needsRegistrationData` path.
Scoped to 404 specifically (not every failure, unlike the old app) — a
genuine 500/network error still surfaces as `isFailed` instead of
silently sending the user into a form that will just fail the same way
on submit; a new test locks in that narrower boundary too. Full
workspace baseline stayed green.

**22. ✅ Resolved 2026-07-17, found from live testing — a reactive token
refresh (`RefreshTokenInterceptor`) had nothing to show the user while
it was in flight, and no protection stopping `AppRouter` from
redirecting to `/login` mid-refresh.** `AuthCubit.refresh()` — the
`TokenRefresher` callback `RefreshTokenInterceptor.onRefreshToken`
calls on a real 401 (see finding under the `auth` row for the original
wiring) — used to leave `AuthState` completely untouched for the
duration of the call: only a *failed* refresh ever emitted anything
(`forceLogout()` → `unauthenticated`, correctly routing to `/login`),
but a *successful* one was indistinguishable from any other silent
background request — nothing told the user a refresh was happening,
and nothing stopped whatever screen they were on from rendering its
own now-stale, paused-request state in the meantime. **Fix**: a new
`AuthState.refreshing(User, {SessionProfile?})` variant, carrying the
exact session that was live right before the refresh started (not
discarded). `AuthCubit.refresh()` now emits it immediately, then
restores `authenticated(user, sessionProfile)` on success — a genuine
failure still only ever reaches `unauthenticated` through the existing
`forceLogout()` path, untouched by this fix.
`AuthSessionAdapter._toStatus` maps `refreshing` to `isAuthenticated:
true` (same as `authenticated`), so `AppRouter` never redirects away
from the current screen just because a refresh is in flight — only a
genuine failure's later `unauthenticated` emission does that.
`apps/mobile/lib/src/app.dart`'s top-level `BlocBuilder` gates on
`AuthRefreshing` the same way it already did on `AuthInitial` (the
existing cold-boot splash), showing that same loading screen while
waiting instead of whatever the current route's own paused state
looked like. Proven at three levels: a cubit-level test observing the
exact emission order (`refreshing` → `authenticated`) relative to the
mocked `refreshToken()` call; an `AuthSessionAdapter` test confirming
`isAuthenticated` never dips to `false` mid-refresh; and a full-DI
integration test (`apps/mobile/test/refresh_token_flow_test.dart`,
already exercising the real interceptor chain against a fake HTTP
adapter) extended to assert the same emission sequence through the
genuine `RefreshTokenInterceptor` → `AuthCubit` wiring, not just a
mocked unit. Full workspace baseline stayed green.

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
| `dashboard` | Selesai (2026-07-13, TAHAP 1-4) — 3-tab bottom-nav shell + global socket-event notification handling, the last piece of the dashboard hub | 2026-07-13 | 2026-07-13 | **`Akun` tab (`account_page.dart`) migrated 2026-07-10** — see permanent findings above and [docs/qa/account.md](docs/qa/account.md); landed as `packages/feature_profile`'s new content. **`Riwayat` (history) tab migrated 2026-07-11** — `packages/feature_history`, see [docs/qa/history.md](docs/qa/history.md). **Shell + `Beranda` tab + global notification handling completed 2026-07-13**, in four separately-committed, CI-verified stages: (TAHAP 1) websocket gateway extracted from `feature_counseling`/`feature_payment` into `packages/shared` (`SocketGateway`) — a functional prerequisite, not a style preference, since the old app's own dashboard handlers never call `subscribe()` themselves, only react to channels other features already opened; (TAHAP 2) `NotificationGateway` built in `packages/shared`, real fix for the old app's discarded-permission-request-result bug (`Err(permissionDenied)` instead of calling the plugin regardless), `cancelAll()` wired into `AuthCubit.logout()` as the single authoritative call site; (TAHAP 3) `AppRouter.shellRoutes`/`AppShell` (infrastructure `shared` already shipped, unused until now) wired into `apps/mobile` — `/home`/`/history`/`/profile` behind a persistent 3-tab bottom-nav matching `CustomBottomNavBar`, test-first (a widget test captured `HomeView`'s pre-existing duplicate AppBar icons, confirmed green, *then* the icons were removed and the same test updated); (TAHAP 4) `DashboardNotificationListener` (`apps/mobile`, wraps `MaterialApp.router` rather than `AppShell` — see [docs/qa/dashboard.md](docs/qa/dashboard.md) §4(a) for why that distinction matters) ports `_handleConfirm`/`_handleSent`/`_handleEnded`, resolving permanent finding #1 (the `conf.<psychologistId>` connect-on-login gap) and permanent finding #6 (raw notification content, expanded during this work to cover `_handleConfirm`'s full-payload-spread alongside `_handleSent`'s raw message — both now generic text through `NotificationGateway`). QA: [docs/qa/dashboard.md](docs/qa/dashboard.md). **Beranda tab's actual body content resolved 2026-07-14, during the reconciliation audit (LANGKAH 1-3):** TAHAP 3 above only ported the shell/AppBar-icon layer — `HomeView`'s body was still the starter-kit's generic demo home-feed (`HomeCubit`/`HomeItem`/Hive), confirmed via `git log` plus a direct `flutter_starter_kit` template comparison to predate every real migration decision in this repo, not something derived from the old app at all (verified before deleting, not assumed). Replaced with the old app's real `dashboard/home_page.dart` content — profile teaser (avatar/name from `SessionProfile`, falling back to email) plus a `!isRegistered` "lengkapi profil" banner routing to `/register`, reading straight from `AuthCubit.state` (no repository/datasource of its own, same pattern as `account.md`); the entire unused `HomeCubit`/`HomeItem`/`HomeRepository`/Hive stack was deleted, not left as dead code. Surfaced two real, previously-undiscovered bugs while building this: (1) `HomeView`'s Payment button had no `BlocProvider<AuthCubit>` ancestor anywhere in production code — masked by `home_page_test.dart`'s own test harness compensating by providing one itself — fixed by wiring `HomePage` the same way `ProfilePage` already does; (2) a returning authenticated user briefly saw the *populated login form*, not a blank gap, before landing on `/home`, because `AuthSessionAdapter._toStatus()` mapped the in-progress `AuthInitial` state to the same status as a confirmed-logged-out session — fixed with a minimal loading gate in `apps/mobile/lib/src/app.dart` (functionally the modern equivalent of the old app's `/splash` gate, not its full carousel — see the `splash` row below and GAPS.md). QA: [docs/qa/home.md](docs/qa/home.md). |
| `auth` | Selesai (send-OTP + verify-OTP login, **project's first genuine "yes, UseCase is justified" case** — see below) — **CATATAN: countdown/expiry UI dan websocket-connect-on-login BELUM direplikasi (lihat catatan permanen di atas); register/KTP/selfie migrated separately, see its own row below.** | 2026-07-10 | 2026-07-10 | Feature #3, foundational/highest fan-in — extends the kit's existing `authentication` package additively (new `SendOtpUseCase`/`VerifyOtpUseCase`/`OtpLoginCubit`/`OtpLoginPage`, all parallel to the existing email/password `LoginUseCase`/`LoginCubit`/`LoginPage`, which are untouched). **Resolves the open UseCase decision** (see above): both new usecases are justified by real ported validation (phone/OTP non-empty, `62` country-code prefix) from the old app's `AuthStateCubit`, not invented structure — the first two real "needs a UseCase" cases after `about`/`onboarding`'s two "doesn't" cases. `OtpLoginPage` is reached via `Navigator.push` from `LoginPage`, not a new `GoRoute` — avoids a real redirect-loop bug found in `AppRouter._redirect` (exact-match on `/login`, would reject a sibling route like `/login/otp`); `shared` was not touched. 30-test `authentication` baseline stayed exactly green, 28 tests added (58 total) — verified by name, not just count. **Extended again same day** to resolve the `dashboard`/`account_page` finding (see above): `SessionProfile` (`avatar`/`name`/`nik`) added as an entity separate from `User`, deliberately — `User` flows into `CrashReporter.setUserId`/`AnalyticsService.setUserId` (unwired today, but that's their whole purpose), and NIK must not travel there by accident. Stored alongside `User` in `SecureTokenStorage` (own key), cleared by the same `clear()` — verified with a real (non-mocked) storage backing, not assumed. `authentication` test count: 58 → 62. QA: [docs/qa/auth_login.md](docs/qa/auth_login.md) — sensitive-data checklist + real network/router/interactive-tap-through verification, including a real (not mock-server-only) login run through to `/home` with `/profile` and `/about` confirmed still reachable; [docs/qa/account.md](docs/qa/account.md) — the `SessionProfile`/NIK checklist and the real-storage clear() proof. |
| `register` | Selesai (KTP+selfie registration, **highest sensitive-data tier of any feature migrated so far, and the last standalone feature from AUDIT.md**) | 2026-07-12 | 2026-07-12 | Audited in full before any code (RegisterStateCubit/FormView, KTP OCR extraction via `/registrasi/ktp`, selfie via `CameraGateway` — confirmed still-capture-only, no ML Kit/live detection, same as the audit expected), then built on seven explicit user decisions. Extends `packages/authentication` additively (not a new package — the package's own pre-existing description and `CameraGateway`'s/`form_input`'s own doc comments both already anticipated this as a second/third consumer, and ARCHITECTURE.md §6 confirms `authentication` already depends on `shared`). **`isRegistered` placed on `User`** (alongside `role`), deliberately the opposite placement from `account.md`'s `SessionProfile` decision — reasoned the same way (authorization-class field vs. display-PII-class field), reaching the opposite conclusion because `isRegistered` genuinely is an authorization flag, not PII. **Third genuinely justified UseCase** (`CompleteRegistrationUseCase`, §21) after `SendOtpUseCase`/`VerifyOtpUseCase` — the old app's `doRegister()` really does validate (every schema field present, NIK exactly 16 digits) before submitting, ported as real orchestration, not simplified to a passthrough. **Four approved corrections, not faithful ports**: (1) `normalizeSelectValue` returns `null` (field left for manual entry) instead of the old app's `orElse: () => form.values!.first` silent-wrong-guess fallback — same class of fix as `CameraGateway.initialize` (permanent finding #7); (2) `normalizeDateValue` only converts values shaped exactly like DD-MM-YYYY, re-validates the reconstructed date is real, and returns `null` otherwise — not the old app's blind `value.split('-').reversed.join('-')` on anything `DateTime.tryParse` rejected (see docs/qa/register.md §6 for the honestly-bounded evidence chain this fix is based on, built from a real `tgl_lahir: "1986-02-18"` example value in the team's own Postman collection); (3) both the KTP photo and the selfie photo are deleted after use (best-effort, proven against real temp files) — resolves the `register`-specific gap permanent finding #4 named as still-open; (4) `CompleteRegistrationUseCase` checks `nik` is present before reading its length, unlike the old app's unconditional read. **`isRegistered` gate wired into `feature_home`'s Payment button** (mandatory, closes the "lengkapi profil" gap `account.md`'s `dashboard`-row note deferred here) — an unregistered user is routed to `/register` before `/payment`. `BackConfirmWrapper` decision: `AppDialog.confirm` (already existing) was sufficient, no new component built. `authentication` test count: 62 → 107 (45 new tests). Full workspace `melos run gen`/`melos run analyze`/`melos run test` all green. QA: [docs/qa/register.md](docs/qa/register.md) — the highest-tier sensitive-data checklist yet (full KTP document + biometric selfie, not just a single NIK field), extending permanent findings #3 (KTP-extraction response leak, the worst instance of that pattern found yet) and #4 (cleanup gap, now resolved). |
| `splash` | Sebagian selesai (2026-07-14) — session-restore *gate* dibangun sungguhan, bukan `packages/feature_splash` | — | 2026-07-14 (gate only) | Confirmed, not just predicted, to fold into app bootstrap — no dedicated package built. The session-restore gate the old app's `/splash` route provided (`AuthStatus.checkingSession`) is real now: a throwaway widget test (pre-seeded a real cached session via `FlutterSecureStorage.setMockInitialValues`, checked the very first frame) proved a returning authenticated user was flashing the *login form* before `/home` — worse than a blank gap, since it's the wrong, fully-rendered screen, not empty space. Fixed in `apps/mobile/lib/src/app.dart`: `BlocBuilder<AuthCubit, AuthState>` shows a bare `CircularProgressIndicator` while `state is AuthInitial`, deferring `AppRouter` construction until the real session status is known, so `AppRouter._redirect`'s first-ever evaluation already has the correct answer. The old app's full carousel/logo splash *screen* (branding, not the session gate) is not rebuilt — stays an accepted gap, see GAPS.md. See [docs/qa/home.md](docs/qa/home.md) for the measurement and fix (found and built alongside the `dashboard`/Beranda-tab content work above, same audit). |
| `counseling` | Selesai (session list + realtime chat thread, **first feature with a real websocket integration**) — **CATATAN: koneksi Pusher wire-level tidak diuji terhadap server sungguhan di sandbox ini (lihat docs/qa/counseling.md § Environment constraints); logika reconnect/backoff/filter event sepenuhnya diuji lewat fake gateway.** | 2026-07-11 | 2026-07-11 | Audited in full before any code (see the corrected permanent finding #1 above: chat is self-contained — `subscribe()` calls `connect()` itself, does **not** depend on `auth`'s deferred connect-on-login, which stays scoped to `conf.<psychologistId>` only), permanent finding #3's now-VERIFIED `sendMessage`/`FormData` safety, and the new permanent finding #6 (raw message content in system notifications — a `dashboard`/`notification` concern, not `counseling`'s). Markdown checked directly: **not used anywhere** in counseling. No image/attachment support exists in the old app's chat at all — confirmed by reading `ChatEntity`, `sendMessage`'s params, and `InputChatField`'s UI; nothing to migrate there. **Four approved design corrections, not faithful ports**: bounded exponential-backoff reconnect (`packages/feature_counseling/lib/src/realtime/reconnect_backoff.dart`, old app retried immediately, unconditionally, forever); explicit unsubscribe (and, if it's the last channel, disconnect) in `ChatCubit.close()` when the session hasn't ended (old app leaked the channel+socket for the rest of the app's life otherwise); the `sent`-event filter checks `kode_voucher` matches the open chat in addition to `sender_type != 'participant'` (old app only checked the latter — a latent cross-channel bug that matters here specifically because the socket gateway is a shared singleton, unlike the old app's per-feature instance); `ChatMessageStatus` only has `pending`/`sent`/`failed` — no fabricated `delivered`/`read`, since the old app's own `MessageStatus` enum with those values was purely decorative. No UseCase — all three endpoints are thin passthroughs, same conclusion as `about`/`onboarding`/`history`. `"Konseling"` on `feature_history`'s history tile now navigates to the real chat page (was a placeholder). QA: [docs/qa/counseling.md](docs/qa/counseling.md) — sensitive-data checklist for transcripts (same tier as raw test answers), the optimistic-send/echo-filter regression test, real network + real router verification. `feature_counseling` test count: 31 (new package). |
| `payment` | Selesai (voucher creation + manual bank-transfer write-path, **first feature with real camera + realtime + local-storage-fix all together**) — **CATATAN: Pusher wire-level tidak diuji terhadap server sungguhan di sandbox ini (sama seperti counseling), logika reconnect/backoff/clear-on-parent-change/disconnect-fix sepenuhnya diuji lewat fake gateway dan mock.** | 2026-07-11 | 2026-07-11 | Large, coupled with dashboard. Full endpoint/entity map done in the joint `payment`/`test`/`counseling`/`websocket` audit (2026-07-10), status-code vocabulary resolved and write-path re-audited 2026-07-11 (see "✓ Resolved" section above). `getVouchers`/`VoucherEntity` confirmed redundant with `feature_history`'s `list-voucher` read, not migrated here. `form_input` built first as a hard prerequisite (`packages/shared`+`design_system`, see "Shared foundations" below) — payment's demography step is its second real consumer. **Five approved corrections, not faithful ports**: (1) cascading-select fields clear their stale value when their parent changes (`clearDependentFields`, applied iteratively) — the old app never did, which is both a write-path data-integrity bug and a proven `DropdownButtonFormField` `AssertionError` crash; (2) `StatusVoucher` enum splits the old app's single `PaymentStatus.review` into `underReview`/`paid`; (3) socket `disconnectSocket()` always unsubscribes + clears, no "skip if review" exception, unlike the old app's asymmetry that left a channel alive in the shared gateway; (4) `PaymentLocalDataSource` uses a prefixed secure-storage key (`com.akujamin.mobile.payment_psychologist_id`), fixing the same ADR-011-class vulnerability as `SecureTokenStorage`'s own fix; (5) the captured/picked proof-of-payment image is deleted after a successful upload (best-effort), a second independent instance of permanent finding #4's class of gap, this time for a financial document. iOS/Android camera permission gap (previously flagged only under `test`'s row, zero permission strings in the old app on either platform) fixed as part of this slice — `apps/mobile`'s `Info.plist`/`AndroidManifest.xml`. No UseCase — all 9 old usecases were pure passthroughs, same conclusion as `about`/`onboarding`/`history`/`counseling`. `feature_payment` test count: 24 (new package). Full workspace: 285/285 passing. QA: [docs/qa/payment.md](docs/qa/payment.md) — sensitive-data checklist with a dedicated financial-data section (proof-of-payment photo), real DI/router wiring verification. |
| `test` | Selesai (question/answer/timer/screenshot-block UI built and tested 2026-07-12 — **first feature with a mandatory second, independent validation layer at the cubit level, approved by explicit user design decision before any UI code**) | 2026-07-11 | 2026-07-12 | Largest, camera+face+websocket+screenshot — migrated last, exactly as planned. **`certificate_page.dart` (read-only PDF viewer) migrated 2026-07-11** as part of the "Riwayat + sertifikat" slice, landed in `packages/feature_history` — see [docs/qa/history.md](docs/qa/history.md). **Markdown blocker resolved 2026-07-12**: `AppMarkdownText` built (see "Shared foundations" below), confirmed by reading `test_info_container.dart` that intro/instruction content genuinely uses markdown (`CustomMarkdownWidget`), not just question text (plain, unaffected). **Face-match endpoint conflict resolved 2026-07-12**: `test`'s own `MatchFaceUsecase`→`TestRepository.matchFace()` chain is dead code — registered in DI, never called anywhere in the presentation layer (exhaustive grep). Only `camera`'s live periodic in-stream implementation is real; migrated as `feature_test`'s `FaceMatchDatasource`, `test`'s own chain not ported. **Camera prerequisite audited and built 2026-07-12** (packages/shared's `CameraGateway` + `packages/feature_test`'s proctoring slice — see "Shared foundations" below and permanent finding #7). **Langkah 3-4 complete 2026-07-12 — full flow map + sensitive-data checklist, no code written yet, reported for confirmation first per this feature's audit-first pattern:**<br><br>*Entity/flow structure*: `TestEntity`→`SectionEntity`→`QuestionEntity`(+optional `SubItemEntity`)→`AnswerEntity`, exactly as already named in `packages/feature_test`'s sibling entities. `TestStateCubit._buildStepsForTests()` flattens the whole nested tree into a single linear `List<QuestionStep>` once at load — one step per question, or one step per sub-item when a question has them — keyed by `"${testId}_${sectionId}_${questionId}[_${subId}]"` for answer storage. No test-wide timer/countdown exists anywhere in the old app (grepped) — `TimeIndicator` is audio/video *playback* position only, not an exam time limit.<br><br>*Save orchestration*: each answered question POSTs individually and immediately to `/api/pertanyaan/savev2` the moment "Next" is tapped (`TestStateCubit.nextStep()` → `_saveAnswer()`) — not batched, no local draft/cache. `_NextButton` is UI-gated on `selectedIds.isNotEmpty`, but that gate lives only in the widget, not in the cubit/API layer — worth deciding whether to also enforce it below the UI when building. Section/test boundaries surface a non-dismissible `TestDonePopup` (`PopScope(canPop: false)`) staged via `pendingStepIndex`, resolved by `closePopup()`. Both existing usecases (`GetTestsUsecase`, `SaveTestAnswerUsecase`) are thin passthroughs — same "no UseCase needed, just port the validation-free call" conclusion as `about`/`onboarding`/`history`/`counseling`/`payment`.<br><br>*Screenshot lifecycle — permanent finding #8, this is where it lives*: confirmed dead in the shipped old app (disable call commented out, three live enable-only call sites) — not fixed yet, no UI to wire it into. Must be fixed for real (not ported as-is) once the question/answer UI exists.<br><br>*New minor finding, not yet a permanent numbered one — flag for the data layer when building*: `QuestionModel.fromJson`'s `sub_items` field casts `data['sub_items'] as Map<String, dynamic>?` with no guard for the classic Laravel empty-array-vs-empty-object JSON quirk — `SectionModel.fromJson`'s parsing of `soal` *does* guard for exactly this shape (`data['soal'].isNotEmpty ? (cast to Map) : []`) in the same file, meaning the original author hit this once already and fixed it for `soal` but not `sub_items`. Circumstantial, not proven against live traffic, but worth handling defensively in the migrated model layer rather than assuming it can't happen.<br><br>*Packages needed, versions matched to old app's `pubspec.yaml`*: `just_audio: ^0.10.5`, `video_player: ^2.11.1`, `no_screenshot: ^1.1.0` — `no_screenshot`'s current pub.dev maintenance status not yet verified (same "verify before choosing" bar as `markdown_widget` in Prasyarat A), deferred to when the screenshot slice is actually built. `screenshot` stays self-contained in `feature_test` (single confirmed consumer — same "extract once" reasoning as the ML Kit wrapper).<br><br>Sensitive-data checklist: [docs/qa/test.md](docs/qa/test.md) — raw test answers (leaked via the logging interceptor, extends finding #3), proctoring face frames (never touch disk at all, a stronger baseline than finding #4's file-based flow), face-match confidence score and full exam content (both logged via the previously-unexamined response-side interceptor path), screenshot gap (finding #8, restated in feature context).<br><br>**UI built and tested 2026-07-12, per explicit user approval after the Langkah 3-4 report above.** `packages/feature_test` extended with the full question/answer/timer/screenshot-block flow on top of the already-built camera/proctoring slice — `TestEntity`/`SectionEntity`/`QuestionEntity`/`SubItemEntity`/`AnswerEntity`, `TestRepository`+`TestRepositoryImpl`+`TestRemoteDataSource`, `TestCubit`+`TestState`, `TestPage`/`ResultPage` + supporting widgets (`QuestionView`, `TestProgressHeader`, `TestInfoView`, `TestDonePopup`, `ViolationOverlay`, `AudioQuestionPlayer`, `VideoQuestionPlayer`). **Six approved corrections, not faithful ports** (the design decision that triggered this build, plus five found while building it): (1) **cubit-level answer-empty validation** — `TestCubit._saveAnswer` refuses to call the repository at all when no answer is selected, an explicit second layer independent of `_NextButton`'s UI-only gate, because this is psychological-test-result data POSTed per question immediately, not a batch-reviewed form — the user's own words, and the reason this was decided before any UI code was written; (2) **permanent finding #8 fixed for real**: `ScreenshotGateway.disable()`/`enable()` live in `TestCubit`'s constructor/`close()` — exactly one enable call site (not three, scattered, like the old app), firing on every exit path automatically via `Cubit.close()`, instead of porting the dead commented-out disable call; (3) the `sub_items`/`soal`/`bab` Laravel empty-array-vs-object guard applied uniformly via one shared `asKeyedMap()` helper, not just to the one field (`soal`) the old app happened to guard; (4) a sub-item's own `text` field is now actually rendered in `QuestionView` — the old app fetched it but never displayed it, so every sub-question step showed identical text with only the answer options changing; (5) `IntroView`'s title and content now come from the *same* level (section-first, falling back to test) instead of the old app's mismatched title-prefers-section/content-prefers-test precedence; (6) `TestCubit.getTests` returns `Future<void>` instead of the old app's (and this migration's own first draft's) `void async` — an async-void method can't be awaited or have its errors observed by a caller, a real Dart anti-pattern, not just a test-friendliness tweak. No UseCase — both endpoints are thin passthroughs, same conclusion as every other migrated feature; `TestRepository` does own the wire-format encoding internally though (structured params in, not a pre-built JSON string), better layering than the old app's presentation-layer `QuestionMapper` call. `feature_history`'s `"Lanjutkan Tes"` now navigates to the real `/test/:code` route, replacing its placeholder dialog — same pattern as `counseling`'s migration. `feature_test` test count: 69 (up from 15 for the camera/proctoring slice alone) — model parsing (incl. the `sub_items` regression test), repository (envelope + per-test-type body construction), cubit (incl. the cubit-level validation test with `verifyNever`), widget tests with fake cubits. Full workspace `melos run gen`/`melos run analyze`/`melos run test` all green. QA: [docs/qa/test.md](docs/qa/test.md) — side-by-side checklist and environment-constraints sections appended with real evidence (a real Dio→ApiClient→repository network round-trip against a local `HttpServer`, since full-app DI bootstrap hits the same class of `MissingPluginException` `auth_login.md` already documented, this time via `path_provider`/Hive, unrelated to `test` itself). |

## Infrastructure/service features (become shared/core services, not feature packages)

| Feature | Status | Started | Done | Notes |
|---|---|---|---|---|
| `form_input` | belum | — | — | Resolved to `shared` (schema fetch) + `design_system` (`FormFieldBuilder`) — AUDIT.md §5b. `FormInputLocalService` is dead code, do not port |
| `camera` | belum | — | — | Consumed by auth (selfie) + test (proctoring). No native permission strings found for camera on either platform (native inventory, 2026-07-10) — real gap in the old app, not something to faithfully port. Captured images have no explicit temp-file cleanup — see permanent finding #4 above |
| `websocket` | Selesai (2026-07-13, TAHAP 1) | 2026-07-13 | 2026-07-13 | Extracted from `feature_counseling`/`feature_payment`'s separately-duplicated `SocketGateway`s into one app-wide `packages/shared` gateway (`SocketGateway`/`SocketGatewayImpl`, single `lazySingleton`), consolidating `counseling`+`payment`+`dashboard` onto the same connection — the old app's own architecture (one process-wide `WebsocketDatasourceImpl`), not a new design. Placed in `shared` rather than a new `packages/websocket` (§3 "extract once" bar not met — see `MIGRATION_PLAYBOOK.md`'s own extended §3). Baseline proof, not assumption: `feature_counseling` 31→28 (`reconnect_backoff_test.dart` moved to `shared`), `feature_payment` unchanged at 24, `shared` +3. See [docs/qa/dashboard.md](docs/qa/dashboard.md). |
| `notification` | Selesai (2026-07-13, TAHAP 2) | 2026-07-13 | 2026-07-13 | `NotificationGateway` built in `packages/shared` (`flutter_local_notifications` + `permission_handler`, mirrors `CameraGateway`'s domain/data split). Real fix, not a port: the old app's `NotificationLocalServiceImpl.show()` requested permission but discarded `request()`'s result, calling `plugin.show()` unconditionally — `NotificationGatewayImpl` captures that result and returns `Err(permissionDenied)` instead, proven by a `verifyNever()` regression test. `cancelAll()` wired into `AuthCubit.logout()` (single authoritative call site, not scattered across UI logout buttons). See [docs/qa/dashboard.md](docs/qa/dashboard.md). |
| `screenshot` | Selesai (2026-07-12) | 2026-07-12 | 2026-07-12 | Consumed by `test` only — stayed self-contained in `packages/feature_test` (`ScreenshotGateway`/`ScreenshotGatewayImpl`, `no_screenshot: ^1.1.0`), not promoted to `shared` (§1 "extract once", no second consumer). Real fix for permanent finding #8: lifecycle lives in `TestCubit`'s constructor/`close()`, one enable call site instead of the old app's three scattered ones |

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
| `SocketGateway`/`ReconnectBackoff`/`SocketEvent` (websocket connect/subscribe/unsubscribe, exponential-backoff reconnect) | `counseling`'s (self-contained, per the rule of thumb above) and `payment`'s separately-duplicated gateways — the third consumer (`dashboard`) is what actually triggered the extraction, per the same "starts feature-specific, promoted once reuse is proven" reasoning `websocket` itself is the canonical example of above | `packages/shared` — not a new `packages/websocket` (§3's package-creation bar not met) | 2026-07-13 |
| `NotificationGateway` (show/cancel/cancelAll, permission-check-then-show) | `dashboard`'s notification handling — no second consumer exists yet, extracted anyway because `cancelAll()`'s single-authoritative-call-site design (`AuthCubit.logout()`) genuinely is app-wide glue, not a `dashboard`-specific concern, the same "generic by design" reasoning `form_input` used | `packages/shared` | 2026-07-13 |

---

*Started 2026-07-09, the same day this repo was bootstrapped from
[flutter_starter_kit](https://github.com/MIT2010/flutter-monorepo). See
[README.md](README.md) for the bootstrap note.*
