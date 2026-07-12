import 'package:camera/camera.dart';

/// Directly reuses the `camera` plugin's own enums (`CameraLensDirection`/
/// `ResolutionPreset`/`ImageFormatGroup`) rather than wrapping them in
/// parallel domain types — `shared` already depends on Flutter and its
/// plugins (unlike `core`), so there's nothing to insulate against here,
/// and the old app made the same choice.
///
/// No `streamImage` flag: unlike the old app's `CameraConfig`, this
/// gateway never starts an image stream itself — a caller that needs raw
/// frames (`test`'s proctoring) calls `CameraController.startImageStream`
/// directly on the `controller` this gateway exposes. Keeps the shared
/// contract to what's actually generic (§1 "extract once") instead of
/// anticipating a stream API only one consumer needs.
class CameraConfig {
  final CameraLensDirection lensDirection;
  final ResolutionPreset resolutionPreset;
  final ImageFormatGroup? imageFormatGroup;

  const CameraConfig({
    required this.lensDirection,
    required this.resolutionPreset,
    this.imageFormatGroup,
  });
}
