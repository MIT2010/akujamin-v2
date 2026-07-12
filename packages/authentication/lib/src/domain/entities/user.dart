import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

/// Pure Dart, no json, no Flutter import (§4's dependency rule) — a single
/// factory constructor, so per ADR-005 this is `abstract class ... with
/// _$User`, not `sealed class` (sealed is reserved for union states like
/// `LoginState`, §18).
///
/// `isRegistered` sits here, next to [role], not on [SessionProfile] —
/// deliberately: it's an authorization/gating flag (same class as `role`,
/// controls whether `/payment` is reachable — see `feature_home`'s Payment
/// button), not a display-only field like `nik`/`avatar`/`name`. Additive,
/// defaults to `false` so every existing construction site (the synthetic
/// email/password login, which has no real source for this flag) stays
/// valid without change.
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String role,
    @Default(false) bool isRegistered,
  }) = _User;
}
