import 'package:camera/camera.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockCameraDatasource extends Mock implements CameraDatasource {}

class _FakeCameraDescription extends Fake implements CameraDescription {
  _FakeCameraDescription(this.lensDirection);

  @override
  final CameraLensDirection lensDirection;
}

void main() {
  late _MockCameraDatasource datasource;
  late CameraGatewayImpl gateway;

  setUpAll(() {
    registerFallbackValue(
      const CameraConfig(
        lensDirection: CameraLensDirection.front,
        resolutionPreset: ResolutionPreset.low,
      ),
    );
    registerFallbackValue(_FakeCameraDescription(CameraLensDirection.front));
  });

  setUp(() {
    datasource = _MockCameraDatasource();
    gateway = CameraGatewayImpl(datasource);
  });

  group('CameraGatewayImpl.initialize', () {
    test('approved fix: never substitutes a different camera than requested '
        '— returns a distinct requestedLensNotFound failure instead of the '
        'old app\'s silent cameras.first fallback', () async {
      when(() => datasource.availableCameras()).thenAnswer(
        (_) async => [_FakeCameraDescription(CameraLensDirection.back)],
      );

      final result = await gateway.initialize(
        const CameraConfig(
          lensDirection: CameraLensDirection.front,
          resolutionPreset: ResolutionPreset.low,
        ),
      );

      expect(result.isErr, isTrue);
      final failure = (result as Err<Failure, void>).failure;
      expect(failure, isA<CameraFailure>());
      expect(
        (failure as CameraFailure).reason,
        CameraFailureReason.requestedLensNotFound,
      );

      // The critical assertion: the datasource's initialize() — which
      // would actually open a camera stream — must never be called
      // with the wrong lens. No substitution happens at all.
      verifyNever(() => datasource.initialize(any(), any()));
    });

    test('returns noCameraOnDevice, not an uncaught StateError, when the '
        'device has zero cameras at all', () async {
      when(() => datasource.availableCameras()).thenAnswer((_) async => []);

      final result = await gateway.initialize(
        const CameraConfig(
          lensDirection: CameraLensDirection.front,
          resolutionPreset: ResolutionPreset.low,
        ),
      );

      expect(result.isErr, isTrue);
      final failure = (result as Err<Failure, void>).failure;
      expect(
        (failure as CameraFailure).reason,
        CameraFailureReason.noCameraOnDevice,
      );
    });

    test(
      'initializes normally when the requested lens is actually available',
      () async {
        final front = _FakeCameraDescription(CameraLensDirection.front);
        when(() => datasource.availableCameras()).thenAnswer(
          (_) async => [
            _FakeCameraDescription(CameraLensDirection.back),
            front,
          ],
        );
        when(
          () => datasource.initialize(any(), any()),
        ).thenAnswer((_) async {});

        final result = await gateway.initialize(
          const CameraConfig(
            lensDirection: CameraLensDirection.front,
            resolutionPreset: ResolutionPreset.low,
          ),
        );

        expect(result.isOk, isTrue);
        verify(() => datasource.initialize(front, any())).called(1);
      },
    );

    test(
      'maps a native CameraException (e.g. permission denied) to a '
      'permissionDenied failure instead of letting it propagate uncaught',
      () async {
        when(() => datasource.availableCameras()).thenAnswer(
          (_) async => [_FakeCameraDescription(CameraLensDirection.front)],
        );
        when(() => datasource.initialize(any(), any())).thenThrow(
          CameraException('CameraAccessDenied', 'User denied camera access'),
        );

        final result = await gateway.initialize(
          const CameraConfig(
            lensDirection: CameraLensDirection.front,
            resolutionPreset: ResolutionPreset.low,
          ),
        );

        expect(result.isErr, isTrue);
        final failure = (result as Err<Failure, void>).failure;
        expect(
          (failure as CameraFailure).reason,
          CameraFailureReason.permissionDenied,
        );
      },
    );
  });

  group('CameraGatewayImpl.captureImage', () {
    test('returns the file path on success', () async {
      when(
        () => datasource.captureImage(),
      ).thenAnswer((_) async => '/tmp/frame.jpg');

      final result = await gateway.captureImage();

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, String>).value, '/tmp/frame.jpg');
    });

    test('maps a capture-time exception to captureFailed', () async {
      when(
        () => datasource.captureImage(),
      ).thenThrow(Exception('no controller'));

      final result = await gateway.captureImage();

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, String>).failure,
        isA<CameraFailure>().having(
          (f) => f.reason,
          'reason',
          CameraFailureReason.captureFailed,
        ),
      );
    });
  });

  group('CameraGatewayImpl passthrough', () {
    test(
      'dispose/isInitialized/controller delegate to the datasource',
      () async {
        when(() => datasource.dispose()).thenAnswer((_) async {});
        when(() => datasource.isInitialized).thenReturn(true);
        when(() => datasource.controller).thenReturn(null);

        await gateway.dispose();

        expect(gateway.isInitialized, isTrue);
        expect(gateway.controller, isNull);
        verify(() => datasource.dispose()).called(1);
      },
    );
  });
}
