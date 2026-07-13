# QA checklist — `dashboard` shell + `notification` infrastructure

Migrated from the old app's `dashboard/presentation/widgets/dashboard_layout.dart`
(`CustomBottomNavBar` + the three global socket-event handlers
`_handleConfirm`/`_handleSent`/`_handleEnded`) and
`notification/data/datasources/notification_local_service.dart`. Landed
across four stages (TAHAP 1-4), each committed and CI-verified
separately:

- **TAHAP 1** — websocket gateway extracted from `feature_counseling`/
  `feature_payment` into `packages/shared` (`SocketGateway`), a prerequisite
  for the dashboard listener below to ever receive events at all.
- **TAHAP 2** — `NotificationGateway` built in `packages/shared`
  (`flutter_local_notifications` + `permission_handler`).
- **TAHAP 3** — `AppRouter.shellRoutes`/`AppShell` wired into
  `apps/mobile`: `/home`/`/history`/`/profile` behind a persistent
  bottom-nav (Beranda/Riwayat/Akun), matching `CustomBottomNavBar`.
- **TAHAP 4** — `DashboardNotificationListener` (`apps/mobile`), the port
  of `_handleConfirm`/`_handleSent`/`_handleEnded`, with the notification
  content fix this file's sensitive-data section documents.

Full audit trail — the corrected scope of permanent finding #1, and
permanent finding #6 (raw message content in system notifications, later
expanded to cover `confirmationPassed`'s raw-payload-spread too) — is in
[MIGRATION_LOG.md](../../MIGRATION_LOG.md).

---

## Sensitive-data checklist (MIGRATION_PLAYBOOK.md §3) — notification content

### 1. Field inventory

| Field | Where it appears | Sensitivity | Reaches a notification? |
|---|---|---|---|
| `payload['payload']` (`status_lulus`, exam result fields) | `konfirmasi.kelulusan` socket event | **High** — exam pass/fail result data | **No** — real fix, see §3 below |
| `message` | `sent` socket event | **High** — psychological counseling content, same tier as `counseling.md`'s finding | **No** — real fix, see §3 below |
| `sender_type`, `kode_voucher` | `sent`/`ended` socket events | Low (metadata, used only for filtering/routing, never rendered) | No |
| Notification title/body (generic) | `NotificationGateway.show()`'s `title`/`body` args | None — fixed, non-derived strings | Yes, by design |

### 2. Storage tier

**No decision needed.** `DashboardNotificationListener` holds no state of
its own beyond a single `StreamSubscription` — every event is handled and
discarded, nothing is written to `SecureTokenStorage`, `shared_preferences`,
or any file. The one piece of state this slice *does* persist
(`psychologist-id`, for the `conf.<psychologistId>` channel cleanup) is
`feature_payment`'s own storage, already covered by
[payment.md](payment.md) and its ADR-011-class fix — this feature only
reads/clears it via `PaymentRepository`, doesn't add a new storage
location.

### 3. Transit and logging — the real fix, not a port

**Real fix for permanent finding #6 (expanded 2026-07-13):** the old
app's handlers put raw content directly into a rendered OS notification —
lock screen and notification shade included, a materially more exposed
surface than the in-app screen itself:

```dart
// confirmationPassed — the expanded half of finding #6, found while
// building this slice: spreads the ENTIRE raw event payload into the
// notification's data (isStatic defaults false, so ...payload applies),
// with no meaningful title/body of its own.
_showNotification(payload: payload);

// chatSent — the originally-recorded half of finding #6.
_showNotification(title: 'Konseling', body: payload['message'], ...);
```

`DashboardNotificationListener`'s `_handleConfirm`/`_handleSent` now call
`NotificationGateway.show()` with **fixed, generic, non-derived** text —
`'Ada pembaruan status kelulusan tes kamu.'` and `'Kamu menerima pesan
baru dari psikolog.'` respectively. Neither the raw payload map nor the
message text is passed anywhere near `NotificationGateway`. Proven
directly, not just described: `dashboard_notification_listener_test.dart`
pushes a fake event containing a deliberately distinctive payload string
(`'Pesan rahasia dari psikolog'` / `'nama': 'Rahasia'`) and asserts the
exact `verify()`-checked call to `NotificationGateway.show()` never
contains it.

`_handleEnded`'s body was already a safe static string in the old app
(`'Sesi konseling telah berakhir...'`) — ported unchanged, no fix needed
there.

### 4. Lifecycle

- **`NotificationGateway.cancelAll()` on logout** — wired into
  `AuthCubit.logout()` as the single authoritative call site (not
  scattered across UI logout buttons), so a pending notification about
  one user's exam/counseling activity can't linger visible after they've
  logged out on a shared device. Proven directly:
  `auth_cubit_test.dart`'s logout regression test verifies
  `NotificationGateway.cancelAll()` is called exactly once.
