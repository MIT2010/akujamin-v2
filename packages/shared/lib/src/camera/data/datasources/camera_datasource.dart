import 'package:camera/camera.dart' as camera_plugin;
import 'package:camera/camera.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/camera_config.dart';

/// Thin, throwing wrapper around the `camera` plugin — mirrors the old
/// app's `CameraDatasourceImpl`, minus the silent lens-fallback and minus
/// `streamImage` (see [CameraConfig]'s doc comment). Raw exceptions are
/// caught and classified one layer up, in `CameraGatewayImpl` — same
/// division of labour as `core`'s `ApiClient` (raw `DioException`) vs. a
/// repository (typed `Failure`).
@injectable
class CameraDatasource {
  CameraController? _controller;

  Future<List<CameraDescription>> availableCameras() =>
      camera_plugin.availableCameras();

  Future<void> initialize(
    CameraDescription description,
    CameraConfig config,
  ) async {
    _controller = CameraController(
      description,
      config.resolutionPreset,
      enableAudio: false,
      imageFormatGroup: config.imageFormatGroup,
    );

    await _controller!.initialize();
  }

  Future<String> captureImage() async {
    final file = await _controller!.takePicture();
    return file.path;
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  CameraController? get controller => _controller;
}
