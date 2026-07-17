import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Resizes an image file down to 800px wide, re-encoded as JPEG — same
/// dimensions as the old app's `resizeImage()` (`lib/src/core/constants/
/// reusable.dart`). Returns bytes directly instead of writing back to the
/// same path: this migration uploads bytes straight from the resize step
/// rather than round-tripping through disk again, so there's one fewer
/// intermediate file to ever worry about cleaning up. Runs on the calling
/// isolate, not offloaded via `compute()` — consistent with `feature_test`'s
/// own NV21-to-JPEG conversion, which made the same call for a comparably
/// one-off, non-hot-path image operation.
///
/// Real bug, found 2026-07-17 from a live web submit: reading via
/// `dart:io`'s `File(path).readAsBytes()` throws `"Unsupported operation:
/// _Namespace"` on Flutter Web — `dart:io`'s filesystem APIs don't exist
/// there at all, and `path` is a `blob:` URL on web anyway (the `camera`/
/// `image_picker` packages' own web implementations), never a real
/// filesystem path. `XFile` (`package:cross_file`, re-exported by
/// `image_picker`) reads bytes portably: `dart:io`'s `File` under the
/// hood on native, a `blob:`-URL fetch on web.
Future<List<int>> resizeImageBytes(String path) async {
  final bytes = await XFile(path).readAsBytes();
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;

  final resized = img.copyResize(image, width: 800);
  return img.encodeJpg(resized);
}
