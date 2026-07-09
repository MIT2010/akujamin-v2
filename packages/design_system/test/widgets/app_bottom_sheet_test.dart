import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppBottomSheet.show displays the given builder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => AppButton(
              label: 'Open',
              onPressed: () => AppBottomSheet.show<void>(
                context,
                builder: (context) => const Text('sheet content'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(find.text('sheet content'), findsOneWidget);
  });
}