- **The dashboard listener's own `StreamSubscription` is cancelled in
  `dispose()`** — it lives for the whole authenticated app session
  (wraps `MaterialApp.router`, not scoped to `AppShell`'s three tabs — see
  §5(a) below for why), so in practice this only fires on full app
  teardown, but it's still explicit, not left to garbage collection.

### 5. Explicitly out of scope

- **Tap-to-navigate deep-linking (`NotificationRouter`-equivalent).**
  `NotificationGateway.onNotificationTapped` (a `Stream<String?>`, built in
  TAHAP 2) exists and is exposed, but nothing in `apps/mobile` subscribes
  to it yet — a deliberate scope decision, not an oversight. The old app's
  `NotificationRouter.handle(payload)` branches on
  `type`/`status_lulus`/`event` fields and includes a hardcoded URL-domain
  replacement (`partner.pmi.dev.caina` → a local IP) that was flagged
  during the original audit as not fully understood and not something to
  faithfully port. Rebuilding that table wasn't part of this slice's
  explicit definition of done (websocket extraction, gateway,
  shell-wiring, content fix, cleanup port) — recorded here so it isn't
  silently assumed to exist.
- **Real push-notification delivery on a physical device** — see
  Environment constraints below.

---

## Explicit decisions (not silent choices) — reasoned during TAHAP 1-4

**(a) `DashboardNotificationListener` wraps `MaterialApp.router`, not
`AppShell`.** `AppShell`/`ShellRoute` only wraps `/home`/`/history`/
`/profile` — every other route (`/payment`, `/counseling`, `/chat/:code`,
etc.) is a sibling standalone route in the same root `Navigator`, which
**unmounts** the shell subtree entirely when navigated to. A listener
scoped to `AppShell`'s lifetime would die the moment a user opened
`/payment` — exactly when a background `confirmationPassed` event is
likely to arrive. `apps/mobile`'s `App` widget is the composition root
that already knows about every feature (`authentication`,
`feature_payment`, `shared`), so the listener lives there instead,
mounted once for the whole session.

**(b) `PaymentRepository` (not a new abstraction) is the psychologist-id
cleanup's data source**, reached directly from `apps/mobile` — the same
cross-feature reach the old app's `dashboard` had into `payment`'s
`GetPsychologistIdUsecase`/`ClearPsychologistIdUsecase`. Not a new
coupling this migration introduced; ported as the explicitly-approved
"already safe, just port it" item.

**(c) The `status_lulus == 'konseling'` skip-cleanup branch is ported
as-is**, unexamined beyond confirming it's already safe: when the
confirmation event's nested payload carries this value, the
`conf.<psychologistId>` channel is deliberately left subscribed (more
events are expected on it); any other status clears the stored id and
unsubscribes. Same logic, same conditions as the old app's
`_handleConfirm`.

**(d) `_isCurrentChat`'s suppression (skip the notification if the user
is already viewing that exact chat) is ported unchanged** — avoids a
redundant system notification duplicating what `ChatPage`/`ChatCubit`
already shows live. Reads `AppRouter.router`'s current location directly
(no `BuildContext` needed), same pattern the old app's
`appRouter.state.matchedLocation` used.

---

## Environment constraints

Same screenshot-proof limitation as every prior feature — see
[about.md](about.md). Feature-specific additions:

- **Real OS-level push notification delivery was not verified on a
  physical device or emulator** — this sandbox has no Android/iOS
  device attached (same constraint class as `register.md`'s camera
  environment note). What **was** verified: every branch of
  `NotificationGatewayImpl`'s permission-check-then-show logic
  (`notification_gateway_impl_test.dart`, TAHAP 2) and every branch of
  `DashboardNotificationListener`'s event-handling logic
  (`dashboard_notification_listener_test.dart`, TAHAP 4) against fakes —
  not the real `flutter_local_notifications` plugin call reaching an
  actual OS notification tray.
- **The permission-prompt UI itself was not visually confirmed** — same
  reasoning as above; the fix (capturing `request()`'s result instead of
  discarding it) is proven at the unit level via `verifyNever`, not by
  watching a real Android permission dialog.

---

## Real verification performed

