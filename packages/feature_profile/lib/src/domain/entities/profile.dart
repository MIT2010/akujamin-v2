import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';

/// Pure Dart, no json, no Flutter import (§4's dependency rule) — a single
/// factory constructor, so per ADR-005 this is `abstract class ... with
/// _$Profile`, not `sealed class`.
///
/// Deliberately its own entity, not `authentication`'s [User] with a few
/// fields bolted on: `User` is "who is logged in and what can they do"
/// (id/email/role, read by `AuthSession`/route guards); `Profile` is "what
/// gets displayed and edited on the profile screen" (name/email/bio/phone).
/// They happen to share `email` today because that's what the API returns
/// for both — that's a coincidence of the current backend, not a reason to
/// merge two entities that answer different questions and will drift
/// independently (e.g. `User.role` never belongs on a profile edit form,
/// and `Profile.bio` never belongs on an auth guard).
@freezed
abstract class Profile with _$Profile {
  const factory Profile({
    required String name,
    required String email,
    required String bio,
    required String phoneNumber,
  }) = _Profile;
}
