import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/session_profile.dart';
import '../../domain/entities/user.dart';

part 'auth_state.freezed.dart';

/// The app-wide session state (§9) — distinct from [LoginState], which is
/// scoped to the login *screen's* form submission. A union of 4 states, so
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

  /// A reactive `RefreshTokenInterceptor`-triggered token refresh is in
  /// flight — real bug, found 2026-07-17 from live testing: `AuthCubit.
  /// refresh()` used to leave `state` untouched during the refresh call,
  /// then only ever emit `unauthenticated` (forcing `/login`) via
  /// `forceLogout()` on *failure* -- so a *successful* refresh looked
  /// correct on paper (no emission at all), but there was nothing to
  /// show the user *while waiting* either. Carries the same [user]/
  /// [sessionProfile] the app was showing right before the refresh
  /// started (not discarded), so `AuthSessionAdapter` can still report
  /// this as authenticated -- `AppRouter` must never redirect away from
  /// the current screen just because a refresh is in progress, only
  /// once a refresh genuinely fails.
  const factory AuthState.refreshing(
    User user, {
    SessionProfile? sessionProfile,
  }) = AuthRefreshing;

  const factory AuthState.unauthenticated() = AuthUnauthenticated;
}
