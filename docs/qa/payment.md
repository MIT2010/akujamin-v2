# QA checklist — `payment` (voucher creation + manual bank-transfer)

Migrated from the old app's `payment` feature — write-path only
(`PaymentStateCubit`/`PaymentPage`: demography → confirmation → payment →
review). The read-only `list-voucher` slice already landed in
`feature_history`; `getVouchers`/`VoucherEntity` are not re-migrated here
(redundant, same endpoint). Landed as a new package,
`packages/feature_payment`. Full audit trail — the three-vocabulary status
code map, the `form_input` mini-audit, the cascading-select design, and
every approved fix below — is in [MIGRATION_LOG.md](../../MIGRATION_LOG.md),
written *before* any code, per the standing instruction for this slice.

---

## Sensitive-data checklist (MIGRATION_PLAYBOOK.md §3)

### 1. Field inventory

| Field | Where it appears | Sensitivity |
|---|---|---|
| `formResults` (NIK, birth date, job, destination country, etc.) | `GET /tes/pertanyaan` schema, submitted via `POST /tes/create` | High — KYC-adjacent, same tier as `auth`'s register flow |
| Bank account number (`no_rekening`) | `GET /tes/rekening-psikolog/{id}` | Medium — a psychologist's own receiving account, not the user's |
| Proof-of-payment photo | Picked via `image_picker`, uploaded `POST /tes/kirim-pembayaran` | **High — see the dedicated financial-data section below, not folded into this table** |
| `kode_voucher` | Multiple endpoints | Low-medium (linkable to a specific test session) |
| Psychologist channel name (`conf.<id>`) | Stored locally to survive reconnects | Low (an opaque routing value, not personal data on its own) |

### 2. Storage tier

**One local value only**: the psychologist channel name, stored in
`flutter_secure_storage` via `PaymentLocalDataSource` — correct tier
(ARCHITECTURE.md §24), matches the old app's own choice of storage
mechanism. **The key itself was wrong, and is fixed here — see the
ADR-011-class fix below.** No other payment data is cached locally; forms,
voucher status, and payment details all live in `PaymentCubit`'s in-memory
state for the page's lifetime, same "no local cache" shape as
`counseling`.

### 3. Transit and logging

`PaymentRemoteDataSource` goes through `core`'s `ApiClient` →
`LoggingInterceptor`, which only logs method + URI, never bodies — same
conclusion as every prior feature. `createVoucher`'s `FormData` body (KYC
form fields) and `sendPayment`'s `FormData` body (the proof-of-payment
file) share the same `dio` `FormData.toString()` safety property already
verified for `counseling`'s `sendMessage` (permanent finding #3) — neither
would print field contents even under the old app's leaky interceptor.

---

## Financial data — separate section, as instructed (not folded into §1)

**Why separate:** the proof-of-payment photo is a new sensitivity class
this migration hasn't handled before — a photograph of a bank transfer
receipt (sender name, amount, partial account numbers, bank branding,
timestamp), not a face or KYC document. Write-path, not read-only, so a
mishandled cleanup here has real consequences, not just cosmetic ones.

