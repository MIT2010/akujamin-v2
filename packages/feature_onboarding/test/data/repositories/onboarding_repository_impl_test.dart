import 'package:core/core.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingLocalDataSource extends Mock
    implements OnboardingLocalDataSource {}

void main() {
  late _MockOnboardingLocalDataSource local;
  late OnboardingRepositoryImpl repository;

  setUp(() {
    local = _MockOnboardingLocalDataSource();
    repository = OnboardingRepositoryImpl(local);
  });

  group('OnboardingRepositoryImpl.getIsFirstLaunch', () {
    test('returns Ok(true) when nothing has been stored yet', () async {
      when(() => local.getIsFirstLaunch()).thenReturn(true);

      final result = await repository.getIsFirstLaunch();

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, bool>).value, isTrue);
    });

    test('returns Ok(false) once the flag has been set', () async {
      when(() => local.getIsFirstLaunch()).thenReturn(false);

      final result = await repository.getIsFirstLaunch();

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, bool>).value, isFalse);
    });

    test('returns Err(CacheFailure) when the datasource throws', () async {
      when(() => local.getIsFirstLaunch()).thenThrow(Exception('boom'));

      final result = await repository.getIsFirstLaunch();

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, bool>).failure, isA<CacheFailure>());
    });
  });

  group('OnboardingRepositoryImpl.setIsFirstLaunch', () {
    test('returns Ok(null) on success', () async {
      when(() => local.setIsFirstLaunch()).thenAnswer((_) async {});

      final result = await repository.setIsFirstLaunch();

      expect(result.isOk, isTrue);
      verify(() => local.setIsFirstLaunch()).called(1);
    });

    test('returns Err(CacheFailure) when the datasource throws', () async {
      when(() => local.setIsFirstLaunch()).thenThrow(Exception('boom'));

      final result = await repository.setIsFirstLaunch();

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, void>).failure, isA<CacheFailure>());
    });
  });
}
