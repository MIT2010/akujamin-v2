import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// App-wide session state (§9) — checks the cached user once at boot, and
/// is what [AuthSessionAdapter] (in the same folder) wraps for
/// `AppRouter`'s redirect logic. `@lazySingleton` (not `@injectable`) so
/// [LoginCubit] and the router's `AuthSession` adapter share the exact same
/// instance/stream — logging in has to be visible to both.
@lazySingleton
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit(this._repository) : super(const AuthState.initial()) {
    _restoreCachedSession();
  }

  Future<void> _restoreCachedSession() async {
    final user = await _repository.getCachedUser();
    emit(
      user != null
          ? AuthState.authenticated(user)
          : const AuthState.unauthenticated(),
    );
  }

  /// Called by [LoginCubit] right after a successful login — the tokens are
  /// already persisted by [AuthRepositoryImpl.login] by this point, this
  /// just makes the in-memory session (and therefore the router) catch up.
  void setAuthenticated(User user) => emit(AuthState.authenticated(user));

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthState.unauthenticated());
  }
}