1. **Camera *and* gallery are both offered** for capturing/selecting the
   proof photo (`showModalBottomSheet<ImageSource>`, confirmed by reading
   the old app's `payment_method_view.dart` before any code was written) —
   this is the **first real camera consumer actually migrated** in this
   repo (`auth`'s selfie/KTP capture and `test`'s proctoring remain
   un-migrated).
2. **iOS/Android camera permission gap — fixed as part of this slice, not
   deferred to `test`.** The old app shipped with **zero**
   `NSCameraUsageDescription`/`CAMERA` permission entries on either
   platform (native inventory, confirmed 2026-07-10, and re-confirmed by
   reading this repo's own `Info.plist`/`AndroidManifest.xml` before this
   fix — also empty). `apps/mobile/ios/Runner/Info.plist` now has
   `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription`;
   `apps/mobile/android/app/src/main/AndroidManifest.xml` now declares
   `android.permission.CAMERA` + a non-required `android.hardware.camera`
   feature.
3. **Temp-file cleanup — mandatory fix, not a port.** The old app never
   deleted the captured/picked image file after a successful upload — a
   second, independent instance of permanent finding #4's class of gap
   (face-image cleanup), this time for a financial document rather than a
   biometric one. `PaymentCubit._cleanupProofImage()` deletes the local
   file after `sendPayment` succeeds, best-effort (a cleanup failure must
   never block a payment that already succeeded server-side) — proven
   against a real temp file in `payment_cubit_test.dart`, not just
   asserted in a comment.
4. **Compression preserved**: `imageQuality: 70` on `ImagePicker.pickImage`,
   matching the old app — not a regression, not tightened further (no
   evidence the old value caused problems).
5. **Existing server-side proof vs. freshly-picked local proof are kept as
   two distinct state fields** (`existingProofUrl` vs. `pickedImagePath`)
   — only the local one is ever subject to cleanup; a proof URL already on
   the server is never touched by this device.

---

## Explicit decisions (not silent choices) — approved before/during code

**(a) `form_input` lives in `packages/shared` + `design_system`, generic
from day one** — not self-contained inside `feature_payment`. Confirmed
2026-07-11: the capability's shape doesn't reference either consumer's
domain (auth's KYC form vs. payment's pre-payment questionnaire read
identically). See MIGRATION_LOG.md's "Shared foundations" section for the
full generic-vs-self-contained principle this decision established for
future migrations.

**(b) Cascading/dependent selects clear stale child values on parent
change** — the old app never did, leaving a stale code that could (1) get
submitted to `createVoucher`, a real write path, and (2) crash Flutter's
`DropdownButtonFormField` outright (`AssertionError`, proven directly
against the Flutter 3.44.4 SDK, not assumed). `clearDependentFields`
applies iteratively so multi-level chains clear correctly, not just the
first hop.

**(c) `StatusVoucher` enum splits the old app's single `PaymentStatus.
review` catch-all into `underReview`/`paid`.** The literal expansion of
`'PT'`/`'TP'` remains unconfirmed — no response example or documentation
text exists to translate them from, only their functional behavior in
`PaymentStateCubit._mapStatus()`. Recorded honestly as unconfirmed rather
than guessed (docs/MIGRATION_PLAYBOOK.md §0).

**(d) Socket disconnect always unsubscribes and clears, no "skip if
review" exception.** The old app's `disconnectSocket()` left a channel
subscription alive in the shared gateway with nothing left listening to it
whenever the status was `review`. Same bounded exponential backoff as
`counseling` (`1s → 30s`, capped) — no payment-specific tuning, since
payment already has manual fallbacks for a missed real-time event (the
confirmation step's 5-minute timeout, the review step's "Cek Status
Pembayaran" button) that counseling doesn't have.

**(e) `PaymentLocalDataSource` uses a prefixed secure-storage key**
(`com.akujamin.mobile.payment_psychologist_id`), fixing the same
ADR-011-class vulnerability found in the old app's bare `'psychologist'`
key — Windows' `flutter_secure_storage` backing has no per-app
namespacing, so two different apps on the same machine would collide in
the same credential. Proven directly against a mocked storage call, not
just described in a comment.

**(f) No UseCase.** All nine of the old app's payment usecases read as
pure one-line passthroughs (confirmed during the write-path audit before
any code) — same conclusion as `about`/`onboarding`/`history`/`counseling`.

**(g) `getVouchers`/`VoucherEntity` are not re-migrated here** — confirmed
identical to `feature_history`'s already-migrated `GET /tes/list-voucher`
read. `POST /tes/kirim-penilaian` exists on the real backend (confirmed via
the Postman collection) but is never called by the old app's own
`PaymentApiService` — belongs to a future `test` feature, out of scope.

---

## Environment constraints

Same screenshot-proof limitation as every prior feature — see
[about.md](about.md). Same Pusher-wire-level disclosure as
[counseling.md](counseling.md): the real-time `conf.<psychologistId>`
channel/event flow is fully exercised through `PaymentCubit`'s tests
against a controllable fake (`_FakeSocketGateway`), never against a live
Pusher/Soketi server (none available in this sandbox) — a real, disclosed
gap, not silently assumed to work.

---

## Real verification performed

1. **Full workspace baseline**: `fvm dart analyze .` clean across all 12
   packages (one pre-existing, unrelated `feature_onboarding` info-level
   lint). `melos run test`: 285/285 passing — every pre-existing package's
   test count intact, `feature_payment` contributing 24 new tests (model
   field-mapping including the PT/TP/pembayaran-status three-way split,
   the ADR-011-class key-prefix fix, envelope handling, cubit step
   transitions, clear-on-parent-change, proof-image cleanup against a real
   temp file, and the disconnect-always-unsubscribes fix).
2. **Real network pipeline** (throwaway file, run then deleted, same
   pattern as `history.md`/`counseling.md`): a real local `HttpServer`
   implementing `/tes/cek-voucher` and `/tes/pertanyaan`, hit through the
   real (not mocked) `PaymentRepository`/`FormInputRepository` chains via
   a plain `test()` — confirmed the `'PT'` → `needsRegistrationData`
   mapping and the bare-array (no-envelope) `form_input` parsing both
   round-trip correctly over actual HTTP, not just against hand-built Dart
   maps in the unit tests.
3. **DI/routing wiring confirmed statically, not by booting the app**:
   `FeaturePaymentPackageModule().init(gh)` present in `apps/mobile`'s
   generated `injection.config.dart`; `/payment` route and "Pembayaran"
   `HomePage` icon confirmed by clean `dart analyze` (no unresolved
   imports/types) across the whole workspace after wiring.
4. **Not completed — disclosed, not silently skipped**: a `testWidgets()`
   smoke test that boots the real `App` end-to-end (real DI, pre-seeded
   `AuthCubit.setAuthenticated()`, navigate to `/payment`) was attempted
   twice and timed out at 10 minutes both times, even after replacing
   `pumpAndSettle()` with bounded `pump()` calls to rule out the
   indeterminate-`CircularProgressIndicator` pitfall. The remaining
   suspect is a platform-channel call (most likely `flutter_secure_
   storage`, used by both `AuthCubit`'s cached-session check and
   `PaymentLocalDataSource`) hanging with no responder in a plain
   `flutter test` unit-test environment, rather than failing fast. Not
   chased further given the cost already sunk into it — the DI graph's
   wiring is confirmed statically (point 3) and every individual piece
   it's made of is real-verified in isolation (points 1-2), but the
   specific "does the fully composed app widget tree render `/payment`
   without crashing" claim is **not** verified end-to-end the way it was
   for `about`/`history`/`counseling`. Flagged here rather than glossed
   over.

---

## Side-by-side checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka halaman pembayaran, voucher baru (`PT`) | Form demografi + pilih psikolog tampil | `PaymentStateCubit._checkVoucher()` → `PaymentStatus.demography` | `PaymentCubit._checkVoucher()` → `StatusVoucher.needsRegistrationData` → `PaymentStep.demography` — verified cubit test | [x] |
| Voucher sudah didaftar, belum bayar (`TP`) | Halaman transfer + rekening tampil | → `PaymentStatus.payment`, `loadPayment()` | → `PaymentStep.payment`, `_loadPaymentAccount()` — verified cubit test | [x] |
| Isi provinsi lalu kota (cascading select) | Pilihan kota terfilter sesuai provinsi | `changeValues()`, TIDAK di-clear kalau provinsi diganti ulang (stale value bisa tersimpan) | `filterCascadingOptions()` sama persis, DITAMBAH `clearDependentFields()` (perbaikan disengaja, keputusan (b)) — verified test reaktif + multi-hop | [x] — perbaikan, bukan port apa adanya |
| Submit form demografi | Voucher dibuat, menunggu konfirmasi psikolog | `createVoucher()` → `PaymentStatus.confirmation` | `createVoucher()` → `PaymentStep.confirmation` — verified cubit test | [x] |
| Psikolog konfirmasi (event `konfirmasi.user`) | Halaman pembayaran (rekening per-psikolog) tampil | `loadPayment()` → `PaymentStatus.payment` | `_loadPaymentAccount()` → `PaymentStep.payment` — verified cubit test | [x] |
| Psikolog tidak merespon 5 menit | Kembali ke demografi dengan pesan | `ConfirmationView`'s `Timer(5 min)` → `backToDemography(message:)` | Sama persis — `ConfirmationView` widget | [x] |
| Upload bukti transfer (kamera) | Kamera terbuka, gambar tersimpan sementara | `pickImage(ImageSource.camera)`, TIDAK ADA permission string iOS/Android | Sama persis, DITAMBAH permission string yang hilang (perbaikan disengaja, lihat bagian data finansial) | [x] — perbaikan, bukan port apa adanya |
| Upload bukti transfer (galeri) | Galeri terbuka, gambar tersimpan sementara | `pickImage(ImageSource.gallery)` | Sama persis | [x] |
| Submit bukti pembayaran berhasil | File lokal bukti dihapus, lanjut ke status | TIDAK PERNAH dihapus (permanent finding #4's class of gap) | Dihapus otomatis setelah upload sukses, best-effort (perbaikan disengaja) — verified test dengan file sungguhan | [x] — perbaikan, bukan port apa adanya |
| Cek status pembayaran manual | Status `PAID` atau tetap menunggu | `checkPayment()` → `data['status'] == 'PAID'` | `checkPayment()` → `PaymentCheckResult.isPaid` — verified repository test | [x] |
| Pembayaran dikonfirmasi (`PAID`) | Kode voucher + tombol "Gunakan Sekarang" tampil | `ReviewView._PaymentSuccess` | Sama persis | [x] |
| Keluar halaman pembayaran (status apa pun) | Channel socket di-unsubscribe, tidak ada koneksi menggantung | `disconnectSocket()` SKIP unsubscribe kalau status `review` (asimetri, bukan disengaja) | Selalu unsubscribe + clear, tanpa pengecualian (perbaikan disengaja, keputusan (d)) — verified cubit test untuk kedua status | [x] — perbaikan, bukan port apa adanya |
| Kunci penyimpanan lokal psikolog | Tidak bentrok dengan app lain di perangkat yang sama | Key mentah `'psychologist'`, tanpa prefix (ADR-011-class vulnerability) | Key `com.akujamin.mobile.payment_psychologist_id` (perbaikan disengaja, keputusan (e)) — verified test | [x] — perbaikan, bukan port apa adanya |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — the resolved status-code
  section (three vocabularies, `StatusVoucher` enum, disconnect-asymmetry
  fix), the `form_input` generic-vs-self-contained design principle, and
  the `payment` feature-table row.
- [counseling.md](counseling.md) — the `ReconnectBackoff`/
  `_FakeSocketGateway` pattern this feature's realtime tests reuse, and
  the Pusher-wire-level environment-constraint disclosure this file points
  back to.
- [history.md](history.md) — why `getVouchers`/`VoucherEntity` are not
  re-migrated here (already covered by that slice's `list-voucher` read).
