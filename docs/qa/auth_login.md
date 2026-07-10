# Sensitive-data checklist — `auth` login (send-OTP + verify-OTP)

Filled in **before writing any migration code**, per explicit instruction —
this is docs/MIGRATION_PLAYBOOK.md §3 applied for real (real phone numbers,
real OTP codes, real tokens), not a mental check. Every claim below is
grounded in code actually read this session, not assumed — cited by file.

The side-by-side old-app/new-app behavior checklist (the
`docs/QA_CHECKLIST_TEMPLATE.md` format `about.md`/`onboarding.md` used)
will be **appended to this same file** once the feature is built and
verified — this file starts as the pre-code sensitive-data plan and
becomes the full QA record.

---

## 1. Inventory of sensitive fields

| Field | Where it appears | Lifetime in old app |
|---|---|---|
| Phone number | `sendOTP` request body (`phone_number`), `login-otp` request body | In-memory only (`AuthStateCubit._phoneNumber`), cleared on successful login — **not cleared on failure**, see §4 |
| OTP code | `login-otp` request body (`otp_code`) | In-memory only (`AuthStateCubit._otpCode`), same clear-on-success-only gap |
| Access token | Returned by `login-otp` (`data['access_token']`), stored client-side | Persisted via `flutter_secure_storage`, single key `'access_token'` (`AuthLocalServiceImpl`, verified by reading the file) |
| Refresh token | **Not present client-side at all** | See §2 — old app has no client-stored refresh token; `refreshToken()` calls `/api/auth/refresh` and gets back a new `access_token` directly |
| User profile (name/role) | Returned by `getProfile()` | Out of scope for this feature — deferred, see MIGRATION_LOG.md's permanent note |

## 2. Storage tier

**Must land in the kit's `SecureTokenStorage`** (flutter_secure_storage-backed,
already namespaced per ADR-011) — same tier the old app already uses for
its access token, so this is "stay at the same tier," not a downgrade.

**Real architecture mismatch found, not just a naming detail**: the old
app's `AuthLocalServiceImpl` stores **only one token** (`access_token`);
there is no client-side refresh token at all — `AuthRepositoryImpl.refreshToken()`
calls `/api/auth/refresh` and receives a fresh `access_token` back directly
(verified in `auth_repo_impl.dart`). The kit's `SecureTokenStorage.saveTokens()`
requires **both** `access` and `refresh` as non-nullable `String`. This
needs a real decision during implementation, not a silent workaround:
- `SecureTokenStorage`'s public method signature is only called from
  *within* `authentication`'s own `AuthRepositoryImpl` (verified — no
  other package calls `.saveTokens()` directly), so adapting how it's
  *used* internally doesn't touch the public `AuthCubit`/`AuthSession`
  contract other features depend on (the baseline-test concern from
  point 1 is about that contract, not this internal storage detail).
- Planned approach: extend `SecureTokenStorage` with a single-token-aware
  path (or make `refresh` optional) rather than storing a placeholder
  value in the refresh slot — a placeholder would be actively misleading
  (something reading "is there a refresh token" would get a false yes).
  Finalized during implementation; documented here as the constraint
  driving that decision, not decided invisibly.

Phone number and OTP code are **not persisted at all** in the old app
(in-memory, request-scoped) — the migrated version keeps that; there's no
storage tier decision to make for them, only a lifecycle one (§4) and a
logging one (§3).

## 3. Transit and logging

**Transit**: no certificate pinning found configured in the old app's
`DioClient` (`packages/core`-equivalent, `lib/src/core/network/dio_client.dart`,
read in full) — plain `Dio(BaseOptions(...))`, no custom `HttpClientAdapter`.
Nothing to preserve here beyond the kit's existing TLS-only `ApiClient`.

**Logging — real finding, not hypothetical**: the old app's own
`LoggerInterceptor` (`lib/src/core/network/interceptors.dart`, read in
full) logs the **full request and response body** for every POST:
```dart
if (options.method == 'POST') {
  logger.d('Data: ${options.data}'); // includes phone_number, otp_code
}
// and, separately, on every response:
logger.d('...Data: ${response.data}'); // includes access_token
```
This means the old app **currently logs phone numbers, OTP codes, and the
access token in plaintext** to its dev logger. This is a real pre-existing
gap in the old app, not a migration risk to faithfully reproduce —
MIGRATION_PLAYBOOK.md §3's bar is "at least as strong as the old app,"
and the floor for "as strong as" is not "as leaky as."

