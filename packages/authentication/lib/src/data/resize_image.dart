import 'dart:io';

import 'package:image/image.dart' as img;

/// Resizes an image file down to 800px wide, re-encoded as JPEG — same
/// dimensions as the old app's `resizeImage()` (`lib/src/core/constants/
/// reusable.dart`). Returns bytes directly instead of writing back to the
/// same path: this migration uploads bytes straight from the resize step
/// rather than round-tripping through disk again, so there's one fewer
/// intermediate file to ever worry about cleaning up. Runs on the calling
/// isolate, not offloaded via `compute()` — consistent with `feature_test`'s
/// own NV21-to-JPEG conversion, which made the same call for a comparably
/// one-off, non-hot-path image operation.
Future<List<int>> resizeImageBytes(String path) async {
  final bytes = await File(path).readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;

  final resized = img.copyResize(image, width: 800);
  return img.encodeJpg(resized);
}
