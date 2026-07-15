# QA checklist — `counseling` (session list + realtime chat)

Migrated from the old app's `counseling` feature — session list
(`counseling_page.dart`/`CounselingStateCubit`, read-only, fetch-once) and
a single realtime chat thread (`chat_page.dart`/`ChatStateCubit`, the
`konseling.<voucher>` Pusher channel). Landed as a new package,
`packages/feature_counseling`. Full audit trail — reconnect behavior,
attachment support (confirmed none exists), the corrected scope of
permanent finding #1, and the new permanent finding #6 — is in
[MIGRATION_LOG.md](../../MIGRATION_LOG.md), written *before* any code, per
the standing instruction for this slice.

---

## Sensitive-data checklist (MIGRATION_PLAYBOOK.md §3) — chat transcripts

**Same seriousness tier as raw test answers** (per explicit instruction
for this feature), even though the storage/lifecycle side is simpler —
there's no local cache to worry about clearing.

### 1. Field inventory

| Field | Where it appears | Sensitivity |
|---|---|---|
| `message` | `GET /chat/detail-conversation` response, `sent` socket event payload | **High** — psychological counseling content, the same tier as a raw test answer |
| `sender_type` | Same sources | Low (metadata: `'participant'` vs the psychologist) |
| `sender_id` | `sendMessage`'s request only | Low (already an opaque user id, not new PII) |
| `created_at` | Same sources | Low |
| `kode_voucher`/`code` | Session list + channel name + chat request param | Low-medium (linkable to a specific test session) |
| `psikolog_name`/`psychologist` | Session list | Low |

### 2. Storage tier

**No decision needed at all** — same conclusion as `feature_history`.
`ChatRepository`/`CounselingRepository` have no local datasource, no
cache (§11 doesn't apply). Messages exist only in `ChatCubit`'s in-memory
state for the lifetime of the chat page; nothing is written to
`SecureTokenStorage`, `shared_preferences`, or any file. Closing the chat
page (or logging out) discards them along with the rest of the widget
tree — there is nothing to explicitly clear because nothing persists.

### 3. Transit and logging

Both `CounselingRemoteDataSource` and `ChatRemoteDataSource` go through
`core`'s `ApiClient` → `LoggingInterceptor`, which only ever logs
method + URI, never bodies — same conclusion as every prior feature.

**Two things specifically re-verified for this feature, not just
inherited by assumption:**

- **`getChat`'s response (the transcript itself) would leak in the OLD
  app** — permanent finding #3, unchanged: `LoggerInterceptor.onResponse`
  logs `'Data: ${response.data}'` unconditionally, and a decoded JSON
  `Map`/`List` has a meaningful `toString()`. Not inherited here — `core`'s
  interceptor doesn't log bodies at all.
- **`sendMessage`'s request body is genuinely safe, confirmed by reading
  `dio`'s own source** (permanent finding #3, upgraded from inference to
  verified 2026-07-11): `FormData` declares no `toString()` override, so
  even the old app's leaky interceptor would only print
  `Instance of 'FormData'` for this specific call — not the message text.
  `ChatRemoteDataSource.sendMessage` deliberately keeps using `FormData`
  (not a raw JSON body) to preserve this property, not just for old-app
  fidelity.

### 4. Lifecycle

- **Nothing to clear on logout** — no persistence exists (§2).
- **The websocket connection itself is torn down deliberately, not left
  dangling** — see "Explicit decisions" below (unsubscribe-on-close).
  This isn't a §3 sensitive-data requirement on its own, but a dangling
  socket connection is a resource a `sendMessage`/transcript could
  theoretically still flow through if something were wrong elsewhere;
  tearing it down promptly removes that surface entirely rather than
  leaving it as a "should be fine" assumption.

### 5. Explicitly out of scope

- **Raw message content in system notifications** — permanent finding #6.
  A `dashboard`-shell + `notification`-infrastructure concern (neither
  migrated yet), not something `counseling`'s own migration touches or
  can fix. Recorded in MIGRATION_LOG.md with an explicit recommendation
  for when that day comes.
- **`payment`'s write-path / PT-TP status codes** — unrelated field,
  confirmed by reading both old-app sources; this slice never touches it.

---

## Explicit decisions (not silent choices) — approved before code started

All four were proposed during the pre-code audit and explicitly approved
before any implementation:

**(a) Websocket connection layer is self-contained inside
`feature_counseling`**, not extracted to a shared `packages/websocket` —
`test` will need realtime eventually too, but there's no second consumer
today to justify the extraction (playbook §1 "extract once"). Revisit
when `test` is migrated.

