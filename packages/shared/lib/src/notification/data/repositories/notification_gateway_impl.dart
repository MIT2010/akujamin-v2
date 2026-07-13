import 'package:core/core.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/repositories/notification_gateway.dart';
import '../datasources/notification_datasource.dart';

/// Real fix, not a port: the old app's `NotificationLocalServiceImpl.show()`
/// did
/// ```dart
/// if (!status.isGranted) {
///   await Permission.notification.request();
/// }
/// await plugin.show(...); // unconditional — request()'s result was discarded
/// ```
/// so a user who denied the permission prompt still had `plugin.show()`
/// called on their behalf, silently doing nothing (or erroring, depending on
/// platform) with no way for any caller to react. This gateway captures the
/// result of [NotificationDatasource.requestPermission] and only calls
/// through to the plugin when it's actually granted — same "never silently
/// substitutes" principle as [CameraGatewayImpl]'s lens-fallback fix.
@LazySingleton(as: NotificationGateway)
class NotificationGatewayImpl implements NotificationGateway {
  final NotificationDatasource _datasource;
  NotificationGatewayImpl(this._datasource);

  @override
  Stream<String?> get onNotificationTapped => _datasource.onNotificationTapped;

  @override
  Future<Result<Failure, void>> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _datasource.ensureInitialized();

      var status = await _datasource.permissionStatus();
      if (!status.isGranted) {
        status = await _datasource.requestPermission();
      }

      if (!status.isGranted) {
        return const Err(
          NotificationFailure(
            NotificationFailureReason.permissionDenied,
            'Izin notifikasi ditolak.',
          ),
        );
      }

      await _datasource.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
      return const Ok(null);
    } catch (e) {
      return Err(
        NotificationFailure(NotificationFailureReason.showFailed, e.toString()),
      );
    }
  }

  @override
  Future<void> cancel(int id) async {
    await _datasource.ensureInitialized();
    await _datasource.cancel(id);
  }

  @override
  Future<void> cancelAll() async {
    await _datasource.ensureInitialized();
    await _datasource.cancelAll();
  }
}
