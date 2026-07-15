# Sensitive-data checklist — `register` (KTP + selfie, highest tier yet)

Migrated from the old app's `register` flow inside its `auth` feature
folder (`RegisterStateCubit`/`FormView`, KTP OCR extraction + selfie
capture + a `/registrasi/profile`-driven dynamic form). Audited in full
before any code was written (see MIGRATION_LOG.md's `register` row for the
audit summary and the seven explicit design decisions this build
implements); this file is the sensitive-data checklist plus the
side-by-side QA record, same combined-file pattern
[test.md](test.md) used.

**Why this is the highest sensitivity tier of any feature migrated so
far, not just "another NIK field" like [account.md](account.md):** a
photographed Indonesian KTP exposes the *entire* national ID card in one
image — full name, NIK, address, place/date of birth, and the ID
photograph itself (a second, separate face image from the live selfie).
`account.md`'s NIK checklist covered one text field sourced from an
already-issued session; this feature captures and transmits the source
document image itself, plus a fresh biometric selfie, both while the user
is still unauthenticated-for-app-purposes (registering, not yet
`isRegistered`). Treated as equal to or higher than `test.md`'s
proctoring-frame tier, per the user's explicit instruction before this
build started.

---

## 1. Inventory of sensitive fields

| Field | Where it appears | Lifetime |
|---|---|---|
| KTP photo (full ID card image: name, NIK, address, DOB, ID photo) | `POST /registrasi/ktp` request (multipart, field `ktp`) | Captured via `image_picker` (`ImageSource.camera`), resized in-memory (`resizeImageBytes`), uploaded, then the local file is **deleted immediately after the call returns** (`RegisterCubit.scanKtp`'s `_deleteFileQuietly(image.path)`) — single-use, never needed again after extraction |
| Selfie photo (live biometric capture) | `POST /registrasi/ktp` request (multipart, field `image`) *and* `POST /registrasi/save` request (multipart, field `foto`) | Captured via `CameraGateway.captureImage()` (still capture only, no ML Kit/live face detection — confirmed during the audit: the old app's own selfie flow never used them either). Kept on disk across both calls (KTP extraction reuses it, then the final submit reuses it again), **deleted only after a successful `submit()`** (`RegisterCubit._deleteFileQuietly(selfiePath)`) — it cannot be deleted after the KTP-extraction call the way the KTP photo is, since it's still needed for the final submit |
| Extracted KTP fields (name, NIK, address, DOB, etc.) | Response body of `/registrasi/ktp`; then held in `RegisterState.formResults` until submit | In-memory only, cleared when `RegisterCubit` is disposed. Never written to disk on its own (only travels back out as part of the final submit's form fields) |
| Full registration form data (schema-driven, `/registrasi/profile`) | `POST /registrasi/save` request (multipart form fields + `foto`) | Same lifetime as the extracted fields above — in-memory, cleared on cubit disposal |
| `isRegistered` flag | `User.isRegistered` (additive field, alongside `role` — an authorization flag, not display PII) | Persisted in `SecureTokenStorage` alongside the rest of `User`, refreshed via `AuthRepository.refreshProfile()` (re-fetches `/auth/me`) right after a successful submit, cleared on logout like every other `User` field |

## 2. Storage tier

**Both captured images are deliberately temp-file-backed, never
persisted to a durable store** — `image_picker`/`CameraGateway` write to
the platform's OS temp directory, and this feature's job is to delete
them as soon as they're no longer needed, not to avoid touching disk at
all (unlike `test`'s proctoring frames, which never touch disk in the
first place — a stronger baseline permanent finding #4 already
distinguishes). This is the same class of mandatory-cleanup gap permanent
finding #4 identified for `test`'s selfie/face-capture path in general,
and finding #4's face-image cleanup note explicitly named `register`'s
selfie capture as still-out-of-scope at the time it was written — **now
resolved**:

- KTP photo: deleted right after the `/registrasi/ktp` call returns,
  success or failure (`scanKtp()`'s `try`/`catch` both reach
  `_deleteFileQuietly`) — single-use, no reason to keep it past that one
  call.
- Selfie photo: deleted only after `submit()` succeeds — it has two real
  uses (KTP extraction, then the final submit), so deleting it after the
  first would break the second. A failed submit deliberately leaves the
  file in place (the user needs to retry without retaking the selfie) —
  proven in `register_cubit_test.dart`'s failure-path test that the file
  survives a failed submit.
- Both deletions are **best-effort** (`try`/`catch`, same shape as
  `PaymentCubit._cleanupProofImage`) — a cleanup failure must never block
  a registration that already succeeded, or leave the user stuck retrying
  a KTP scan that already extracted correctly.

`isRegistered` itself lives in `SecureTokenStorage` (`flutter_secure_storage`),
the correct tier for an authorization flag traveling alongside `User` —
not `shared_preferences` (would be wrong for anything gating server-side
authorization state) and not folded into `SessionProfile` (which is
display-only PII, a different class — see `account.md`'s `SessionProfile`
architecture decision for why that distinction matters).

## 3. Transit and logging

**Extends permanent finding #3 with the single most sensitive payload
found in that finding's lineage.** Both new endpoints send multipart
bodies (`FormData.fromMap(...)`), so the same `dio`-source-verified proof
(`FormData` has no `toString()` override, `LoggerInterceptor`'s
request-side `'Data: ${options.data}'` only ever prints
`Instance of 'FormData'`) clears the **request** side of both
`/registrasi/ktp` and `/registrasi/save` — the KTP image bytes, selfie
image bytes, and submitted form fields are never leaked by that log line.

**The response side is a real, serious leak, following the same
unconditional-response-logger pattern `test.md` §3 already established
for `getTests`/`face-matchv2`:** `/registrasi/ktp`'s response body is the
**extracted KTP fields themselves — full name, NIK, address, date of
birth** — and the old app's `LoggerInterceptor.onResponse` prints it to
the dev console in full, unconditionally, regardless of how the request
was sent. This is a materially worse instance of the same root cause than
either of `test.md`'s response-side findings (exam content, face-match
confidence score) — this one is a complete national-ID-document field
set, not test content or a similarity score.

**Already true, restated so it isn't missed**: this is automatically
avoided the moment `register` goes through the kit's own `core`
`ApiClient` + body-free `LoggingInterceptor` — no new code needed for
that mechanism, same conclusion as every prior feature's transit section.
The same rule already written down for `test`/`counseling` applies here
with extra weight: **never add an ad-hoc debug print of the raw KTP
extraction response, the submitted form fields, or either image's bytes
anywhere in this feature's code, even temporarily.**

**Transit**: no certificate pinning in the old app (already established
generally in `auth_login.md` §3) — nothing feature-specific to add here,
beyond noting that the lack of pinning matters more for this feature's
payloads than most others migrated so far.

## 4. Lifecycle

- **Mandatory cleanup, both images** — covered in full in §2 above,
  proven with real temp files in `register_cubit_test.dart` (not just
  asserted from a comment — same bar `payment_cubit_test.dart`'s
  proof-of-payment cleanup test set).
- **`isRegistered` gate at the call site, not just after the fact** —
  `feature_home`'s Payment button now checks `AuthCubit.state`'s
  `User.isRegistered` before navigating; an unregistered user is routed
  to `/register` first (`context.push<bool>('/register')`), a registered
  one goes straight to `/payment`. This closes the "lengkapi profil" gap
  `account.md`'s `dashboard`-row note flagged as out of scope for that
  feature and deferred to here (`HomePage._makeProfile()`'s equivalent in
  the old app).
- **No silent-wrong-guess normalization** — two approved fixes, both
  proven with dedicated unit tests
  (`normalize_extracted_field_test.dart`), not just described:
  - `normalizeSelectValue`: an OCR-extracted value matching no real form
    option returns `null` (field left unset for manual entry) instead of
    the old app's `orElse: () => form.values!.first` — silently
    submitting the *wrong* province/city/etc. from OCR noise is worse
    than leaving a field blank for a human to fill in, the same reasoning
    already applied to `CameraGateway.initialize`'s lens-fallback fix
    (permanent finding #7).
  - `normalizeDateValue`: only converts a value shaped exactly like
    `DD-MM-YYYY` (and only when it's a real calendar date — a regex match
    alone doesn't catch `13` as a month, the reconstructed date is
    re-validated), returning `null` otherwise — not the old app's blind
    `value.split('-').reversed.join('-')` on *any* string
    `DateTime.tryParse` rejected. See §6 below for the evidence this
    format assumption is built on.
- **Defensive NIK-length check** — `CompleteRegistrationUseCase` only
  reads `formResults['nik']!.length` after confirming `nik` is present,
  unlike the old app's unconditional read (a null-check crash waiting to
  happen if the schema ever omitted the field) — low-cost fix made while
  this validation logic was already being rewritten (decision #6).
- **Logout** — `isRegistered` travels with the rest of `User` through
  `SecureTokenStorage.clear()`, already proven generically for every
  `User` field by `account.md`'s real-storage `clear()` test; not
  re-proven per-field here since the mechanism is identical, not new.

## 5. UseCase decision (§21/ADR-004)

**`CompleteRegistrationUseCase` — justified, the third genuinely real
case in this migration** (after `SendOtpUseCase`/`VerifyOtpUseCase`),
**not** a passthrough like every other UseCase decision so far
(`about`/`onboarding`/`history`/`counseling`/`payment`/`test` all
concluded "no UseCase needed"). The old app's
`RegisterStateCubit.doRegister()` really does perform multi-field
validation before calling the API — every schema field must be present,
the NIK must be exactly 16 digits — real business rules read directly
from the old app's source, not invented ones. Ported as real
orchestration, not simplified to a thin call-through.

`loadForm`/`scanKtp` stay UseCase-free — both are thin passthroughs
(`FormInputRepository.getForm`, `AuthRepository.extractKtp`), same
conclusion as every prior feature's non-submit calls.

## 6. Date-format evidence chain (decision #3)

**Explicitly not provable with 100% certainty from the sources
available — stated with its actual boundaries, not overstated.** The
chain, honestly bounded:

1. `/registrasi/save`'s submit body needs an ISO (`yyyy-MM-dd`) date —
   confirmed by a **real example value**, `tgl_lahir: "1986-02-18"`, in
   the team's own `PMI-API.postman_collection.json` under "API V2 >
   Registrasi > Save Regis". This part is directly evidenced, not
   inferred.
2. `normalizeDateValue`'s DD-MM-YYYY-reversal heuristic only ever
   activates when a value is **not already** a valid ISO date — so it
   only matters for whatever shape `/registrasi/ktp`'s OCR extraction
   actually returns a birth date in.
3. Indonesian physical e-KTP cards print the birth date as `DD-MM-YYYY`
   on the card itself — a well-established fact about the physical
   document, not about this specific API.
4. **What's genuinely not proven**: the Postman collection's "response"
   arrays are empty for every endpoint (49 out of 49, checked) — there is
   no captured real response from `/registrasi/ktp` showing what shape
   the OCR extraction actually returns a date in. The old app's own
   reversal heuristic firing "whenever `DateTime.tryParse` rejects the
   value" is consistent with OCR returning the card's own DD-MM-YYYY
   format, but it is not direct proof of it.

**Given that boundary, the fix keeps the original intent (DD-MM-YYYY→ISO
conversion stays, since it's very likely still needed) but changes *how*
it activates**: from "blindly reverse anything `DateTime.tryParse`
rejects" to "match the DD-MM-YYYY shape explicitly, re-validate the
reconstructed date is real, fail closed (return `null`) otherwise" — the
same "explicit match, honest failure" standard already applied to
`normalizeSelectValue` and, before that, `CameraGateway.initialize`.

## 7. Explicitly out of scope for this checklist

- Any endpoint/flow already covered by `auth_login.md`/`account.md`
  (`/auth/me`, `SessionProfile`, logout) — `refreshProfile()` reuses
  `getProfile()`, not a new endpoint, so its transit/logging properties
  are already established there, not re-derived here.
- The `UserProfileModel` envelope-nesting question flagged here as
  unverified — **now answered, 2026-07-15, MIGRATION_LOG.md Permanent
  Finding #10**: `/auth/me`'s real response nests every field under
  `data` except `is_regis`, which is a top-level sibling; the fix landed
  in `AuthRemoteDataSource.getProfile()`, unrelated to `register`'s own
  code, same as this note originally scoped it.
- `CameraGateway`'s own failure-handling/lens-selection behavior —
  already covered by `packages/shared`'s own test suite and permanent
  finding #7, not re-verified here.

---

## Environment constraints (same class as `about`/`onboarding`/`auth_login`/`test`, not re-litigated)

Screenshot-based proof is not achievable in this environment — full
detail in [about.md](about.md). Same `MissingPluginException` constraint
`test.md` documented for full `configureDependencies()` bootstrap
(`path_provider`/Hive, pulled in transitively by `feature_home`, nothing
to do with `register` itself) applies here too. Two things were verified
instead, the same two-part bar `test.md` set:

1. **Registration completeness, proven statically.** `injectable_generator`'s
   "Missing dependencies" warning step was checked across the full
   workspace `melos run gen` run for this feature — present only for the
   same pre-existing, unrelated external-type warnings already established
   as benign throughout this migration (`ApiClient`/`AnalyticsService`/
   `FormInputRepository`/`CameraGateway` resolved via `ExternalModule` at
   the `apps/mobile` aggregation level), absent for `[mobile]` itself. If
   `RegisterCubit`, `SelfieCameraCubit`, `CompleteRegistrationUseCase`, or
   any of their dependencies were missing a registration, this step would
   have said so.
2. **Widget-level behavior, proven with fake cubits** (`register_page_test.dart`,
   same `MockCubit`-based pattern `test_page_test.dart`/`otp_login_page_test.dart`
   established): the selfie-capture screen renders with no crash when the
   camera isn't actually ready (`SelfieCameraState`'s default
   `isReady: false` — the real camera preview widget is gated behind that
   flag, so a test environment with no real camera plugin host never
   reaches `CameraPreview` at all); tapping the camera button calls
   `SelfieCameraCubit.takePhoto()`; the dynamic form renders from a real
   `FormInputField` schema and a tap on "Lanjutkan" calls
   `RegisterCubit.submit()`; `loadingForm`/`submitting` show their
   respective progress indicators (verified with bounded `pump()` calls,
   not `pumpAndSettle` — an indeterminate `CircularProgressIndicator`/
   `LinearProgressIndicator` never "settles", the same gotcha worth naming
   explicitly for future test authors in this codebase); a `failed` status
   shows the failure message inline; a `success` status pops the route
   with `true`.

`image_picker`'s actual native picker call
(`RegisterCubit.scanKtp`'s `_picker.pickImage(source: ImageSource.camera)`)
and `CameraGateway`'s real hardware capture are **not** unit-testable —
both are platform-channel-backed with no test-host implementation
available, the exact same limitation `payment_cubit_test.dart` already
lives with for its own `ImagePicker`-gated proof-of-payment method (that
file has zero tests exercising its pick-image call either). The
orchestration *around* those calls (resize → repository call → mandatory
cleanup → normalize-and-apply-fields, or the analogous submit path) is
covered by `register_cubit_test.dart`'s other tests and by
`normalize_extracted_field_test.dart`'s dedicated coverage of the
normalization logic itself; only the bare picker/camera invocation is
left to manual verification, consistent with the existing precedent
rather than a new gap introduced here.

## What was verified, concretely

- **Full workspace baseline stays green**: `melos run gen`, `melos run
  analyze` (clean), `melos run test`. `authentication` package test
  count: 62 → 107 (45 new tests: `UserProfileModel.isRegistered`
  round-trip/default, `normalizeSelectValue`/`normalizeDateValue`
  (8 tests, including the two approved-fix regression tests and the
  month-13 rejection case), `AuthRemoteDataSource.extractKtp`/
  `submitRegistration` (multipart field verification),
  `AuthRepositoryImpl.extractKtp`/`submitRegistration`/`refreshProfile`
  (7 tests), `CompleteRegistrationUseCase` (4 tests, including the
  null-check-before-length-read regression case),
  `SelfieCameraCubit` (7 tests), `RegisterCubit` (9 tests, including the
  real-temp-file cleanup proof on both the success and failure paths),
  `RegisterView` widget tests (10 tests)).
- **The two approved-fix regressions, proven, not just described**:
  `normalizeSelectValue('Sumatera Utara')` against a field with no
  matching option returns `null`, not the first option in the list;
  `normalizeDateValue('01-13-2026')` (a value shaped like DD-MM-YYYY but
  with an impossible month) returns `null`, not a garbage reconstructed
  date — this second case specifically required comparing the
  re-parsed `DateTime`'s year/month/day back against the regex-captured
  values, since `DateTime`'s constructor silently rolls invalid
  month/day values over into the next month/year instead of throwing
  (`DateTime.tryParse` alone does not reject `'2026-13-01'`) — a real
  Dart behavior confirmed by first writing this test, watching it fail
  against the naive implementation, then fixing the implementation to
  match.
- **Mandatory cleanup, proven against real temp files**: KTP photo
  deleted after `/registrasi/ktp` regardless of success/failure; selfie
  photo survives a failed submit but is deleted after a successful one —
  both proven with `dart:io` `File` round-trips, same bar
  `payment_cubit_test.dart`'s proof-of-payment cleanup test set.
- **`isRegistered` gate, proven at the call site**: `feature_home`'s
  Payment button reads `AuthCubit.state`'s `User.isRegistered` and routes
  to `/register` instead of `/payment` when it's `false`.
- **Widget-level behavior** (`register_page_test.dart`) — see
  "Environment constraints" above for the full list.

## Checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Tekan tombol Payment di Home saat `isRegistered == false` | Diarahkan ke alur registrasi dulu, bukan langsung ke payment | `HomePage._makeProfile()`/navigasi setara "lengkapi profil" | `context.push<bool>('/register')`, bukan `/payment` — verified di `feature_home` | [x] |
| Tekan tombol Payment saat `isRegistered == true` | Langsung ke halaman payment | Langsung ke payment | `context.push('/payment')` langsung, tanpa mampir register | [x] |
| Buka halaman register | Layar selfie tampil duluan | `SelfieView` (status `takePict`) | `SelfieCaptureView` (status `takingSelfie`) — verified widget test | [x] |
| Ambil foto selfie | Preview foto tampil, opsi "Ulangi"/"Lanjutkan" | `CameraStateCubit.takePicture()`, `takenPict` | `SelfieCameraCubit.takePhoto()`, status `selfieTaken` — verified cubit test | [x] |
| Tekan "Lanjutkan" setelah selfie | Form registrasi (`/registrasi/profile`) dimuat | `getForm()`, status `inputForm` | `RegisterCubit.loadForm()`, status `inputForm` — verified cubit + widget test | [x] |
| Scan KTP | Field form terisi otomatis dari hasil ekstraksi, field yang tidak yakin dibiarkan kosong | `_normalizeInput()` — select tanpa match pakai opsi pertama diam-diam, tanggal dibalik buta | Field yang cocok terisi; field select tanpa match & tanggal tidak valid dibiarkan kosong untuk diisi manual — **perbaikan disetujui, bukan port**, verified `normalize_extracted_field_test.dart` | [x] |
| Submit dengan field wajib kosong | Ditolak, tidak ada request ke server | `doRegister()` menolak, field message spesifik | `CompleteRegistrationUseCase` menolak sama persis, `ValidationFailure` per field — verified usecase test | [x] |
| Submit dengan NIK bukan 16 digit | Ditolak | `doRegister()` menolak | `CompleteRegistrationUseCase` menolak — verified, termasuk kasus schema tanpa field `nik` sama sekali (null-check defensif) | [x] |
| Submit sukses | Data tersimpan, foto lokal (KTP+selfie) terhapus, `isRegistered` jadi true, kembali ke Home | Tidak ada cleanup eksplisit sama sekali (gap, bukan fitur) | Foto KTP terhapus setelah ekstraksi, foto selfie terhapus setelah submit sukses, `isRegistered` di-refresh lewat `/auth/me` — **perbaikan mandatory, bukan port** — verified real-temp-file test | [x] |
| Submit gagal (server error) | Pesan error jelas, foto selfie tidak ikut terhapus (masih dibutuhkan untuk retry) | Tidak ada cleanup untuk dibandingkan | Status kembali ke `inputForm` dengan error, foto selfie tetap ada di disk — verified real-temp-file test | [x] |
| Tekan tombol back saat mengisi form | Konfirmasi dulu sebelum keluar (data akan hilang) | Dialog konfirmasi kustom | `PopScope(canPop: false)` + `AppDialog.confirm` (komponen sudah ada, tidak bikin baru) — decision #4 | [x] |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — `register` row, and
  permanent findings #3 (logging interceptor — extended here with the
  KTP-extraction response leak), #4 (face-image cleanup — the `register`
  selfie-capture gap it named as still-out-of-scope is resolved here),
  #7 (`CameraGateway`'s honest-failure fix, the same "explicit match,
  honest failure" standard this feature's normalization fixes follow).
- [test.md](test.md) — the response-side logging-leak pattern this file
  extends, and the environment-constraints/`pumpAndSettle` precedents
  reused here.
- [account.md](account.md) — the NIK/`SessionProfile` architecture
  decision `isRegistered`'s placement on `User` deliberately mirrors in
  reasoning (authorization-class field vs. display-PII-class field) while
  reaching the opposite placement, and the `dashboard`-row note that
  deferred "lengkapi profil" to this feature.
- [payment.md](payment.md) — the proof-of-payment image cleanup precedent
  this feature's own mandatory-cleanup fix follows, and the
  `ImagePicker`-not-unit-testable precedent this file's environment
  constraints section extends rather than re-discovers.
