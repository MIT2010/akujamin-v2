import 'dart:io';
import 'dart:typed_data';

import 'package:authentication/src/data/resize_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('resizeImageBytes', () {
    late File tempFile;

    setUp(() {
      // A real, valid 100x100 image -- resizeImageBytes runs it through
      // img.decodeImage/copyResize/encodeJpg, so the input has to be a
      // genuine image, not arbitrary bytes.
      final source = img.Image(width: 100, height: 100);
      tempFile = File(
        '${Directory.systemTemp.path}/resize_image_test_source.png',
      )..writeAsBytesSync(img.encodePng(source));
    });

    tearDown(() {
      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    test('reads via XFile (not dart:io\'s File directly) and returns resized '
        'JPEG bytes -- real bug, found 2026-07-17 from a live web scan/'
        'submit: File(path).readAsBytes() throws "Unsupported operation: '
        '_Namespace" on Flutter Web, since path is a blob: URL there, not '
        'a real filesystem path', () async {
      final result = await resizeImageBytes(tempFile.path);

      expect(result, isNotEmpty);
      final decoded = img.decodeImage(Uint8List.fromList(result));
      expect(decoded, isNotNull);
      // resizeImageBytes always targets 800px wide (its own doc
      // comment) -- confirms the resize step actually ran against
      // bytes genuinely read from the file, not just that some bytes
      // came back.
      expect(decoded!.width, 800);
    });
  });
}
