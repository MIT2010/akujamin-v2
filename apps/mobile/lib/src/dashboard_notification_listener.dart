import 'dart:async';

import 'package:authentication/authentication.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:flutter/widgets.dart';
import 'package:shared/shared.dart';

/// Ported from the old app's `DashboardLayout` (`_handleConfirm`/
/// `_handleSent`/`_handleEnded`), moved from a bottom-nav-scoped widget to
/// wrapping the whole [MaterialApp.router] in `App` — the equivalent
/// bottom-nav-scoped placement here (inside `AppShell`, which only wraps
/// `/home`/`/history`/`/profile`) would tear this listener down the moment
/// the user opens `/payment`, `/counseling`, or any other standalone route,
/// which is exactly when a background confirmation/chat event is most
/// likely to arrive. `apps/mobile` is the composition root that already
/// knows about every feature (`authentication`, `feature_payment`,
/// `shared`), so it — not `AppShell` in `shared` — is where this belongs.
///
/// Listens on `shared`'s app-wide [SocketGateway] (MIGRATION_LOG.md
/// permanent finding #1's resolution) rather than subscribing itself —
/// the dashboard never called `subscribe()` in the old app either, it only
/// reacted to whatever channels `counseling`/`payment` had already opened.
///
/// **Real fix for permanent finding #6 (expanded)**: the old app's
/// `confirmationPassed` handler spread the entire raw event payload into
/// the notification (`...payload`, no title/body given), and `chatSent`
/// put the raw message text directly in the notification body
/// (`body: payload['message']`). Both now go through [NotificationGateway]
/// with fixed, generic, safe text — never the payload or message content
/// itself. `chatEnded`'s body was already a safe static string in the old
/// app; ported unchanged.
class DashboardNotificationListener extends StatefulWidget {
  const DashboardNotificationListener({super.key, required this.child});

  final Widget child;

  @override
  State<DashboardNotificationListener> createState() =>
      _DashboardNotificationListenerState();
}

class _DashboardNotificationListenerState
    extends State<DashboardNotificationListener> {
  StreamSubscription<SocketEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = getIt<SocketGateway>().events.listen(_handleEvent);
  }

  void _handleEvent(SocketEvent event) {
    switch (event.type) {
      case 'konfirmasi.kelulusan':
        _handleConfirm(event);
      case 'sent':
        _handleSent(event);
      case 'ended':
        _handleEnded(event);
    }
  }

  Future<void> _handleConfirm(SocketEvent event) async {
    final payload = event.payload;

    final userId = switch (getIt<AuthCubit>().state) {
      AuthAuthenticated(:final user) => user.id,
      _ => null,
    };
    if (payload['from'] != 'psikolog.$userId') return;

    await getIt<NotificationGateway>().show(
      id: 1,
      title: 'Konfirmasi Kelulusan',
      body: 'Ada pembaruan status kelulusan tes kamu.',
    );

    // Cleanup, ported as-is (already safe): the channel this event arrived
    // on is `conf.<psychologistId>` — the same one PaymentCubit subscribed
    // to, stored via the ADR-011-fixed PaymentLocalDataSource. A
    // `status_lulus == 'konseling'` result means more events are still
    // expected on this channel, so it isn't torn down yet.
    final psychologistId = await getIt<PaymentRepository>().getPsychologistId();
    if (psychologistId == null) return;

    final data = payload['payload'];
    if (data is Map && data['status_lulus'] == 'konseling') return;

    await getIt<PaymentRepository>().clearPsychologistId();
    await getIt<SocketGateway>().unsubscribe('conf.$psychologistId');
  }

  Future<void> _handleSent(SocketEvent event) async {
    final payload = event.payload;

    // Already live in ChatPage/ChatCubit — a system notification on top
    // would just be a redundant duplicate of what the open chat already
    // shows in real time.
    if (_isCurrentChat(payload['kode_voucher'] as String?)) return;
    if (payload['sender_type'] == 'participant') return;

    await getIt<NotificationGateway>().show(
      id: 1,
      title: 'Konseling',
      body: 'Kamu menerima pesan baru dari psikolog.',
    );
  }

  Future<void> _handleEnded(SocketEvent event) async {
    final payload = event.payload;

    if (_isCurrentChat(payload['kode_voucher'] as String?)) return;

    await getIt<NotificationGateway>().show(
      id: 1,
      title: 'Konseling',
      body: 'Sesi konseling telah berakhir. Kamu bisa melanjutkan ujian ke 2.',
    );
  }

  bool _isCurrentChat(String? voucherCode) {
    if (voucherCode == null) return false;
    final location =
        getIt<AppRouter>().router.routerDelegate.currentConfiguration.uri.path;
    return location == '/chat/$voucherCode';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
