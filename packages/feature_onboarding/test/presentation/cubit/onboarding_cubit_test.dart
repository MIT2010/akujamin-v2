import 'package:bloc_test/bloc_test.dart';
import 'package:core/core.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingRepository extends Mock implements OnboardingRepository {}

void main() {
  late _MockOnboardingRepository repository;

  setUp(() {
    repository = _MockOnboardingRepository();
  });

  group('OnboardingCubit.checkStatus', () {
    blocTest<OnboardingCubit, OnboardingState>(
      'given the repository reports first launch',
      setUp: () {
        when(
          () => repository.getIsFirstLaunch(),
        ).thenAnswer((_) async => const Ok(true));
      },
      build: () => OnboardingCubit(repository),
      act: (cubit) => cubit.checkStatus(),
      expect: () => [
        const OnboardingState.checking(),
        const OnboardingState.showCarousel(),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'given the repository reports onboarding already completed',
      setUp: () {
        when(
          () => repository.getIsFirstLaunch(),
        ).thenAnswer((_) async => const Ok(false));
      },
      build: () => OnboardingCubit(repository),
      act: (cubit) => cubit.checkStatus(),
      expect: () => [
        const OnboardingState.checking(),
        const OnboardingState.alreadyCompleted(),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'given the repository fails',
      setUp: () {
        when(() => repository.getIsFirstLaunch()).thenAnswer(
          (_) async => const Err(CacheFailure('Gagal membaca status')),
        );
      },
      build: () => OnboardingCubit(repository),
      act: (cubit) => cubit.checkStatus(),
      expect: () => [
        const OnboardingState.checking(),
        const OnboardingState.error(CacheFailure('Gagal membaca status')),
      ],
    );
  });

  group('OnboardingCubit.complete', () {
    blocTest<OnboardingCubit, OnboardingState>(
      'given the repository resolves',
      setUp: () {
        when(
          () => repository.setIsFirstLaunch(),
        ).thenAnswer((_) async => const Ok(null));
      },
      build: () => OnboardingCubit(repository),
      act: (cubit) => cubit.complete(),
      expect: () => [
        const OnboardingState.completing(),
        const OnboardingState.finished(),
      ],
    );

    blocTest<OnboardingCubit, OnboardingState>(
      'given the repository fails',
      setUp: () {
        when(() => repository.setIsFirstLaunch()).thenAnswer(
          (_) async => const Err(CacheFailure('Gagal menyimpan status')),
        );
      },
      build: () => OnboardingCubit(repository),
      act: (cubit) => cubit.complete(),
      expect: () => [
        const OnboardingState.completing(),
        const OnboardingState.error(CacheFailure('Gagal menyimpan status')),
      ],
    );
  });
}
