import 'package:authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User', () {
    test('two instances with the same fields are equal', () {
      const a = User(id: '1', email: 'a@example.com', role: 'admin');
      const b = User(id: '1', email: 'a@example.com', role: 'admin');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith overrides only the given fields', () {
      const user = User(id: '1', email: 'a@example.com', role: 'admin');

      final promoted = user.copyWith(role: 'superadmin');

      expect(promoted.id, '1');
      expect(promoted.email, 'a@example.com');
      expect(promoted.role, 'superadmin');
    });
  });
}
