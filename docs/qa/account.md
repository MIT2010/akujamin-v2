# QA checklist — `account` (formerly `feature_profile`'s synthetic profile)

Migrated from the old app's real `dashboard/presentation/pages/
account_page.dart` — read-only avatar/name/NIK + logout, **not** the
synthetic name/email/bio/phoneNumber edit form `packages/feature_profile`
started as (that was a starter-kit demo, never mapped to real akujamin
behavior). Full audit trail is in the conversation that led to this
decision; summarized in [MIGRATION_LOG.md](../../MIGRATION_LOG.md)'s
`dashboard` row and permanent-findings section.

---

## Sensitive-data checklist (MIGRATION_PLAYBOOK.md §3) — NIK

NIK (Nomor Induk Kependudukan — Indonesia's national ID number) is
genuinely sensitive PII, unlike anything the two prior migrated features
(`about`, `onboarding`) touched. Filled in for real, same bar as
`auth_login.md`'s phone/OTP/token checklist.

### 1. Inventory

| Field | Where it appears | Lifetime |
|---|---|---|
| NIK | `AccountPage` display (old app); `authentication`'s `SessionProfile.nik` (new app) | Same `/auth/me` fetch as login (feature #3) — not a separate endpoint. Cached alongside the session, cleared on logout |
| Avatar (URL), name | Same source, same lifetime as NIK — not independently sensitive, but travel with it (see architecture decision below) |

### 2. Storage tier

**Real architecture question, resolved deliberately, not by default:**
the obvious first design was to add `avatar`/`nik` straight onto
`authentication`'s existing `User` entity (`{id, email, role}` →
`{id, email, role, avatar, nik}`), since they come from the same
`/auth/me` fetch. **Rejected after checking a real risk, not a
hypothetical one:** `User` is the object `AuthCubit`/`AuthState` carry
everywhere — including into `CrashReporter.setUserId(String? id)` and
`AnalyticsService.setUserId(String? id)`, both already declared in
`packages/shared` with an explicit "swap-later" comment pointing at a
real Firebase-backed implementation arriving eventually. Checked directly
(grepped the whole workspace for `.setUserId(`): **not called anywhere in
production code today** — but the interface's entire purpose is to be
called with session identity once a real provider lands, and `User` is
what a future implementer would reach for. If `nik` had been folded into
`User`, it would have been one `crashReporter.setUserId(user.id)`-shaped
line away from leaking into crash reports/analytics, with nobody
consciously deciding that was acceptable — exactly the class of gap
MIGRATION_PLAYBOOK.md §3 exists to catch **before** it happens, not after.

**Decision**: a separate `SessionProfile` entity (`avatar`, `name`,
`nik`), stored in `SecureTokenStorage` under its own key
(`com.akujamin.mobile.session_profile`), alongside — not replacing —
the existing cached `User`. `AuthState.authenticated` and
`AuthCubit.setAuthenticated` both gained an optional `sessionProfile`
parameter (`null` for the synthetic email/password `LoginCubit` flow,
which never had one). `User` itself was **not** touched — still exactly
`{id, email, role}`, so anything that already reaches for `User` (route
guards, and eventually `setUserId`) is structurally incapable of
receiving `nik`, not just trusted not to.

**Verified, not assumed, that logout actually clears it**: added a test
using the real (non-mocked) `flutter_secure_storage` in-memory backing
(`FlutterSecureStorage.setMockInitialValues`, not a mocktail mock of
`FlutterSecureStorage` itself — a mocked `deleteAll()` succeeding only
proves the method was *called*, not that data is actually gone) —
`packages/authentication/test/data/datasources/secure_token_storage_test.dart`,
group `clear() against a real (non-mocked) storage backing`: writes a
real access token, a real cached `User`, and a real `SessionProfile`
(with a NIK), confirms all three are genuinely present, calls `clear()`,
then asserts all three — including `getCachedSessionProfile()` — come
back `null`. Green. `SessionProfile` is written through the exact same
`FlutterSecureStorage` instance as everything else in `SecureTokenStorage`,
so `clear()`'s `_storage.deleteAll()` genuinely reaches it — this was a
real question, not a rhetorical one, since it would have been easy to
accidentally wire `SessionProfile` through a different mechanism (e.g. a
separate `SharedPreferences` cache) that `clear()` wouldn't touch.

### 3. Transit and logging

Same `/auth/me` fetch already covered in
[auth_login.md](auth_login.md) §3 — no new endpoint, no new interceptor,
nothing to re-verify here. `core`'s `LoggingInterceptor` (method+URI
only, never bodies) applies the same way.

### 4. Lifecycle

- **Logout clears NIK** — verified above, not assumed.
- **No edit/update path exists** for NIK (or anything else on this
  screen) — the old app's real `AccountPage` has zero `TextField`s; the
  "Ganti Password" button visible in its source is commented-out dead
  code with no usecase/repository/endpoint behind it anywhere in the old
  codebase (grepped for `change.?password`/`update.?profile` — zero
  hits besides the dead comment). Nothing to secure that isn't already
  covered by "display it, then clear it on logout."
- **No new remote endpoint** — `feature_profile` (package name kept)
  has no `ApiClient`/repository/datasource of its own anymore; it reads
  `AuthCubit.state.sessionProfile`, populated entirely by the login flow
  already audited in `auth_login.md`.

### 5. Explicitly out of scope

- Editing any account field — old app never had this working; not
  invented here either (§0 golden rule: migrate behavior, not
  aspiration).
- `register`/KTP/selfie ("lengkapi profil" — `isRegistered` gating on
  Home) — a completely separate flow from `AccountPage`, confirmed
  during the audit (`HomePage._makeProfile()` pushes a `register` route,
  unrelated to the account tab). Already out of scope per feature #3's
  scope note; unaffected by this feature too.

---

## Side-by-side checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka halaman akun setelah login | Tampilkan avatar, nama, NIK — tanpa field yang bisa diedit | `AccountPage` baca `AuthStateCubit.state.user` langsung, tampilkan `user.avatar`/`user.name`/`user.nik` via `Text`/`CircleAvatar`, nol `TextField` | `ProfileView` baca `AuthCubit.state.sessionProfile` (populated dari fetch `/auth/me` yang sama saat login), tampilkan avatar/name/nik read-only — verified widget test, nol `TextField` | [x] |
| Tekan tombol Logout | Dialog konfirmasi muncul dulu | `showDialog` + `ConfirmationDialog`, `onConfirm: AuthStateCubit.clearToken` | `AppDialog.confirm(...)`, `onConfirm` memanggil `AuthCubit.logout()` — verified widget test (tap Logout tidak langsung logout tanpa konfirmasi) | [x] |
| Konfirmasi Logout | Sesi berakhir, kembali ke halaman login | `clearToken()` menghapus `access_token`, redirect otomatis lewat auth-gated router | `AuthCubit.logout()` memanggil `SecureTokenStorage.clear()` (menghapus token + user + session profile — verified real-storage test di atas), lalu `context.go('/login')` — verified widget test | [x] |
| Batalkan dialog Logout | Tetap di halaman akun, sesi tidak berubah | Dialog tertutup, tidak ada perubahan state | Verified widget test — `authCubit.logout()` tidak pernah dipanggil, data akun tetap tampil | [x] |
| Sesi authenticated tapi belum ada session profile (mis. flow login email/password sintetis) | Tidak crash; tampilkan sesuatu yang masuk akal | N/A — old app hanya punya satu flow login (OTP), selalu ada `user` lengkap begitu authenticated | Fallback message ditampilkan (`'Belum ada data akun untuk ditampilkan.'`), tidak crash — verified widget test. Ini kasus yang secara sengaja mustahil terjadi lewat flow OTP nyata, tapi mungkin lewat `LoginCubit` sintetis kit | [x] |
| Logout benar-benar menghapus NIK dari storage (bukan cuma token) | NIK tidak tersisa setelah logout | N/A — tidak ada cara memeriksa storage app lama dari luar | Real-storage-backed test (§2 di atas) — `getCachedSessionProfile()` mengembalikan `null` setelah `clear()` | [x] |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — `dashboard` row and the
  permanent-findings section this feature resolves.
- [auth_login.md](auth_login.md) — the `/auth/me` fetch and
  `LoggingInterceptor` findings this file points back to rather than
  repeats.
- [about.md](about.md) — the environment-constraints writeup (screenshot
  proof not possible in this sandbox) that also applies here.