**Good news, verified**: the kit's own `core` `LoggingInterceptor`
(`packages/core/lib/src/network/interceptors/logging_interceptor.dart`,
read in full) already logs **only method + URI**, never request/response
bodies:
```dart
_logger.api('--> ${options.method} ${options.uri}');
_logger.api('<-- ${response.statusCode} ${response.requestOptions.uri}');
```
Since this feature goes through `core`'s `ApiClient` like every other
migrated feature, it **automatically avoids the old app's body-logging
leak** — not because of anything auth-specific added, but because it
inherits infrastructure that was already built more carefully. No extra
redaction code is needed for this interceptor. (If a future feature adds
a *new* interceptor or logs manually, that code would need the same
scrutiny — noted here as a reusable observation, not just for this
feature.)

## 4. Lifecycle

- **Logout must clear the same fields the old app clears, at minimum**:
  old app's `clearToken()` only clears `access_token`. The kit's
  `SecureTokenStorage.clear()` already clears access token + refresh
  token + cached user (`_storage.deleteAll()`) — **broader than the old
  app's own logout**, which is fine (clearing more on logout is not a
  downgrade), but confirms the migrated logout path must route through
  the kit's existing `clear()`, not reimplement a narrower one that only
  clears the single token.
- **In-memory `_phoneNumber`/`_otpCode` must be cleared on both success
  *and* failure**: the old app only clears them in `getToken()`'s success
  branch (`_phoneNumber = ''; _otpCode = '';` inside the `Right` case) —
  on a failed verification attempt, the entered OTP code stays in memory
  until the next attempt overwrites it. Small, safe correction planned
  for the migrated version: clear on both paths. This is not a structural
  behavior change a user would notice (the UI already requires re-entry
  on failure) — it's tightening an in-memory retention window, allowed
  under "migrate behavior, not structure" since the *observable* behavior
  is unchanged.

## 5. Explicitly out of scope for this checklist

- **websocket-connect-on-login** and the **`account_page` question** are
  not sensitive-data concerns and are tracked separately — see
  [MIGRATION_LOG.md](../../MIGRATION_LOG.md)'s permanent notes, added in
  the same session as this file.
- `register`/KTP/selfie: excluded from this feature's scope entirely (per
  the confirmed feature #3 scope) — its own sensitive-data checklist
  (biometric templates, ID document images) happens when that's migrated,
  not folded in here.

---

## Environment constraints (same as `about`/`onboarding`, not re-litigated)

Screenshot-based proof is not achievable in this environment — full detail
in [about.md](about.md). Verification below is real-pipeline and
real-widget assertion-based instead, same bar as the two prior features.

**What was verified, concretely (three throwaway test files under
`apps/mobile/qa_verification/`, run then deleted — not part of the repo,
per the `melos run test`-hang lesson from `onboarding`'s QA — evidence
copied here):**

1. **Real network pipeline, zero mocking above the socket.** A real local
   `HttpServer` implementing `/v1/auth/send-otp`, `/v1/auth/login-otp`,
   `/v1/auth/me`, hit through the real `SendOtpUseCase` → `VerifyOtpUseCase`
   → `AuthRepositoryImpl` → `AuthRemoteDataSource` → `ApiClient` → `Dio`
   chain (resolved from the real `configureDependencies()` DI graph, `Env`
   pointed at the local server via `--dart-define`). Confirmed: both calls
   return `Ok`, the returned `User` has the real fields from the mock
   `/auth/me` response, the access token is genuinely persisted (read back
   via `SecureTokenStorage.accessToken`, not just assumed), and
   `AuthCubit.setAuthenticated(user)` flips `AuthCubit.state` to
   `authenticated`. `flutter_secure_storage`'s platform channel has no
   working default in this sandbox (`MissingPluginException` on `write`,
   confirmed) — worked around with the plugin's own official in-memory
   test double (`TestFlutterSecureStoragePlatform`), the same class of fix
   as `shared_preferences`' `setMockInitialValues`, not a hand-rolled mock.
2. **Real `App`/`AppRouter`/DI, pre-seeded auth state, no live-emit-during-
   pump risk** (per `onboarding`'s documented `Cubit.emit()`-in-`runAsync()`
   finding): booted the real `App` widget with `AuthCubit` already
   authenticated, confirmed the real `AppRouter` routes to `/home`, then
   `router.push('/profile')` and `router.push('/about')` — both rendered
   (`AppBar` title visible) without a redirect loop back to `/login`. This
   is the actual regression question this migration raises: does
   extending `authentication` break anything the router or other features
   depend on. It doesn't.
3. **Real interactive tap-through, phone entry to Home**, bounded with a
   45-second timeout (a repeat of `onboarding`'s hang would fail loudly
   instead of running indefinitely — it didn't repeat; this run completed
   in ~1 second). Tapped "Masuk dengan nomor telepon" on the real
   `LoginPage`, entered a phone number, tapped "Kirim OTP" (real network
   call), entered the OTP code once the real `otpEntry` state rendered,
   tapped "Verifikasi" (real network call), landed on the real `HomePage`.
   Genuinely end to end: real widgets, real taps, real Cubit, real HTTP,
   real router redirect on success — not a mock server standing in for the
   app's own code.

