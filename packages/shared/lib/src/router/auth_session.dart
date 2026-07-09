import 'package:injectable/injectable.dart';

/// What [AppRouter] needs to know about the current session — nothing more.
///
/// `shared` and `authentication` are siblings in the dependency graph (§6):
/// neither imports the other. So instead of depending on the concrete
/// `AuthCubit` (as §17's illustrative snippet does), the router depends on
/// this thin contract. `authentication` will adapt `AuthCubit` to it once
/// that package is built — zero changes needed here when that happens.
class AuthSessionStatus {
  final bool isAuthenticated;
  final List<String> roles;

  const AuthSessionStatus({
    required this.isAuthenticated,
    this.roles = const [],
  });

  static const unauthenticated = AuthSessionStatus(isAuthenticated: false);
}

abstract class AuthSession {
  AuthSessionStatus get status;
  Stream<AuthSessionStatus> get statusStream;
}

/// Default no-op, same swap-later pattern as [AnalyticsService]/
/// [CrashReporter] (§17): the app — and `AppRouter`'s DI graph — has to
/// resolve *something* before `authentication` exists. `authentication`
/// will register its `AuthCubit`-backed adapter under this same interface
/// once it's built, superseding this registration.
@LazySingleton(as: AuthSession)
class UnauthenticatedAuthSession implements AuthSession {
  @override
  AuthSessionStatus get status => AuthSessionStatus.unauthenticated;

  @override
  Stream<AuthSessionStatus> get statusStream =>
      Stream.value(AuthSessionStatus.unauthenticated);
}
