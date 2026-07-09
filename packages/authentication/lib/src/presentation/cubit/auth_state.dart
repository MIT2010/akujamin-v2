import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'auth_state.freezed.dart';

/// The app-wide session state (§9) — distinct from [LoginState], which is
/// scoped to the login *screen's* form submission. A union of 3 states, so
/// per ADR-005 this is `sealed class ... with _$AuthState`.
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.authenticated(User user) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
}
