import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDialog.confirm', () {
    testWidgets('resolves true when the confirm label is tapped', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AppButton(
                label: 'Open',
                onPressed: () async {
                  result = await AppDialog.confirm(
                    context,
                    title: 'Delete?',
                    message: 'This cannot be undone.',
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Delete?'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('resolves false when cancel is tapped', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AppButton(
                label: 'Open',
                onPressed: () async {
                  result = await AppDialog.confirm(
                    context,
                    title: 'Delete?',
                    message: 'This cannot be undone.',
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('AppDialog.info', () {
    testWidgets('shows the message and dismisses on OK', (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => AppButton(
                label: 'Open',
                onPressed: () async {
                  await AppDialog.info(
                    context,
                    title: 'Belum tersedia',
                    message: 'Fitur ini belum tersedia.',
                  );
                  completed = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      expect(find.text('Belum tersedia'), findsOneWidget);
      expect(find.text('Fitur ini belum tersedia.'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(find.text('Belum tersedia'), findsNothing);
    });
  });
}
