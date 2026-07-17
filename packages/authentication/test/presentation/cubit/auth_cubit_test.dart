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

  group('AuthCubit as TokenRefresher (§9/§10, RefreshTokenInterceptor)', () {
    test('refresh() delegates straight to the repository when there is no '
        'authenticated session to preserve (e.g. still restoring, or '
        'already logged out)', () async {
      when(() => repository.getCachedUser()).thenAnswer((_) async => null);
      when(() => repository.refreshToken()).thenAnswer((_) async => true);
      final cubit = AuthCubit(repository, notificationGateway);
      await pumpEventQueue();

      final refreshed = await cubit.refresh();

      expect(refreshed, isTrue);
      verify(() => repository.refreshToken()).called(1);
    });

    test('refresh() emits refreshing(user) while the call is in flight, then '
        'restores authenticated(user) on success -- real bug, found '
        '2026-07-17 from live testing: this used to leave state untouched '
        'during the call, so there was nothing distinguishing "a refresh is '
        'in progress" from any other silent background request, and nothing '
        'shown while waiting. A successful refresh must land back on the '
        'exact same session, not force a fresh login.', () async {
      when(() => repository.getCachedUser()).thenAnswer((_) async => user);
      when(
        () => repository.getCachedSessionProfile(),
      ).thenAnswer((_) async => null);
      when(() => repository.refreshToken()).thenAnswer((_) async => true);
      final cubit = AuthCubit(repository, notificationGateway);
      await pumpEventQueue();
      expect(cubit.state, AuthState.authenticated(user));

      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);

      final refreshed = await cubit.refresh();
      // Stream delivery to `.listen()` is microtask-scheduled, at least
      // one tick behind `emit()` itself -- draining the queue here
      // (rather than asserting immediately after `await cubit.refresh()`
      // returns) avoids a race against the cubit's own second emission
      // still being in flight.
      await pumpEventQueue();
      await sub.cancel();

      expect(refreshed, isTrue);
      expect(states, [
        AuthState.refreshing(user),
        AuthState.authenticated(user),
      ]);
      expect(cubit.state, AuthState.authenticated(user));
    });

    test('refresh() leaves the cubit on refreshing(user) when the call fails '
        '-- RefreshTokenInterceptor.onRefreshFailed (wired to forceLogout) '
        'is what moves it on to unauthenticated, not refresh() itself, so a '
        'failed refresh never gets stuck showing the splash forever', () async {
      when(() => repository.getCachedUser()).thenAnswer((_) async => user);
      when(
        () => repository.getCachedSessionProfile(),
      ).thenAnswer((_) async => null);
      when(() => repository.refreshToken()).thenAnswer((_) async => false);
      final cubit = AuthCubit(repository, notificationGateway);
      await pumpEventQueue();

      final refreshed = await cubit.refresh();

      expect(refreshed, isFalse);
      expect(cubit.state, AuthState.refreshing(user));
    });

    test('forceLogout() has the exact same side effects as logout() — a '
        'refresh-triggered logout is not a lesser/different path', () async {
      when(() => repository.getCachedUser()).thenAnswer((_) async => user);
      when(
        () => repository.getCachedSessionProfile(),
      ).thenAnswer((_) async => null);
      when(() => repository.logout()).thenAnswer((_) async => const Ok(null));
      final cubit = AuthCubit(repository, notificationGateway);
      await pumpEventQueue();
      expect(cubit.state, AuthState.authenticated(user));

      await cubit.forceLogout();

      expect(cubit.state, const AuthState.unauthenticated());
      verify(() => repository.logout()).called(1);
      verify(() => notificationGateway.cancelAll()).called(1);
    });
  });
}
