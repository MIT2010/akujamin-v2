import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'login_state.freezed.dart';

/// §22 — a union of 4 states, so per ADR-005 this is `sealed class ...
/// with _$LoginState`, matched with native `switch` at call sites
/// (`LoginPage`'s `listener`) instead of the old `.when()`/`.whenOrNull()`.
@freezed
sealed class LoginState with _$LoginState {
  const factory LoginState.initial() = LoginInitial;
  const factory LoginState.loading() = LoginLoading;
  const factory LoginState.success(User user) = LoginSuccess;
  const factory LoginState.failure(Failure failure) = LoginFailureState;
}
