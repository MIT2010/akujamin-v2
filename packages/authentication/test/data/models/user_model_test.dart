import 'package:authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    const model = UserModel(
      id: '1',
      email: 'a@example.com',
      role: 'admin',
      accessToken: 'access-123',
      refreshToken: 'refresh-456',
    );

    test('round-trips through fromJson/toJson', () {
      final json = model.toJson();
      final decoded = UserModel.fromJson(json);

      expect(decoded, model);
    });

    test('toEntity maps only the domain-relevant fields', () {
      final entity = model.toEntity();

      expect(entity.id, '1');
      expect(entity.email, 'a@example.com');
      expect(entity.role, 'admin');
    });
  });
}
