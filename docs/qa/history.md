# QA checklist — `history` (Riwayat + sertifikat)

Migrated from the old app's `dashboard`'s "Riwayat" tab
(`history_page.dart` → `VoucherStateCubit` → `GetVouchersUsecase` →
`PaymentRepository.getVouchers()`, `/tes/list-voucher`) and its
`test/presentation/pages/certificate_page.dart` (PDF viewer). Landed as a
new package, `packages/feature_history` — deliberately the smallest safe
slice of the payment/test/counseling/websocket cluster: **read-only, zero
camera, zero websocket, zero write-path**. Full audit trail (native
inventory, websocket architecture, sensitive-data mapping across the
whole cluster) is in [MIGRATION_LOG.md](../../MIGRATION_LOG.md)'s
permanent findings #3/#4 and the "open item" section, both written before
this feature's code started.

Entity deliberately **not** named `Voucher` — AUDIT.md §6's "voucher
trap" finding (`VoucherEntity` in the old app is the test-session itself,
not a discount code) reconfirmed independently via this exact screen; see
`TestHistoryItem`'s doc comment in
[test_history_item.dart](../../packages/feature_history/lib/src/domain/entities/test_history_item.dart).

---

## Sensitive-data checklist (MIGRATION_PLAYBOOK.md §3) — psychologist name, status, result

Lighter-tier than `auth_login.md`'s phone/OTP/token or `account.md`'s
NIK — but explicitly not skipped for that reason (that was the standing
instruction going into this slice). None of this is raw test-answer
content; it's already-summarized metadata about a completed or
in-progress test session.

### 1. Inventory

| Field | Where it appears | Lifetime |
|---|---|---|
| `psychologist` (nama psikolog) | `/tes/list-voucher` response (`nama_psikolog`), shown in `_HistoryTile` | Fetched fresh on every `HistoryPage` load — no local cache, no persistence beyond the widget tree |
| `status` (status_ujian) | Same response, drives both the display text and the conditional action button (`_isTest`/`_isCounseling`/`_isPassed`) | Same as above |
| `testResult` (hasil_tes) | Same response — a **string label** (e.g. "Baik"), not raw answer data or a numeric score breakdown | Same as above |
| `certificateUrl` | Same response (`sertifikat`), consumed by `CertificatePage` to download the actual PDF | Same as above — the PDF bytes themselves are only ever held in `CertificateCubit`'s in-memory state, never written to disk or cache |

### 2. Storage tier

