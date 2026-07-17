import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import '../../domain/entities/session_profile.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// App-wide session state (§9) — checks the cached user once at boot, and
/// is what [AuthSessionAdapter] (in the same folder) wraps for
/// `AppRouter`'s redirect logic. `@lazySingleton` (not `@injectable`) so
/// [LoginCubit] and the router's `AuthSession` adapter share the exact same
/// instance/stream — logging in has to be visible to both.
///
/// Owns [NotificationGateway] directly (not routed through
/// [AuthRepository]) for the same reason `TestCubit` owns `ScreenshotGateway`
/// directly rather than through `TestRepository`: [logout] is the one
/// authoritative call site every UI logout button already goes through, so
/// [NotificationGateway.cancelAll] belongs here, not scattered across
/// individual logout buttons.
///
/// Also implements [TokenRefresher] (§9/§10) — bound to that interface too
/// via `RegisterModule.tokenRefresher`, so `RefreshTokenInterceptor` (built
/// in `shared`, which can't import `authentication`) can call back into the
/// one auth-session owner on a real 401, without a circular package
/// dependency. [refresh] and [forceLogout] are that contract's two methods;
/// [forceLogout] is deliberately just [logout] under another name — a
/// refresh-triggered logout needs the exact same side effects as a
/// user-tapped one.
@lazySingleton
class AuthCubit extends Cubit<AuthState> implements TokenRefresher {
  final AuthRepository _repository;
  final NotificationGateway _notificationGateway;

  AuthCubit(this._repository, this._notificationGateway)
    : super(const AuthState.initial()) {
    _restoreCachedSession();
  }

  Future<void> _restoreCachedSession() async {
    final user = await _repository.getCachedUser();
    if (user == null) {
      emit(const AuthState.unauthenticated());
      return;
    }
    final sessionProfile = await _repository.getCachedSessionProfile();
    emit(AuthState.authenticated(user, sessionProfile: sessionProfile));
  }

  /// Called by [LoginCubit]/`OtpLoginCubit` right after a successful login
  /// — the tokens (and, for the OTP flow, the session profile) are already
  /// persisted by [AuthRepositoryImpl] by this point, this just makes the
  /// in-memory session (and therefore the router) catch up. `sessionProfile`
  /// stays `null` for [LoginCubit]'s email/password flow, which never had
  /// one.
  void setAuthenticated(User user, {SessionProfile? sessionProfile}) =>
      emit(AuthState.authenticated(user, sessionProfile: sessionProfile));

  Future<void> logout() async {
    await _repository.logout();
    await _notificationGateway.cancelAll();
    emit(const AuthState.unauthenticated());
  }

  /// Shows a splash while the refresh call is in flight, not `/login` --
  /// real bug, found 2026-07-17 from live testing: this used to leave
  /// `state` untouched during the call, so a *successful* refresh had
  /// nothing distinguishing it from any other silent background request,
  /// but there was also nothing shown *while waiting* on the current
  /// screen either. Only [forceLogout] (via `RefreshTokenInterceptor`'s
  /// `onRefreshFailed`, already wired below) moves to `unauthenticated` --
  /// a *failed* refresh is the only thing that should ever reach
  /// `/login`; a successful one restores exactly the session that was
  /// there before, on whatever screen the user was already on.
  @override
  Future<bool> refresh() async {
    final current = state;
    if (current is! AuthAuthenticated) return _repository.refreshToken();

    emit(
      AuthState.refreshing(
        current.user,
        sessionProfile: current.sessionProfile,
      ),
    );
    final refreshed = await _repository.refreshToken();
    if (refreshed) {
      emit(
        AuthState.authenticated(
          current.user,
          sessionProfile: current.sessionProfile,
        ),
      );
    }
    return refreshed;
  }

  @override
  Future<void> forceLogout() => logout();
}
