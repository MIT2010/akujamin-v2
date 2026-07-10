import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_profile.freezed.dart';

/// Display-only fields from the same `/auth/me` response `User` is built
/// from (docs/qa/auth_login.md) — deliberately kept out of [User]: `User`
/// is the object callers reach for when wiring session-scoped observability
/// (`CrashReporter.setUserId`/`AnalyticsService.setUserId`, both currently
/// unwired but clearly meant for exactly that), and `nik` (an Indonesian
/// national ID number) must never flow there just because it happened to
/// live on the same "logged in user" object. `name`/`avatar` travel here
/// too, not because they're sensitive the way `nik` is, but because they're
/// the same kind of thing — display-only, not auth/session-relevant — and
/// splitting them across two objects for no reason would just be
/// confusing. Two objects from one fetch, not two sources of truth — see
/// MIGRATION_LOG.md's `dashboard` row.
@freezed
abstract class SessionProfile with _$SessionProfile {
  const factory SessionProfile({
    required String avatar,
    required String name,
    required String nik,
  }) = _SessionProfile;
}
