import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('StringValidatorX', () {
    test('isBlank/isNotBlank', () {
      expect('   '.isBlank, isTrue);
      expect('hi'.isBlank, isFalse);
      expect('hi'.isNotBlank, isTrue);
    });

    test('isValidEmail', () {
      expect('user@example.com'.isValidEmail, isTrue);
      expect('user.name+tag@sub.example.co.id'.isValidEmail, isTrue);
      expect('not-an-email'.isValidEmail, isFalse);
      expect('missing@domain'.isValidEmail, isFalse);
    });

    test('isStrongPassword requires length, uppercase and a digit', () {
      expect('Abcdef12'.isStrongPassword, isTrue);
      expect('abcdef12'.isStrongPassword, isFalse); // no uppercase
      expect('Abcdefgh'.isStrongPassword, isFalse); // no digit
      expect('Ab1'.isStrongPassword, isFalse); // too short
    });
  });
}
