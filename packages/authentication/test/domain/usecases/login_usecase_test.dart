import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  late _MockAuthRepository repository;
  late _MockAnalyticsService analytics;
  late LoginUseCase useCase;

  setUp(() {
    repository = _MockAuthRepository();
    analytics = _MockAnalyticsService();
    useCase = LoginUseCase(repository, analytics);
  });

  const user = User(id: '1', email: 'a@example.com', role: 'admin');

  test(
    'logs a login_success analytics event and returns Ok on success',
    () async {
      when(
        () => repository.login(email: 'a@example.com', password: 'secret'),
      ).thenAnswer((_) async => const Ok(user));
      when(
        () => analytics.logEvent(any(), params: any(named: 'params')),
      ).thenAnswer((_) async {});

      final result = await useCase(
        const LoginParams(email: 'a@example.com', password: 'secret'),
      );

      expect(result.isOk, isTrue);
      verify(() => analytics.logEvent('login_success')).called(1);
    },
  );

  test('does not log any analytics event on failure', () async {
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Err(UnauthorizedFailure()));

    final result = await useCase(
      const LoginParams(email: 'a@example.com', password: 'wrong'),
    );

    expect(result.isErr, isTrue);
    verifyNever(() => analytics.logEvent(any(), params: any(named: 'params')));
  });
}
