import 'package:core/core.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockProfileRemoteDataSource extends Mock
    implements ProfileRemoteDataSource {}

void main() {
  late _MockProfileRemoteDataSource remote;
  late ProfileRepositoryImpl repository;

  const model = ProfileModel(
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    bio: 'Mathematician',
    phoneNumber: '+1-555-0100',
  );

  setUpAll(() {
    registerFallbackValue(model);
  });

  setUp(() {
    remote = _MockProfileRemoteDataSource();
    repository = ProfileRepositoryImpl(remote);
  });

  group('ProfileRepositoryImpl.getProfile', () {
    test('returns Ok with the mapped entity on success', () async {
      when(() => remote.getProfile()).thenAnswer((_) async => const Ok(model));

      final result = await repository.getProfile();

      expect(result.isOk, isTrue);
      final profile = (result as Ok<Failure, Profile>).value;
      expect(profile.name, 'Ada Lovelace');
      expect(profile.bio, 'Mathematician');
    });

    test('returns Err on a server failure', () async {
      when(() => remote.getProfile()).thenAnswer(
        (_) async =>
            const Err(ServerFailure('Internal error', statusCode: 500)),
      );

      final result = await repository.getProfile();

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, Profile>).failure, isA<ServerFailure>());
    });
  });

  group('ProfileRepositoryImpl.updateProfile', () {
    const edited = Profile(
      name: 'Ada L.',
      email: 'ada@example.com',
      bio: 'Mathematician & writer',
      phoneNumber: '+1-555-0100',
    );

    test(
      'sends the entity as a model and returns Ok with the mapped response',
      () async {
        when(() => remote.updateProfile(any())).thenAnswer(
          (_) async => const Ok(
            ProfileModel(
              name: 'Ada L.',
              email: 'ada@example.com',
              bio: 'Mathematician & writer',
              phoneNumber: '+1-555-0100',
            ),
          ),
        );

        final result = await repository.updateProfile(edited);

        expect(result.isOk, isTrue);
        expect(
          (result as Ok<Failure, Profile>).value.bio,
          'Mathematician & writer',
        );
        verify(
          () => remote.updateProfile(ProfileModel.fromEntity(edited)),
        ).called(1);
      },
    );

    test('returns Err on a server failure', () async {
      when(() => remote.updateProfile(any())).thenAnswer(
        (_) async =>
            const Err(ServerFailure('Invalid phone number', statusCode: 422)),
      );

      final result = await repository.updateProfile(edited);

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, Profile>).failure, isA<ServerFailure>());
    });
  });
}
