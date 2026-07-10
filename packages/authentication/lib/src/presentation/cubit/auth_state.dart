import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/session_profile.dart';
import '../../domain/entities/user.dart';

part 'auth_state.freezed.dart';

/// The app-wide session state (§9) — distinct from [LoginState], which is
/// scoped to the login *screen's* form submission. A union of 3 states, so
/// per ADR-005 this is `sealed class ... with _$AuthState`.
///
/// `sessionProfile` is optional and additive (MIGRATION_LOG.md's
/// `dashboard`/`account_page` resolution) — `null` for the synthetic
/// email/password [LoginCubit] flow, which never had one; populated for
/// the OTP flow. Deliberately not folded into [User] — see
/// [SessionProfile]'s doc comment.
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.authenticated(
    User user, {
    SessionProfile? sessionProfile,
  }) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
}
