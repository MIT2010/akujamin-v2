import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared/shared.dart';

class _MockNotificationDatasource extends Mock
    implements NotificationDatasource {}

void main() {
  late _MockNotificationDatasource datasource;
  late NotificationGatewayImpl gateway;

  setUp(() {
    datasource = _MockNotificationDatasource();
    gateway = NotificationGatewayImpl(datasource);
    when(() => datasource.ensureInitialized()).thenAnswer((_) async {});
  });

  group('NotificationGatewayImpl.show', () {
    test('shows immediately when permission is already granted', () async {
      when(
        () => datasource.permissionStatus(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(
        () => datasource.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      final result = await gateway.show(id: 1, title: 'Judul', body: 'Isi');

      expect(result.isOk, isTrue);
      verify(
        () =>
            datasource.show(id: 1, title: 'Judul', body: 'Isi', payload: null),
      ).called(1);
      verifyNever(() => datasource.requestPermission());
    });

    test('requests permission when not yet granted, and shows once the '
        'request is accepted', () async {
      when(
        () => datasource.permissionStatus(),
      ).thenAnswer((_) async => PermissionStatus.denied);
      when(
        () => datasource.requestPermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(
        () => datasource.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      final result = await gateway.show(id: 1, title: 'Judul', body: 'Isi');

      expect(result.isOk, isTrue);
      verify(() => datasource.requestPermission()).called(1);
      verify(
        () =>
            datasource.show(id: 1, title: 'Judul', body: 'Isi', payload: null),
      ).called(1);
    });

    test('real fix, not a port: when the permission request is still denied, '
        'returns Err(permissionDenied) and never calls the plugin — the old '
        "app's NotificationLocalServiceImpl discarded request()'s result and "
        'called plugin.show() regardless', () async {
      when(
        () => datasource.permissionStatus(),
      ).thenAnswer((_) async => PermissionStatus.denied);
      when(
        () => datasource.requestPermission(),
      ).thenAnswer((_) async => PermissionStatus.denied);

      final result = await gateway.show(id: 1, title: 'Judul', body: 'Isi');

      expect(result.isErr, isTrue);
      final failure = (result as Err<Failure, void>).failure;
      expect(
        (failure as NotificationFailure).reason,
        NotificationFailureReason.permissionDenied,
      );

      // The critical assertion — same shape as CameraGatewayImpl's
      // never-substitutes proof: a denied permission must never reach
      // the plugin at all.
      verifyNever(
        () => datasource.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      );
    });

    test('maps a plugin-level exception to showFailed', () async {
      when(
        () => datasource.permissionStatus(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(
        () => datasource.show(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          payload: any(named: 'payload'),
        ),
      ).thenThrow(Exception('plugin not initialized'));

      final result = await gateway.show(id: 1, title: 'Judul', body: 'Isi');

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, void>).failure,
        isA<NotificationFailure>().having(
          (f) => f.reason,
          'reason',
          NotificationFailureReason.showFailed,
        ),
      );
    });
  });

  group('NotificationGatewayImpl passthrough', () {
    test('cancel delegates to the datasource', () async {
      when(() => datasource.cancel(any())).thenAnswer((_) async {});

      await gateway.cancel(7);

      verify(() => datasource.cancel(7)).called(1);
    });

    test('cancelAll delegates to the datasource', () async {
      when(() => datasource.cancelAll()).thenAnswer((_) async {});

      await gateway.cancelAll();

      verify(() => datasource.cancelAll()).called(1);
    });

    test('onNotificationTapped forwards the datasource stream', () async {
      when(
        () => datasource.onNotificationTapped,
      ).thenAnswer((_) => Stream.value('payload-123'));

      final payload = await gateway.onNotificationTapped.first;

      expect(payload, 'payload-123');
    });
  });
}
