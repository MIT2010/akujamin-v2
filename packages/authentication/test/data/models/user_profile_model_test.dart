import 'package:authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfileModel', () {
    const model = UserProfileModel(
      id: '1',
      email: 'a@example.com',
      role: 'admin',
    );

    test('round-trips through fromJson/toJson', () {
      final json = model.toJson();
      final decoded = UserProfileModel.fromJson(json);

      expect(decoded, model);
    });

    test('toEntity maps to the domain User', () {
      final entity = model.toEntity();

      expect(entity.id, '1');
      expect(entity.email, 'a@example.com');
      expect(entity.role, 'admin');
    });
  });
}
