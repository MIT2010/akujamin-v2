import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// Pure Dart, no json, no Flutter import (§4's dependency rule) — a single
/// factory constructor, so per ADR-005 this is `abstract class ... with
/// _$User`, not `sealed class` (sealed is reserved for union states like
/// `LoginState`, §18).
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String role,
  }) = _User;
}
