import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalImagePreview', () {
    // A 1x1 transparent PNG -- small enough to embed literally, but a
    // real, valid image file so the widget's image-decode step (which
    // Image.file kicks off asynchronously after build) succeeds instead
    // of surfacing a decode error unrelated to what this test is about.
    const onePixelPng = <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x64, 0x60, 0x60, 0x60,
      0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A,
      0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];

    late File tempFile;

    setUp(() {
      tempFile = File(
        '${Directory.systemTemp.path}/local_image_preview_test.png',
      )..writeAsBytesSync(onePixelPng);
    });

    tearDown(() {
      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    testWidgets(
      // kIsWeb is a compile-time constant fixed by the test runner's
      // target (the Dart VM here, never the web compiler), so the
      // kIsWeb==true / Image.network branch this widget exists for
      // cannot be exercised by a standard `flutter test` run -- real
      // gap, found 2026-07-17: `Image.file` crashes outright on Flutter
      // Web (`!kIsWeb` assertion in image.dart), which neither this
      // package's nor any consuming package's test suite could have
      // caught, since none of them run under `flutter test --platform
      // chrome`. That branch is verified by driving the real app in a
      // real browser instead (how this bug was originally found).
      'on native (non-web), renders Image.file with the given path, '
      'fit and dimensions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LocalImagePreview(
                path: tempFile.path,
                fit: BoxFit.contain,
                width: 120,
                height: 80,
              ),
            ),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        final source = image.image as FileImage;
        expect(source.file.path, tempFile.path);
        expect(image.fit, BoxFit.contain);
        expect(image.width, 120);
        expect(image.height, 80);
      },
    );

    testWidgets('defaults to BoxFit.cover when fit is not given', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalImagePreview(path: tempFile.path)),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
    });
  });
}
