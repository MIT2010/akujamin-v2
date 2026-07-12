import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// NV21 YUV420 -> RGB JPEG conversion for the periodic face-match upload.
/// Ported as-is from the old app's `lib/src/core/constants/reusable.dart`
/// — same algorithm, not re-derived. **Inherited limitation, not
/// introduced here**: this assumes NV21 layout (`image.planes[0]` as one
/// contiguous Y+VU buffer), which only matches the Android camera config
/// (`ImageFormatGroup.nv21`); the old app used this same function
/// unconditionally on iOS too, where the stream is actually `bgra8888` —
/// a pre-existing correctness gap this migration doesn't newly introduce,
/// flagged here rather than silently carried forward unremarked.
Uint8List convertCameraImageToJpeg(CameraImage image) {
  final width = image.width;
  final height = image.height;

  final Uint8List nv21 = image.planes[0].bytes;

  final out = img.Image(width: width, height: height);

  final frameSize = width * height;

  for (int y = 0; y < height; y++) {
    final uvRow = frameSize + (y >> 1) * width;

    for (int x = 0; x < width; x++) {
      final yp = y * width + x;
      final uvIndex = uvRow + (x & ~1);

      final yValue = nv21[yp] & 0xff;
      final vValue = nv21[uvIndex] & 0xff;
      final uValue = nv21[uvIndex + 1] & 0xff;

      int r = (yValue + 1.370705 * (vValue - 128)).round();
      int g = (yValue - 0.698001 * (vValue - 128) - 0.337633 * (uValue - 128))
          .round();
      int b = (yValue + 1.732446 * (uValue - 128)).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      out.setPixelRgb(x, y, r, g, b);
    }
  }

  return Uint8List.fromList(img.encodeJpg(out, quality: 90));
}