**(b) Reconnect uses exponential backoff with a cap, not the old app's
unconditional-immediate-retry-forever.** `ReconnectBackoff`:
`1s → 2s → 4s → 8s → 16s → 30s` (capped), reset to `1s` after a
successful reconnect. `30s` was chosen as a cap most users would tolerate
without assuming the feature is broken during a brief network blip — not
derived from any documented server-side rate limit (none exists to
reference). Unit-tested directly (`reconnect_backoff_test.dart`), not
just exercised indirectly through the cubit.

**(c) The chat cubit explicitly unsubscribes (and, if it's the last
active channel, disconnects) when leaving an active — not yet `ended` —
chat.** The old app's `ChatStateCubit.close()` only cancelled its own two
local `StreamSubscription`s; the Pusher channel and the underlying socket
connection stayed alive for the rest of the app's life. Verified this is
now correct even with multiple potential concurrent chats (the socket
gateway is a shared `@LazySingleton`): `unsubscribe()` only tears the
connection down once *no* channel needs it anymore, so one chat closing
early can't kill a connection a different, still-open chat depends on —
see `CounselingSocketGatewayImpl.unsubscribe`'s doc comment.

**(d) The `sent` event filter checks `kode_voucher` matches the open
chat, in addition to `sender_type != 'participant'`.** The old app only
checked the latter — a latent cross-channel bug, harmless there because
only one chat channel was ever practically subscribed at a time, but a
real risk here specifically because the gateway is a shared singleton
(see (c)). New code doesn't inherit it — proven by a dedicated regression
test (`ignores a sent event for a different kode_voucher`), not just
asserted in a comment.

**(e) `MessageStatus` is deliberately honest, not a fake read-receipt
system.** The old app's UI had a `sending/sent/delivered/read` enum that
was purely decorative — nothing in `ChatStateCubit` ever set `delivered`
or `read`, `Message.status` always defaulted to `sent`. This migration's
`ChatMessageStatus` only has `pending`/`sent`/`failed` — states the app
can actually verify (a send request is in flight vs. succeeded vs.
failed). No `delivered`/`read` exists anywhere in the type, so it's not
possible to accidentally wire up a fake receipt later either — verified
by a dedicated widget test asserting `'Delivered'`/`'Read'`/`'Dibaca'`
never render.

---

## Environment constraints

Same screenshot-proof limitation as every prior feature — see
[about.md](about.md). One feature-specific addition:

**The real Pusher-protocol websocket connection itself was not exercised
against a live server** — this sandbox has no Pusher/Soketi test server
available, and standing one up was judged out of proportion to this
slice's scope. What **was** verified, and how:

