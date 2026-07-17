import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Renders a locally-captured/picked image, correctly on every platform
/// including web — real bug, found 2026-07-17 during live web testing:
/// `Image.file` asserts `!kIsWeb` internally and crashes outright on
/// Flutter Web (`"Image.file is not supported on Flutter Web"`), hit
/// directly by both the register flow's selfie preview and the payment
/// flow's bukti-pembayaran preview, each constructing `Image.file(File(
/// path))` unconditionally. On web, `path` is never a real filesystem
/// path in the first place — the `camera` and `image_picker` packages'
/// own web implementations hand back an `XFile` backed by a `blob:` URL
/// — so `Image.network(path)` is the correct call there, not a
/// workaround: the browser fetches a `blob:` URI the same way it
/// fetches an `http(s):` one.
class LocalImagePreview extends StatelessWidget {
  const LocalImagePreview({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(path, fit: fit, width: width, height: height);
    }
    return Image.file(File(path), fit: fit, width: width, height: height);
  }
}
