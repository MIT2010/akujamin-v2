import 'package:authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhoneNumber', () {
    test('strips a leading 0 before prefixing with 62 -- the most common '
        'way an Indonesian phone number is actually typed', () {
      expect(normalizePhoneNumber('081234567890'), '6281234567890');
    });

    test('prefixes with 62 when there is no leading 0', () {
      expect(normalizePhoneNumber('81234567890'), '6281234567890');
    });

    test('leaves a number that already has the 62 country code untouched', () {
      expect(normalizePhoneNumber('6281234567890'), '6281234567890');
    });

    test('trims surrounding whitespace before normalizing', () {
      expect(normalizePhoneNumber('  081234567890  '), '6281234567890');
    });
  });
}