**No storage tier decision needed at all** — this is the first migrated
feature with genuinely no local persistence layer. `HistoryRepositoryImpl`
has no local datasource (mirrors `AboutRepositoryImpl`'s "pure CRUD, no
offline flow" shape, §11 doesn't apply). `CertificateRepositoryImpl`
holds downloaded PDF bytes only in the `CertificateCubit`'s state object
for the lifetime of that page — nothing written to `SecureTokenStorage`,
`shared_preferences`, or any file.

### 3. Transit and logging

Both `HistoryRemoteDataSource` (via `core`'s `ApiClient`) and
`CertificateRemoteDataSource` (via the same injected `Dio` singleton
`ApiClient` wraps — see that class's doc comment for why it bypasses
`ApiClient` specifically) go through `core`'s `LoggingInterceptor`, which
only ever logs method + URI, never request/response bodies — same
conclusion as every prior feature, reconfirmed rather than assumed:
`nama_psikolog`/`status_ujian`/`hasil_tes`/the PDF bytes never reach the
log output. The old app's own `LoggerInterceptor` (permanent finding #3)
would have logged this response body in full on every request — not
inherited here.

### 4. Lifecycle

- **Nothing to clear on logout** — no local persistence exists (§2), so
  there's no cached copy of this data that could outlive the session it
  was fetched in beyond the current widget tree, which is torn down on
  navigation away regardless.
- **PDF bytes are download-and-display only** — `CertificateCubit` never
  writes the downloaded bytes to disk; `pdfx`'s `PdfDocument.openData()`
  takes the in-memory `Uint8List` directly, no temp file involved (unlike
  `camera`'s captured-image gap, permanent finding #4 — that finding
  doesn't apply here since there's no file write to forget to clean up).

### 5. Explicitly out of scope

- Raw test answers, chat transcripts — permanent finding #3's actual
  subject matter. Not reachable from this screen at all; `test`'s and
  `counseling`'s own future migrations carry that finding forward.
- Face images / camera — permanent finding #4. This slice has zero
  camera dependency by design (see the file header and MIGRATION_LOG.md).
- `payment`'s `'PT'`/`'TP'` status-code ambiguity (open item in
  MIGRATION_LOG.md) — `status`/`testResult` are consumed here purely as
  **display strings**, never branched on beyond the three literal values
  documented in `HistoryView`'s doc comment (`'Belum Tes'`/`'Sedang
  Tes'`/`'Konseling'`/`'Lulus'`/`'Tidak Lulus'`/`'Selesai'`) — the PT/TP
  ambiguity is about a *different* field (`payment`'s own status codes),
  confirmed unrelated by reading both old-app sources.

---

## Explicit decision — "Lanjutkan Tes" / "Konseling" / "Mulai Tes" placeholders

Per the standing instruction for this slice: these buttons must not be
dead (do-nothing) buttons, and the decision must be recorded here, not
left implicit in code.

**Decision**: all three lead to features not migrated yet (`payment`'s
create-voucher flow, `test`, `counseling`). Tapping any of them shows
`AppDialog.info` with the message "Fitur ini belum tersedia. Coba lagi
nanti." — an explicit, visible acknowledgement rather than silently doing
nothing or navigating to a broken route. Only "Lihat Sertifikat" (shown
when `status == 'Lulus'`) is real — `certificate` is the one piece of
this graph the slice actually migrates, and it navigates to a genuine
`CertificatePage` with a real PDF download.

This was the reason `AppDialog.info` (a single-button acknowledgement
variant of the existing `AppDialog.confirm`) was added to `design_system`
as part of this slice — a real need, not a speculative addition.

---

## Environment constraints

Same screenshot-proof limitation as every prior feature in this
environment — see [about.md](about.md) for the full writeup. Two
additional, feature-specific constraints found this time:

**PDF rendering can't be exercised under `flutter_test` at all.**
`pdfx`'s `PdfDocument.openData()` routes through a platform
`MethodChannel` (`io.scer.pdf_renderer`, confirmed by reading `pdfx`'s
source in full) with no handler registered in this test environment.
Verification therefore stops at "the download succeeds and the correct
bytes arrive" (proven — see below); actually building a `PdfController`
and rendering a page was not exercised here. This is a real, currently
unverified gap — flagged rather than silently assumed to work.

**`flutter_test`'s `TestWidgetsFlutterBinding` globally blocks real
`dart:io HttpClient` requests** (returns a synthetic 400, confirmed via
its own printed warning) — not scoped to the fake-async zone, so
`tester.runAsync()` alone does not bypass it, unlike what its name might
suggest. The real-network verification below therefore used a plain
`test()` (no `testWidgets()`, no Flutter binding at all — the same
approach `core`'s own `api_client_test.dart` already uses) rather than
fighting the override inside a widget test. Worth carrying forward: any
future feature's "real local server" verification should default to a
plain `test()` first, and only reach for a widget test when the thing
being proven is genuinely about the widget tree (routing, rendering),
not the network call itself.

---

## Real verification (two throwaway files, run then deleted — same rule as prior features)

1. **Real network pipeline.** A real local `HttpServer` implementing
   `/v1/tes/list-voucher` and a `/cert.pdf` binary endpoint, hit through
   the real DI-resolved `HistoryRepository` → `HistoryRemoteDataSource` →
   `ApiClient` → `Dio` chain, and separately `CertificateRepository` →
   `CertificateRemoteDataSource` → the raw injected `Dio` (proving the
   "bypasses `ApiClient` on purpose" design genuinely works, not just
   compiles). Confirmed: `HistoryRepository.getHistory()` returns `Ok`
   with one item whose fields match the real `kode_voucher`/
   `nama_psikolog`/`sertifikat` mapping exactly (`code: 'ABC123'`,
   `psychologist: 'Budi'`, `certificateUrl` pointing at the same local
   server); `CertificateRepository.download()` returns `Ok` with the
   exact bytes the server sent.
2. **Real `App`/`AppRouter`/DI, pre-seeded auth state.** Booted the real
   `App` widget with `AuthCubit` already authenticated (same pattern
   `auth_login.md` established), navigated to `/home`, invoked the real
   "Riwayat" `IconButton`'s `onPressed` (routed around a `tester.tap()`
   coordinate-space quirk specific to this environment — direct
   `onPressed` invocation still proves the wiring, just not Flutter's own
   gesture recognition), confirmed the real `HistoryPage` renders
   (`AppBar` title visible), then navigated to `/certificate?url=...` and
   confirmed that page also renders (`AppBar` title "Sertifikat") with no
   redirect loop back to `/login`. This part doesn't require the network
   call to succeed — part 1 above already separately proves the real data
   path; this part is specifically about route/DI wiring.

---

## Side-by-side checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka tab Riwayat dengan data ada | Daftar riwayat tes tampil, semua field terlihat | `HistoryPage` → `VoucherStateCubit` → `GetVouchersUsecase`, render `VoucherList` dengan `TestResultInfo` per item | `HistoryPage` → `HistoryCubit.getHistory()` → real `/tes/list-voucher` call, render `_HistoryTile` per item dengan semua 9 field — verified widget test (`shows all fields for a history item`) + real-network test (field mapping exact) | [x] |
| Buka tab Riwayat tanpa data | Tampilkan empty state, tombol "Mulai Tes" | N/A — tidak diverifikasi langsung terhadap app lama di sesi ini, hanya perilaku `VoucherList` kosong | `_EmptyHistory` tampil ("Belum ada tes" + tombol "Mulai Tes") — verified widget test | [x] |
| Tekan "Mulai Tes" (empty state) | Keputusan sadar (bukan tombol mati) | N/A — fitur `payment`'s create-voucher belum dimigrasi | `AppDialog.info` — "Fitur ini belum tersedia. Coba lagi nanti." — verified widget test, keputusan didokumentasikan di atas | [x] |
| Item dengan status "Belum Tes"/"Sedang Tes" | Tombol "Lanjutkan Tes" muncul | `isTest` guard menampilkan tombol serupa | Tombol "Lanjutkan Tes" muncul (guard sama persis: `status == 'Belum Tes' || status == 'Sedang Tes'`), menekannya menampilkan `AppDialog.info` — verified widget test | [x] |
| Item dengan status "Konseling" | Tombol "Konseling" muncul | `counseling` guard menampilkan tombol serupa | Tombol "Konseling" muncul, menekannya menampilkan `AppDialog.info` — verified widget test | [x] |
| Item dengan status "Lulus" | Tombol "Lihat Sertifikat" muncul, membuka PDF viewer sungguhan | `passed` guard, navigasi ke `CertificatePage` (Syncfusion) dengan query param `url` | Tombol "Lihat Sertifikat" muncul, navigasi ke `/certificate?url=...` (real `context.push`, real query param encoding) — verified widget test + real-app router test | [x] |
| Item dengan status "Tidak Lulus"/"Selesai" | Tidak ada tombol aksi | `if (isTest \|\| counseling \|\| passed)` guard — tidak satupun cocok, tidak ada tombol | Guard yang sama persis, tidak ada `AppButton` — verified widget test (`a finished item with no further action shows no button`) | [x] |
| Buka `CertificatePage` dengan URL sertifikat valid | PDF sungguhan ter-download dan dirender | Syncfusion `SfPdfViewer.network(url)` | `pdfx`'s `PdfDocument.openData()` dari bytes yang di-download via `CertificateRepository` — download sungguhan diverifikasi (lihat di atas); rendering PDF aktual tidak dapat diuji di `flutter_test` (lihat Environment constraints) | [ ] — download verified, render tidak dapat diuji di sandbox ini |
| Gagal memuat riwayat (server error) | Pesan error + tombol coba lagi | N/A — tidak diverifikasi terhadap app lama | `HistoryError` state, pesan `failure.message` + tombol "Coba lagi" yang memanggil ulang `getHistory()` — verified widget test | [x] |
| Gagal memuat sertifikat (server error) | Pesan error + tombol coba lagi, AppBar tetap "Sertifikat" | N/A | `CertificateError` state, pesan + tombol "Coba lagi" — verified widget test | [x] |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — `dashboard`/`payment`/
  `test`/`counseling`/`camera` rows, the permanent findings this slice was
  deliberately scoped around (#1 websocket, #3 logging, #4 face-image
  cleanup), and the "open item" (`payment` status codes) this slice is
  explicitly unaffected by.
- [account.md](account.md) — the NIK sensitive-data checklist this file's
  §3 structure follows, one tier lighter.
- [about.md](about.md) — the environment-constraints writeup (screenshot
  proof not possible in this sandbox) this file points back to.
