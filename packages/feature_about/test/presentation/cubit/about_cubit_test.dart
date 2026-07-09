import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_about/feature_about.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Same `build`/`act`/`expect` shape as `feature_profile`'s
/// `profile_cubit_test.dart` — the reference for a plain-pass-through
/// Cubit's test (no `updateProfile`-style second method here, since
/// `about` is read-only).
class _MockAboutRepository extends Mock implements AboutRepository {}

void main() {
  late _MockAboutRepository repository;

  const items = [About(type: 'Umum', text: 'Ini adalah jawaban umum.')];

  setUp(() {
    repository = _MockAboutRepository();
  });

  group('AboutCubit.getAbout', () {
    blocTest<AboutCubit, AboutState>(
      'given the repository resolves a list of FAQ items',
      setUp: () {
        when(
          () => repository.getAbout(),
        ).thenAnswer((_) async => const Ok(items));
      },
      build: () => AboutCubit(repository),
      act: (cubit) => cubit.getAbout(),
      expect: () => [
        const AboutState.loading(),
        const AboutState.loaded(items),
      ],
    );

    blocTest<AboutCubit, AboutState>(
      'given the repository fails',
      setUp: () {
        when(() => repository.getAbout()).thenAnswer(
          (_) async =>
              const Err(ServerFailure('Internal error', statusCode: 500)),
        );
      },
      build: () => AboutCubit(repository),
      act: (cubit) => cubit.getAbout(),
      expect: () => [
        const AboutState.loading(),
        const AboutState.error(
          ServerFailure('Internal error', statusCode: 500),
        ),
      ],
    );
  });
}