- **All of the business logic around realtime** — event filtering
  (`sender_type`, `kode_voucher`), the optimistic-send/echo-filter pairing
  (the specific regression this feature's definition-of-done calls out),
  the `ended` transition, unsubscribe-on-close — is fully exercised via
  `ChatCubit`'s tests against a controllable fake
  (`_FakeSocketGateway`, a real `StreamController` the test pushes
  fabricated `SocketEvent`s into and asserts real subscribe/unsubscribe
  call history against — not a mocktail mock standing in for behavior
  that was never actually exercised).
- **The reconnect backoff math itself** is unit-tested directly
  (`reconnect_backoff_test.dart`) — the delay sequence and the cap are
  proven as pure values, independent of any real connection.
- **Not verified**: the actual `dart_pusher_channels` wire-level
  integration (does `CounselingSocketGatewayImpl` correctly parse a real
  server's Pusher-protocol frames, does the real library's
  `connectionErrorHandler` actually invoke the callback the way this
  code assumes). This is a real, disclosed gap — flagged rather than
  silently assumed to work, same standard as every other environment
  constraint in this project.

---

## Real verification performed (two throwaway files, run then deleted)

1. **Real network pipeline.** A real local `HttpServer` implementing
   `/v1/chat/list`, `/v1/chat/detail-conversation`, `/v1/chat/send` —
   **the `/v1/` prefix was `Env.apiUrl`'s assumed convention at the time,
   later proven wrong against the real backend 2026-07-14 (see
   MIGRATION_LOG.md's permanent findings): the real server has no
   versioning concept, the correct path is `/api/chat/list` etc. This
   test double matched the code's own assumption, not the real server —
   recorded as-is, not rewritten.** — hit through the real DI-resolved
   `CounselingRepository` and
   `ChatRepository` chains (a plain `test()`, not `testWidgets()` — see
   [history.md](history.md)'s note on why `testWidgets()`'s
   `TestWidgetsFlutterBinding` blocks real HTTP). Confirmed: session list
   fields map correctly (`kode_voucher → code`, `psikolog_name →
   psychologist`), chat history fields map correctly (`sender_type →
   senderType`), and `sendMessage` genuinely round-trips through a real
   `FormData` POST.
2. **Real `App`/`AppRouter`/DI, pre-seeded auth state.** Booted the real
   `App`, navigated to `/home`, invoked the real "Konseling"
   `IconButton`'s `onPressed` (same `tester.tap()` coordinate-space
   workaround as `history.md`), confirmed the real `CounselingListPage`
   renders, then navigated to `/chat/ABC123?psychologist=Budi` and
   confirmed that page also renders (`AppBar` title "Budi") with no
   redirect loop.

---

## Side-by-side checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka daftar sesi konseling | Daftar sesi tampil dengan psikolog, tanggal, status | `CounselingPage` → `CounselingStateCubit` → `GetCounselingUsecase`, render `CounselingTimeline` per sesi | `CounselingListPage` → `CounselingCubit.getSessions()` → real `/chat/list` — verified widget test + real-network test (field mapping exact) | [x] |
| Sesi dengan status `finished` | Tombol Chat nonaktif | `hasDone ? null : onPressed` | Sama persis — verified widget test | [x] |
| Buka thread chat | Riwayat pesan tampil, koneksi realtime terbentuk | `ChatPage` → `ChatStateCubit.getChat()` → `subscribe()` (yang men-`connect()` sendiri) | `ChatPage` → `ChatCubit.getMessages()` → real `/chat/detail-conversation`, lalu subscribe ke `konseling.<code>` — verified widget test + real-network test + cubit test (channel disubscribe dikonfirmasi) | [x] |
| Psikolog mengirim pesan (event `sent`) | Pesan baru muncul di thread | Listener global filter `sender_type != participant` | Filter yang sama, DITAMBAH cek `kode_voucher` cocok (perbaikan disengaja, lihat keputusan (d) di atas) — verified cubit test | [x] |
| Kirim pesan dari user | Pesan langsung tampil (optimistic), lalu status berubah jadi "Terkirim" | Optimistic append + filter echo `sender_type == participant` di listener | Pasangan yang sama persis, dibuktikan dengan test regresi khusus — tidak dobel, tidak hilang | [x] |
| Kirim pesan gagal (server error) | Pesan tetap terlihat, ada indikasi gagal | `state.copyWith(error: error)`, pesan lokal tetap ada tanpa indikator visual | Pesan lokal tetap ada, status berubah jadi "Gagal terkirim" (nyata, bukan dekoratif) — verified cubit test + widget test | [x] |
| Sesi konseling berakhir (event `ended`) | Input pesan diganti banner "Konseling Selesai" | `ChatStatus.ended`, tampilkan `AppCard` + tombol "Mulai Tes Kedua" (nyata, navigasi ke `test`) | Banner yang sama, tombol "Mulai Tes Kedua" menampilkan `AppDialog.info` (placeholder disengaja — `test` belum dimigrasi) — verified widget test | [x] — placeholder disengaja, dicatat |
| Keluar dari chat yang belum berakhir | — | Channel + koneksi socket TETAP hidup (bug, tidak disengaja) | Channel di-unsubscribe eksplisit saat `close()` (perbaikan disengaja, lihat keputusan (c)) — verified cubit test | [x] — perbaikan, bukan port apa adanya |
| Koneksi socket terputus | Reconnect otomatis, resubscribe channel yang aktif | Retry langsung tanpa batas, tanpa delay bertambah | `resubscribeAll()` yang sama persis dipicu ulang setelah reconnect, TAPI retry pakai exponential backoff berjenjang (1s→30s, capped) — lihat keputusan (b). Tidak diverifikasi terhadap server Pusher sungguhan (lihat Environment constraints) | [ ] — logika backoff diverifikasi unit test, integrasi wire-level tidak diverifikasi di sandbox ini |
| Item "Konseling" di halaman Riwayat | Navigasi ke chat sungguhan | N/A — halaman Riwayat baru ada di app ini | `context.push('/chat/<code>?psychologist=...')` — placeholder `AppDialog.info` sebelumnya diganti navigasi nyata sekarang `counseling` sudah dimigrasi — verified widget test (feature_history) | [x] |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — `counseling` row, the
  corrected permanent finding #1 (self-contained connect, no dependency
  on auth's deferred websocket hook), the upgraded permanent finding #3
  (FormData verified safe), and the new permanent finding #6 (raw
  message content in system notifications).
- [history.md](history.md) — the `testWidgets()`/`HttpOverrides` lesson
  this file's real-network verification approach reuses, and the
  `tester.tap()` coordinate-space workaround reused for the routing
  verification.
- [about.md](about.md) — the environment-constraints writeup (screenshot
  proof not possible in this sandbox) this file points back to.
