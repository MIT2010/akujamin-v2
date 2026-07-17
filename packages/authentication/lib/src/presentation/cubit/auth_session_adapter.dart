import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import 'auth_cubit.dart';
import 'auth_state.dart';

/// The adapter `shared`'s `auth_session.dart` comment promised: `shared` and
/// `authentication` are siblings (§6), so `AppRouter` depends on the thin
/// `AuthSession` contract instead of this package's concrete `AuthCubit` —
/// this is the one place that bridges the two. Registering as
/// `@LazySingleton(as: AuthSession)` supersedes `shared`'s own
/// `UnauthenticatedAuthSession` default registration; `apps/mobile`'s
/// `injection.dart` sets `getIt.allowReassignment = true` so the second
/// registration (this one, since `authentication`'s micro-package module is
/// listed after `shared`'s) is allowed to replace the first instead of
/// asserting.
@LazySingleton(as: AuthSession)
class AuthSessionAdapter implements AuthSession {
  final AuthCubit _authCubit;
  AuthSessionAdapter(this._authCubit);

  @override
  AuthSessionStatus get status => _toStatus(_authCubit.state);

  @override
  Stream<AuthSessionStatus> get statusStream =>
      _authCubit.stream.map(_toStatus);

  // `refreshing` reports the same `isAuthenticated: true` an `authenticated`
  // session does -- real bug, found 2026-07-17 from live testing: `AppRouter`
  // must never redirect away from the current screen just because a
  // reactive token refresh is in flight, only once it genuinely fails
  // (`AuthCubit.forceLogout()`, which emits `unauthenticated` separately).
  AuthSessionStatus _toStatus(AuthState state) => switch (state) {
    AuthAuthenticated(:final user) || AuthRefreshing(:final user) =>
      AuthSessionStatus(isAuthenticated: true, roles: [user.role]),
    AuthInitial() || AuthUnauthenticated() => AuthSessionStatus.unauthenticated,
  };
}
