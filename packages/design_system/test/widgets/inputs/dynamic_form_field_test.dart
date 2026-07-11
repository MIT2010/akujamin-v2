import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('DynamicFormField — small select (<=10 options)', () {
    testWidgets('renders every option and reports the resolved value, '
        'not the label, when one is picked', (tester) async {
      String? reported;

      await tester.pumpWidget(
        _wrap(
          DynamicFormField(
            label: 'Provinsi',
            type: DynamicFormFieldType.select,
            value: null,
            options: const [
              DynamicFormOption(label: 'Jawa Barat', value: '32'),
              DynamicFormOption(label: 'Jawa Timur', value: '35'),
            ],
            onChanged: (v) => reported = v,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jawa Timur').last);
      await tester.pumpAndSettle();

      expect(reported, '35');
    });

    testWidgets(
      'regression: rendering with value=null after options were filtered '
      'down (the exact post-clear-on-parent-change shape) does not throw '
      '— this is the crash proven directly against Flutter\'s '
      'DropdownButtonFormField before the clear-on-parent-change fix '
      'existed',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            DynamicFormField(
              label: 'Kota',
              type: DynamicFormFieldType.select,
              // Simulates: 'kota' held '3578' (Surabaya) before 'provinsi'
              // changed; the Cubit is now expected to have cleared it to
              // null, and 'options' is already re-filtered down to just
              // Bandung. This must render cleanly, not throw.
              value: null,
              options: const [
                DynamicFormOption(label: 'Bandung', value: '3273'),
              ],
              onChanged: (_) {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      },
    );
  });

  group('DynamicFormField — large select (>10 options)', () {
    final manyOptions = List.generate(
      12,
      (i) => DynamicFormOption(label: 'Kota $i', value: '$i'),
    );

    testWidgets('renders as a read-only field that opens a search dialog', (
      tester,
    ) async {
      String? reported;

      await tester.pumpWidget(
        _wrap(
          DynamicFormField(
            label: 'Kota',
            type: DynamicFormFieldType.select,
            value: null,
            options: manyOptions,
            onChanged: (v) => reported = v,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Cari Kota'), findsOneWidget);

      // Pick an item guaranteed on-screen without scrolling, to keep this
      // test about dialog-select behavior rather than ListView scrolling.
      await tester.tap(find.text('Kota 0'));
      await tester.pumpAndSettle();

      expect(reported, '0');
    });
  });

  group('DynamicFormField — text', () {
    testWidgets('reports typed text directly, with no resolution', (
      tester,
    ) async {
      String? reported;

      await tester.pumpWidget(
        _wrap(
          DynamicFormField(
            label: 'Nama',
            type: DynamicFormFieldType.text,
            value: null,
            onChanged: (v) => reported = v,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Budi Santoso');

      expect(reported, 'Budi Santoso');
    });
  });

  group('DynamicFormField — date', () {
    testWidgets('renders as a read-only field, does not throw', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DynamicFormField(
            label: 'Tanggal Lahir',
            type: DynamicFormFieldType.date,
            value: '2000-01-01',
            onChanged: (_) {},
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('1 January 2000'), findsOneWidget);
    });
  });
}
