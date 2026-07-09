import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTextField', () {
    testWidgets('shows the label and reports changes', (tester) async {
      String? changed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Email',
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );

      expect(find.text('Email'), findsOneWidget);

      await tester.enterText(find.byType(AppTextField), 'user@example.com');

      expect(changed, 'user@example.com');
    });

    testWidgets('shows an error message when errorText is set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(label: 'Email', errorText: 'Required'),
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('obscures text when obscure is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppTextField(label: 'Password', obscure: true)),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });
  });
}
