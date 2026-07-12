import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  // markdown_widget renders each block inside a VisibilityDetector, which
  // runs its own internal periodic timer to poll visibility — without
  // this, `flutter_test` fails every test with "A Timer is still pending
  // even after the widget tree was disposed." A zero interval disables
  // that polling, the documented fix for testing anything that uses
  // visibility_detector.
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  group('AppMarkdownText', () {
    testWidgets('renders plain paragraph text', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppMarkdownText(data: 'Hello world')),
      );

      expect(find.text('Hello world'), findsOneWidget);
    });

    testWidgets('renders a heading with its own text', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppMarkdownText(data: '# A Heading')),
      );

      expect(find.text('A Heading'), findsOneWidget);
    });

    testWidgets(
      'renders full CommonMark syntax, not a restricted subset — bold, '
      'list items, and a link label all show up',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AppMarkdownText(
              data:
                  '**Bold text**\n\n'
                  '- First item\n'
                  '- Second item\n\n'
                  '[A link](https://example.com)',
            ),
          ),
        );

        expect(find.textContaining('Bold text'), findsOneWidget);
        expect(find.textContaining('First item'), findsOneWidget);
        expect(find.textContaining('Second item'), findsOneWidget);
        expect(find.textContaining('A link'), findsOneWidget);
      },
    );

    testWidgets('does not throw on empty content', (tester) async {
      await tester.pumpWidget(_wrap(const AppMarkdownText(data: '')));

      expect(tester.takeException(), isNull);
    });
  });
}