**Widget tests against real DI registration, not standalone unit tests.**
`dashboard_notification_listener_test.dart` registers a real
`_FakeSocketGateway` (a real `StreamController`, the same pattern as
`feature_counseling`'s `_FakeSocketGateway`) into `getIt`, mounts the real
`DashboardNotificationListener` wrapping a real `MaterialApp.router`
(so `AppRouter.router.routerDelegate.currentConfiguration` — what
`_isCurrentChat` reads — is genuinely populated, not stubbed), pushes
fabricated `SocketEvent`s onto the real stream, and asserts the exact
`NotificationGateway.show()` call (id/title/body) via `mocktail`'s
`verify()` — 9 tests covering all three event types, the
psychologist-cleanup branch, the current-chat suppression, and the
participant-echo filter.

`auth_cubit_test.dart`'s logout test independently proves
`NotificationGateway.cancelAll()` is reached from the single authoritative
call site.

---

## Side-by-side checklist

| Input/Aksi | Ekspektasi | Hasil di app lama | Hasil di app baru | Status |
|---|---|---|---|---|
| Buka app dalam keadaan login | Bottom-nav 3 tab (Beranda/Riwayat/Akun) tampil, persisten di semua tab | `DashboardLayout` + `CustomBottomNavBar` | `AppShell` + `AppRouter.shellRoutes` — verified widget test (`home_page_test.dart`) | [x] |
| Pindah tab Beranda ↔ Riwayat ↔ Akun | Konten berganti, bottom-nav tetap terlihat | `NavCubit` + `context.goNamed` | `context.go(destination.path)` — infrastruktur `AppShell` yang sama, tidak dimodifikasi | [x] — infrastruktur sudah ada sebelumnya, hanya disambungkan |
| Buka `/payment`/`/counseling`/dll dari salah satu tab | Layar penuh di atas shell, bottom-nav hilang sementara | N/A — old app's routing structure not directly comparable | Standalone route, sibling `ShellRoute` — bottom-nav benar-benar unmount, bukan disembunyikan | [x] |
| Event `konfirmasi.kelulusan` diterima, dari psikolog yang sesuai | Notifikasi tampil, TANPA data mentah (nama/status) | `_showNotification(payload: payload)` — **membocorkan seluruh payload mentah** | Judul/isi generik tetap, payload mentah tidak pernah sampai ke gateway — verified widget test dengan payload yang sengaja dibuat mencolok | [x] — perbaikan, bukan port apa adanya |
| Event `konfirmasi.kelulusan` dari psikolog lain | Tidak ada notifikasi | Filter `payload['from'] != 'psikolog.$userId'` | Filter yang sama persis | [x] |
| Status akhir (bukan `konseling`) setelah konfirmasi | Channel `conf.<id>` di-unsubscribe, psychologist-id dibersihkan | Ya | Ya — sama persis, verified dengan assert unsubscribe channel | [x] |
| Status `konseling` setelah konfirmasi | Channel TETAP hidup | Ya | Ya — sama persis, verified `unsubscribedChannels` kosong | [x] |
| Event `sent` diterima, chat TIDAK sedang dibuka | Notifikasi generik tampil | `body: payload['message']` — **isi pesan mentah bocor ke notification tray** | Judul/isi generik ('Kamu menerima pesan baru dari psikolog.'), pesan asli tidak pernah sampai — verified widget test | [x] — perbaikan, bukan port apa adanya |
| Event `sent` diterima, chat SEDANG dibuka | Tidak ada notifikasi (sudah tampil live di ChatPage) | `_isCurrentChat` check | Sama persis — verified widget test dengan router location asli | [x] |
| Event `sent`, `sender_type == participant` (echo pesan sendiri) | Tidak ada notifikasi | Filter di listener | Sama persis — verified widget test | [x] |
| Event `ended` diterima, chat TIDAK sedang dibuka | Notifikasi teks statis aman tampil | Teks statis (sudah aman di app lama) | Teks yang sama persis, lewat `NotificationGateway` — verified widget test | [x] |
| Logout | Semua notifikasi pending dibersihkan | N/A — tidak ada di app lama | `AuthCubit.logout()` memanggil `NotificationGateway.cancelAll()` — verified widget test | [x] — perbaikan baru, bukan di app lama |
| Izin notifikasi ditolak saat `show()` dipanggil | Tidak crash, tidak memanggil plugin | App lama: `request()`'s hasil dibuang, `plugin.show()` tetap dipanggil (bug) | `Err(permissionDenied)` dikembalikan, plugin TIDAK pernah dipanggil — verified `verifyNever` (TAHAP 2) | [x] — perbaikan, bukan port apa adanya |

---

## See also

- [MIGRATION_LOG.md](../../MIGRATION_LOG.md) — permanent finding #1
  (resolved: the `conf.<psychologistId>` connect-on-login gap this
  finding was scoped to is now closed by the shared `SocketGateway` the
  dashboard listens on) and permanent finding #6 (resolved, expanded to
  cover `confirmationPassed`'s raw-payload-spread alongside `chatSent`'s
  raw message).
- [counseling.md](counseling.md) — the corrected scope of permanent
  finding #1, and the originally-recorded half of finding #6 this file
  expands and resolves.
- [payment.md](payment.md) — the ADR-011-class fix for
  `psychologist-id`'s storage key, reused (not re-fixed) here.
- [about.md](about.md) — the environment-constraints writeup (screenshot
  proof not possible in this sandbox) this file points back to.
