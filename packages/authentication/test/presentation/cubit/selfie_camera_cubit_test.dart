import 'package:authentication/authentication.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:camera/camera.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockCameraGateway extends Mock implements CameraGateway {}

void main() {
  late _MockCameraGateway gateway;

  setUpAll(() {
    registerFallbackValue(
      const CameraConfig(
        lensDirection: CameraLensDirection.front,
        resolutionPreset: ResolutionPreset.medium,
      ),
    );
  });

  setUp(() {
    gateway = _MockCameraGateway();
    when(() => gateway.dispose()).thenAnswer((_) async {});
  });

  blocTest<SelfieCameraCubit, SelfieCameraState>(
    'initCamera emits [loading, ready] on success',
    build: () {
      when(
        () => gateway.initialize(any()),
      ).thenAnswer((_) async => const Ok(null));
      return SelfieCameraCubit(gateway);
    },
    act: (cubit) => cubit.initCamera(),
    expect: () => [
      const SelfieCameraState(isLoading: true),
      const SelfieCameraState(isLoading: false, isReady: true),
    ],
  );

  blocTest<SelfieCameraCubit, SelfieCameraState>(
    'initCamera emits [loading, error] when the gateway fails to initialize',
    build: () {
      when(() => gateway.initialize(any())).thenAnswer(
        (_) async => const Err(
          CameraFailure(
            CameraFailureReason.permissionDenied,
            'Izin kamera ditolak',
          ),
        ),
      );
      return SelfieCameraCubit(gateway);
    },
    act: (cubit) => cubit.initCamera(),
    expect: () => [
      const SelfieCameraState(isLoading: true),
      const SelfieCameraState(
        isLoading: false,
        error: CameraFailure(
          CameraFailureReason.permissionDenied,
          'Izin kamera ditolak',
        ),
      ),
    ],
  );

  blocTest<SelfieCameraCubit, SelfieCameraState>(
    'takePhoto emits the captured path on success',
    build: () {
      when(
        () => gateway.captureImage(),
      ).thenAnswer((_) async => const Ok('/tmp/selfie.jpg'));
      return SelfieCameraCubit(gateway);
    },
    act: (cubit) => cubit.takePhoto(),
    expect: () => [const SelfieCameraState(imagePath: '/tmp/selfie.jpg')],
  );

  blocTest<SelfieCameraCubit, SelfieCameraState>(
    'takePhoto emits an error and leaves imagePath unset on failure',
    build: () {
      when(() => gateway.captureImage()).thenAnswer(
        (_) async => const Err(
          CameraFailure(
            CameraFailureReason.captureFailed,
            'Gagal mengambil foto',
          ),
        ),
      );
      return SelfieCameraCubit(gateway);
    },
    act: (cubit) => cubit.takePhoto(),
    expect: () => [
      const SelfieCameraState(
        error: CameraFailure(
          CameraFailureReason.captureFailed,
          'Gagal mengambil foto',
        ),
      ),
    ],
  );

  blocTest<SelfieCameraCubit, SelfieCameraState>(
    'resumePreview clears imagePath',
    build: () => SelfieCameraCubit(gateway),
    seed: () => const SelfieCameraState(imagePath: '/tmp/selfie.jpg'),
    act: (cubit) => cubit.resumePreview(),
    expect: () => [const SelfieCameraState()],
  );

  test('close disposes the gateway', () async {
    final cubit = SelfieCameraCubit(gateway);
    await cubit.close();
    verify(() => gateway.dispose()).called(1);
  });
}
