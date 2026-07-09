import 'package:core/core.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockProfileRepository repository;
  late _MockAnalyticsService analytics;
  late UpdateProfileUseCase useCase;

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
    analytics = _MockAnalyticsService();
    useCase = UpdateProfileUseCase(repository, analytics);
  });

  test(
    'logs a profile_updated analytics event and returns Ok on success',
    () async {
      when(
        () => repository.updateProfile(profile),
      ).thenAnswer((_) async => const Ok(profile));
      when(
        () => analytics.logEvent(any(), params: any(named: 'params')),
      ).thenAnswer((_) async {});

      final result = await useCase(profile);

      expect(result.isOk, isTrue);
      verify(() => analytics.logEvent('profile_updated')).called(1);
    },
  );

  test('does not log any analytics event on failure', () async {
    when(
      () => repository.updateProfile(profile),
    ).thenAnswer((_) async => const Err(ServerFailure('Invalid data')));

    final result = await useCase(profile);

    expect(result.isErr, isTrue);
    verifyNever(() => analytics.logEvent(any(), params: any(named: 'params')));
  });
}
