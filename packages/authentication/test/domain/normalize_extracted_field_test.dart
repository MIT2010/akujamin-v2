import 'package:authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('normalizeSelectValue', () {
    const field = FormInputField(
      label: 'provinsi',
      display: 'Provinsi',
      type: 'select',
      validate: true,
      readOnly: false,
      options: [
        FormFieldOption(label: 'Jawa Barat', value: '32'),
        FormFieldOption(label: 'DKI Jakarta', value: '31'),
      ],
    );

    test('matches an exact option value', () {
      expect(normalizeSelectValue(field, '32'), '32');
    });

    test('matches a case-insensitive label substring', () {
      expect(normalizeSelectValue(field, 'jawa barat'), '32');
    });

    test('approved fix: no match returns null instead of silently picking '
        'the first option — the old app\'s '
        '`orElse: () => form.values!.first` would have returned \'32\' here '
        'for a value that matches nothing, the same class of bug '
        'CameraGateway.initialize was fixed for', () {
      expect(normalizeSelectValue(field, 'Sumatera Utara'), isNull);
    });

    test('a field with no options returns the raw value unchanged', () {
      const noOptionsField = FormInputField(
        label: 'x',
        display: 'X',
        type: 'select',
        validate: false,
        readOnly: false,
      );

      expect(normalizeSelectValue(noOptionsField, 'anything'), 'anything');
    });
  });

  group('normalizeDateValue', () {
    test('an already-ISO value passes through unchanged', () {
      expect(normalizeDateValue('1986-02-18'), '1986-02-18');
    });

    test('converts DD-MM-YYYY (Indonesian e-KTP\'s printed format) to ISO', () {
      expect(normalizeDateValue('18-02-1986'), '1986-02-18');
    });

    test('approved fix: a value matching neither ISO nor DD-MM-YYYY returns '
        'null instead of the old app\'s blind '
        '`value.split(\'-\').reversed.join(\'-\')`, which would silently '
        'produce a wrong date for any other dash-separated shape', () {
      expect(normalizeDateValue('not-a-date-at-all'), isNull);
    });

    test('rejects a value that matches the DD-MM-YYYY shape but isn\'t a '
        'real calendar date (month 13) — the regex alone wouldn\'t catch '
        'this, the reconstructed-ISO re-parse does', () {
      expect(normalizeDateValue('01-13-2026'), isNull);
    });
  });
}
