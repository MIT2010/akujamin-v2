import 'package:authentication/authentication.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockNotificationGateway extends Mock implements NotificationGateway {}

void main() {
  late _MockAuthRepository repository;
  late _MockNotificationGateway notificationGateway;

  const user = User(id: '1', email: 'a@example.com', role: 'admin');

  setUp(() {
    repository = _MockAuthRepository();
    notificationGateway = _MockNotificationGateway();
    when(() => notificationGateway.cancelAll()).thenAnswer((_) async {});
  });

  group('AuthCubit — restores the cached session at construction', () {
    test('emits authenticated(user) when a user is cached', () async {
      when(() => repository.getCachedUser()).thenAnswer((_) async => user);
      when(
        () => repository.getCachedSessionProfile(),
      ).thenAnswer((_) async => null);

      final cubit = AuthCubit(repository, notificationGateway);
      await pumpEventQueue();

      expect(cubit.state, AuthState.authenticated(user));
    });

    test('emits unauthenticated() when nothing is cached', () async {
      when(() => repository.getCachedUser()).thenAnswer((_) async => null);

      final cubit = AuthCubit(repository, notificationGateway);
      await pumpEventQueue();

      expect(cubit.state, const AuthState.unauthenticated());
    });
  });

  test('setAuthenticated makes a fresh login visible immediately, without '
      'waiting on the cache read', () async {
    when(() => repository.getCachedUser()).thenAnswer((_) async => null);
    final cubit = AuthCubit(repository, notificationGateway);
    await pumpEventQueue();
    expect(cubit.state, const AuthState.unauthenticated());

    cubit.setAuthenticated(user);

    expect(cubit.state, AuthState.authenticated(user));
  });

  test('logout clears the repository, cancels all pending notifications, '
      'and emits unauthenticated() — the single authoritative call site for '
      'NotificationGateway.cancelAll(), not scattered across UI logout '
      'buttons', () async {
    when(() => repository.getCachedUser()).thenAnswer((_) async => user);
    when(
      () => repository.getCachedSessionProfile(),
    ).thenAnswer((_) async => null);
    when(() => repository.logout()).thenAnswer((_) async => const Ok(null));
    final cubit = AuthCubit(repository, notificationGateway);
    await pumpEventQueue();
    expect(cubit.state, AuthState.authenticated(user));

    await cubit.logout();

    expect(cubit.state, const AuthState.unauthenticated());
    verify(() => repository.logout()).called(1);
    verify(() => notificationGateway.cancelAll()).called(1);
  });
}
