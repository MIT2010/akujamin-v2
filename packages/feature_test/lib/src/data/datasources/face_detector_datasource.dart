import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:injectable/injectable.dart';

/// Raw ML Kit wrapper — mirrors the old app's `FaceDetectorDatasourceImpl`
/// exactly (same `FaceDetectorMode.fast`/`minFaceSize: 0.15`/2s timeout
/// config, same manual `InputImage.fromBytes` conversion). Throws, not
/// `Result`-wrapped — classified one layer up in `ProctoringGatewayImpl`,
/// same division of labour as `CameraDatasource`.
@injectable
class FaceDetectorDatasource {
  late final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

  Future<int> detectFaces(CameraImage image, CameraDescription camera) async {
    final inputImage = _convert(image, camera);

    final faces = await _detector
        .processImage(inputImage)
        .timeout(const Duration(seconds: 2));

    return faces.length;
  }

  InputImage _convert(CameraImage image, CameraDescription camera) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      throw Exception('Unsupported image format');
    }

    final rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
    if (rotation == null) {
      throw Exception('Unsupported rotation');
    }

    final buffer = WriteBuffer();
    for (final plane in image.planes) {
      buffer.putUint8List(plane.bytes);
    }
    final bytes = buffer.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() => _detector.close();
}
