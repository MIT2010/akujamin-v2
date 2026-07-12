import 'package:camera/camera.dart';
import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import 'selfie_camera_state.dart';

/// Self-contained in `authentication`, not promoted to `shared` (§1
/// "extract once" — `register`'s selfie capture is the *first* consumer of
/// this exact "simple still-photo capture" cubit shape; `CameraGateway`
/// itself is already shared, this is just the thin cubit wrapping it for
/// this one screen's lifecycle).
///
/// Confirmed during the register audit: the old app's selfie flow
/// (`CameraStateCubit`) never used ML Kit or live face detection — just
/// `initCamera()` → `takePhoto()` → `pausePreview()`, `resumePreview()` on
/// retry. `CameraGateway`'s existing `initialize`/`captureImage`/`dispose`
/// trio (built for the camera/proctoring prerequisite) covers all of that
/// already; `pausePreview()`/`resumePreview()` are called directly on the
/// `CameraController` the gateway already exposes — no gateway API change
/// needed.
@injectable
class SelfieCameraCubit extends Cubit<SelfieCameraState> {
  SelfieCameraCubit(this._gateway) : super(const SelfieCameraState());

  final CameraGateway _gateway;

  /// Exposed so `SelfieCaptureView` can render `CameraPreview(gateway.
  /// controller!)` directly — the controller itself isn't part of
  /// [SelfieCameraState] (a `CameraController` isn't a value type worth
  /// comparing for `Equatable`/freezed equality), same reasoning the old
  /// app's own `CameraField` had for reading `CameraStateCubit.repo`
  /// directly instead of through state.
  CameraGateway get gateway => _gateway;

  Future<void> initCamera() async {
    emit(state.copyWith(isLoading: true));

    final result = await _gateway.initialize(
      const CameraConfig(
        lensDirection: CameraLensDirection.front,
        resolutionPreset: ResolutionPreset.medium,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure)),
      (_) => emit(state.copyWith(isLoading: false, isReady: true)),
    );
  }

  Future<void> takePhoto() async {
    final result = await _gateway.captureImage();

    result.fold((failure) => emit(state.copyWith(error: failure)), (path) {
      emit(state.copyWith(imagePath: path));
      _gateway.controller?.pausePreview();
    });
  }

  void resumePreview() {
    _gateway.controller?.resumePreview();
    emit(state.copyWith(imagePath: null));
  }

  @override
  Future<void> close() async {
    await _gateway.dispose();
    return super.close();
  }
}
