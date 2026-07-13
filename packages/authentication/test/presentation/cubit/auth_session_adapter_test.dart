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

  test('status reflects AuthCubit.authenticated as isAuthenticated with the '
      "user's role", () async {
    when(() => repository.getCachedUser()).thenAnswer((_) async => user);
    when(
      () => repository.getCachedSessionProfile(),
    ).thenAnswer((_) async => null);
    final authCubit = AuthCubit(repository, notificationGateway);
    await pumpEventQueue();

    final adapter = AuthSessionAdapter(authCubit);

    expect(adapter.status.isAuthenticated, isTrue);
    expect(adapter.status.roles, ['admin']);
  });

  test(
    'status reflects AuthCubit.unauthenticated as AuthSessionStatus.unauthenticated',
    () async {
      when(() => repository.getCachedUser()).thenAnswer((_) async => null);
      final authCubit = AuthCubit(repository, notificationGateway);
      await pumpEventQueue();

      final adapter = AuthSessionAdapter(authCubit);

      expect(adapter.status.isAuthenticated, isFalse);
      expect(adapter.status.roles, isEmpty);
    },
  );

  test('statusStream follows AuthCubit through a login/logout cycle', () async {
    when(() => repository.getCachedUser()).thenAnswer((_) async => null);
    when(() => repository.logout()).thenAnswer((_) async => const Ok(null));
    final authCubit = AuthCubit(repository, notificationGateway);
    await pumpEventQueue();
    final adapter = AuthSessionAdapter(authCubit);

    final statuses = <AuthSessionStatus>[];
    final subscription = adapter.statusStream.listen(statuses.add);

    authCubit.setAuthenticated(user);
    await pumpEventQueue();
    await authCubit.logout();
    await pumpEventQueue();
    await subscription.cancel();

    expect(statuses.map((s) => s.isAuthenticated), [true, false]);
  });
}
