import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// `authentication`'s `login_cubit_test.dart` is the only other `blocTest`
/// example in the repo so far, covering a single linear flow (submit →
/// loading → success/failure). This one follows the same `build`/`act`/
/// `expect`/`verify` shape, extended to two independent methods on the
/// same cubit (`getProfile`/`updateProfile`), each with its own
/// given/when/then: "given" is whatever `build` wires the mocks to
/// answer, "when" is `act`, "then" is `expect` (+ `verify` for side
/// effects) — worth keeping as the reference the next feature's cubit
/// test is written against.
class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockUpdateProfileUseCase extends Mock implements UpdateProfileUseCase {}

void main() {
  late _MockProfileRepository repository;
  late _MockUpdateProfileUseCase updateProfileUseCase;

  const profile = Profile(
    name: 'Ada Lovelace',
    email: 'ada@example.com',
    bio: 'Mathematician',
    phoneNumber: '+1-555-0100',
  );

  setUpAll(() {
    registerFallbackValue(profile);
  });

  setUp(() {
    repository = _MockProfileRepository();
    updateProfileUseCase = _MockUpdateProfileUseCase();
  });

  group('ProfileCubit.getProfile', () {
    blocTest<ProfileCubit, ProfileState>(
      // given
      'given the repository resolves a profile',
      setUp: () {
        when(
          () => repository.getProfile(),
        ).thenAnswer((_) async => const Ok(profile));
      },
      build: () => ProfileCubit(repository, updateProfileUseCase),
      // when
      act: (cubit) => cubit.getProfile(),
      // then
      expect: () => [
        const ProfileState.loading(),
        const ProfileState.loaded(profile),
      ],
    );

    blocTest<ProfileCubit, ProfileState>(
      'given the repository fails',
      setUp: () {
        when(() => repository.getProfile()).thenAnswer(
          (_) async =>
              const Err(ServerFailure('Internal error', statusCode: 500)),
        );
      },
      build: () => ProfileCubit(repository, updateProfileUseCase),
      act: (cubit) => cubit.getProfile(),
      expect: () => [
        const ProfileState.loading(),
        const ProfileState.error(
          ServerFailure('Internal error', statusCode: 500),
        ),
      ],
    );
  });

  group('ProfileCubit.updateProfile', () {
    const edited = Profile(
      name: 'Ada L.',
      email: 'ada@example.com',
      bio: 'Mathematician & writer',
      phoneNumber: '+1-555-0100',
    );

    blocTest<ProfileCubit, ProfileState>(
      'given the use case resolves the updated profile',
      setUp: () {
        when(
          () => updateProfileUseCase(edited),
        ).thenAnswer((_) async => const Ok(edited));
      },
      build: () => ProfileCubit(repository, updateProfileUseCase),
      act: (cubit) => cubit.updateProfile(edited),
      expect: () => [
        const ProfileState.saving(edited),
        const ProfileState.loaded(edited),
      ],
    );

    blocTest<ProfileCubit, ProfileState>(
      'given the use case fails validation',
      setUp: () {
        when(() => updateProfileUseCase(edited)).thenAnswer(
          (_) async => const Err(ValidationFailure('Invalid phone number')),
        );
      },
      build: () => ProfileCubit(repository, updateProfileUseCase),
      act: (cubit) => cubit.updateProfile(edited),
      expect: () => [
        const ProfileState.saving(edited),
        const ProfileState.error(ValidationFailure('Invalid phone number')),
      ],
    );
  });
}
