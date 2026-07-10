import 'package:authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfileModel', () {
    const model = UserProfileModel(
      id: '1',
      email: 'a@example.com',
      role: 'admin',
      name: 'Ani',
      avatar: 'https://example.com/a.png',
      nik: '1234567890123456',
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

    test('toSessionProfile maps avatar/name/nik to a SessionProfile', () {
      final profile = model.toSessionProfile();

      expect(profile.avatar, 'https://example.com/a.png');
      expect(profile.name, 'Ani');
      expect(profile.nik, '1234567890123456');
    });
  });
}
