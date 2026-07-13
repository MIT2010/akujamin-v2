import 'package:core/core.dart';

/// Local (device) notification primitive — app-wide, one consumer today
/// (the dashboard shell, TAHAP 4) but deliberately placed in `shared`
/// alongside [CameraGateway]/`SocketGateway` rather than a feature package,
/// same §3 "extract once" reasoning: it is cross-feature glue, not one
/// feature's private concern, the moment `AuthCubit.logout()` is the single
/// authoritative caller of [cancelAll].
///
/// **Gateway never silently substitutes** (§7): the old app's
/// `NotificationLocalServiceImpl.show()` requested permission but never
/// checked the *result* of that request before calling `plugin.show()`
/// regardless — so a denied permission produced a silently-dropped
/// notification with no way for a caller to know. [show] returns an honest
/// `Err(NotificationFailure(permissionDenied, ...))` instead.
///
/// **Redaction and routing are explicitly not this gateway's job.** What
/// text goes in `title`/`body`, and what happens when a notification is
/// tapped, are call-site decisions (the dashboard shell, TAHAP 4) — this
/// gateway only delivers what it's given and reports [onNotificationTapped]
/// honestly, the same passive-stream shape `SocketGateway.events` already
/// established.
abstract class NotificationGateway {
  Stream<String?> get onNotificationTapped;

  Future<Result<Failure, void>> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}
