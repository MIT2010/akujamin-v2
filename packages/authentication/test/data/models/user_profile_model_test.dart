import 'package:authentication/authentication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfileModel', () {
    const model = UserProfileModel(
      id: '1',
      email: 'a@example.com',
      name: 'Ani',
      avatar: 'https://example.com/a.png',
      nik: '1234567890123456',
    );

    test('round-trips through fromJson/toJson', () {
      final json = model.toJson();
      final decoded = UserProfileModel.fromJson(json);

      expect(decoded, model);
    });

    test('toEntity maps to the domain User, role supplied by the caller '
        '(this DTO never carries one — see the class doc comment)', () {
      final entity = model.toEntity(role: 'peserta');

      expect(entity.id, '1');
      expect(entity.email, 'a@example.com');
      expect(entity.role, 'peserta');
      expect(entity.isRegistered, isFalse);
    });

    test('fromJson reads is_regis into isRegistered', () {
      final decoded = UserProfileModel.fromJson({
        'id': '1',
        'email': 'a@example.com',
        'name': 'Ani',
        'avatars': 'https://example.com/a.png',
        'nik': '1234567890123456',
        'is_regis': true,
      });

      expect(decoded.isRegistered, isTrue);
      expect(decoded.toEntity(role: '').isRegistered, isTrue);
    });

    test('isRegistered defaults to false when is_regis is absent', () {
      final decoded = UserProfileModel.fromJson({
        'id': '1',
        'email': 'a@example.com',
        'name': 'Ani',
        'avatars': 'https://example.com/a.png',
        'nik': '1234567890123456',
      });

      expect(decoded.isRegistered, isFalse);
    });

    test('fromJson accepts a numeric id — confirmed 2026-07-15, the real '
        'backend sends id as a JSON number, not a string', () {
      final decoded = UserProfileModel.fromJson({
        'id': 59,
        'email': 'a@example.com',
        'name': 'Ani',
        'avatars': 'https://example.com/a.png',
        'nik': '1234567890123456',
      });

      expect(decoded.id, '59');
    });

    test('toSessionProfile maps avatar/name/nik to a SessionProfile', () {
      final profile = model.toSessionProfile();

      expect(profile.avatar, 'https://example.com/a.png');
      expect(profile.name, 'Ani');
      expect(profile.nik, '1234567890123456');
    });
  });
}
