import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('DateFormatterX', () {
    test('toYmd pads month and day', () {
      final date = DateTime(2026, 7, 6);

      expect(date.toYmd, '2026-07-06');
    });
  });

  group('NumFormatterX', () {
    test('withThousandsSeparator groups by three digits', () {
      expect(1234567.withThousandsSeparator, '1.234.567');
      expect(999.withThousandsSeparator, '999');
    });

    test('asCurrencyIdr prefixes Rp', () {
      expect(1500000.asCurrencyIdr, 'Rp1.500.000');
    });
  });
}
