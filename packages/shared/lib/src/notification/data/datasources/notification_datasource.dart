import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin, throwing wrapper around `flutter_local_notifications` +
/// `permission_handler` — mirrors [CameraDatasource]'s division of labour:
/// raw plugin calls here, permission-then-show business logic one layer up
/// in `NotificationGatewayImpl`.
///
/// Lazily initializes the plugin on first use (memoized, not repeated per
/// call) rather than exposing a separate `init()` step a caller could forget
/// — the old app's `InitNotificationUsecase` had to be remembered to run at
/// app bootstrap; this can't be skipped by omission.
@injectable
class NotificationDatasource {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<String?>.broadcast();
  Future<void>? _initFuture;

  Stream<String?> get onNotificationTapped => _tapController.stream;

  Future<void> ensureInitialized() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _tapController.add(response.payload);
      },
    );
  }

  Future<PermissionStatus> permissionStatus() => Permission.notification.status;

  Future<PermissionStatus> requestPermission() =>
      Permission.notification.request();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(),
      payload: payload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelAll() => _plugin.cancelAll();

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'default_channel',
        'General',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
  }
}