**New finding, recorded so it isn't rediscovered**: `AppRouter._redirect`'s
`loggingIn` check (`state.matchedLocation == '/login'`) is an *exact*
string match, not a prefix match. A sibling top-level route like
`/login/otp` would fail that check and bounce an unauthenticated user
straight back to `/login` — a real redirect-loop bug, not hypothetical
(confirmed by reading `packages/shared/lib/src/router/app_router.dart` in
full). Avoided entirely by *not* adding a new `GoRoute` for the OTP flow:
`OtpLoginPage` is reached via `Navigator.of(context).push(...)` from the
already-`/login`-routed `LoginPage`, so the router's own location never
changes underneath it, and the existing `loggedIn && loggingIn -> /home`
rule fires automatically the moment `AuthCubit.setAuthenticated` runs — see
`otp_login_page.dart`'s class doc for the full reasoning. `shared` was not
touched by this migration.

---

## Checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Masuk nomor telepon valid, tekan "Kirim OTP" | Kode OTP dikirim, layar verifikasi tampil | `sendOTP()` validates phone (non-empty, min length), prefixes `62`, calls `/api/auth/send-otp`, starts a countdown timer | `SendOtpUseCase` runs the same validation + `62` prefix (ported from `AuthStateCubit._validatePhone()`), calls `/auth/send-otp` — verified against a real local server. Countdown timer UI not reproduced (see below) | [x] |
| Nomor telepon kosong atau terlalu pendek | Pesan error, tidak memanggil API | `_validatePhone()` returns an error before any network call | `SendOtpUseCase` returns `ValidationFailure` before touching the repository — unit-tested (`send_otp_usecase_test.dart`), never calls the network | [x] |
| Masuk kode OTP benar, tekan "Verifikasi" | Login berhasil, masuk ke halaman utama | `getToken()` validates phone+OTP non-empty, calls `/api/auth/login-otp`, saves the access token, calls `getProfile()`, connects websocket, emits `authenticated` | `VerifyOtpUseCase` runs the same non-empty validation (ported from `_validateOtp()`), `AuthRepositoryImpl.verifyOtp()` calls `/auth/login-otp` → saves the access token → calls `/auth/me` → emits `authenticated` via `AuthCubit.setAuthenticated` — verified end to end against a real local server, including the real tap-through to Home (see above). Websocket-connect explicitly deferred, see MIGRATION_LOG.md | [x] |
| Kode OTP salah atau kosong | Pesan error, tetap di layar OTP, tidak berpindah halaman | `getToken()` emits an error state, `_phoneNumber`/`_otpCode` cleared only on success (a gap) | `verifyOtp()` returns `Err`, `OtpLoginCubit` emits `verifyOtpFailure` (stays on the OTP screen with the error message) — unit-tested (`otp_login_cubit_test.dart`). In-memory phone/OTP aren't retained across attempts either way here (no persistent field to leak, unlike the old app's gap) | [x] |
| Setelah login berhasil, buka `/profile` dan `/about` | Kedua halaman tetap bisa diakses normal | N/A — old app doesn't have this package boundary | Verified with the real `App`/`AppRouter`/DI: both routes render without a redirect loop, confirming `AuthCubit`'s public contract (`AuthState`/`setAuthenticated`) wasn't broken by this extension (see above) | [x] |
| Hitung mundur/waktu kedaluwarsa kode OTP | Tampilkan sisa waktu, tombol kirim ulang aktif setelah kedaluwarsa | `Timer.periodic` 1-detik tick, driven by `expires_at` from the send-OTP response | Not reproduced — `expiresAt` is returned by `sendOtp` and carried in `OtpLoginState.otpEntry`/`verifyingOtp`/`verifyOtpFailure` (available to a future UI pass), but no live countdown widget or resend-cooldown logic was built. Scope was confirmed as "send-OTP + verify-OTP login only" (MIGRATION_LOG.md) — this is a UX nicety on top of that, not the core flow | [ ] — known, tracked simplification |
| Websocket connect setelah login sukses | Terhubung ke channel psikolog | `getProfile()` success calls `_connectToWebsocket()` | Explicitly out of scope — see MIGRATION_LOG.md's permanent findings section | [ ] — deferred to `websocket`/`counseling` migration |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — `auth`'s row, and the
  permanent findings (websocket-connect-on-login, `account_page`) recorded
  before this feature's code was written.
- [about.md](about.md) — the environment-constraints writeup this file
  points back to rather than repeats.
- [onboarding.md](onboarding.md) — the `Cubit.emit()`-in-`runAsync()` and
  `melos run test`-hang findings this file's verification approach was
  built to avoid repeating.
