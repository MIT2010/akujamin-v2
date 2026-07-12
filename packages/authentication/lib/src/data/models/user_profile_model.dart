import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/session_profile.dart';
import '../../domain/entities/user.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

/// DTO for `/auth/me` (§19). Unlike [UserModel], OTP verification only
/// returns an access token — no user fields — so the profile has to be
/// fetched separately afterwards (see [AuthRemoteDataSource.getProfile],
/// used by [AuthRepositoryImpl.verifyOtp]) to produce a full [User].
///
/// `avatar`/`nik` come from the same response but split off into
/// [SessionProfile] rather than [User] — see that class's doc comment for
/// why (MIGRATION_LOG.md's `dashboard`/`account_page` resolution). `avatars`
/// (plural) is the real field name confirmed by reading the old app's
/// `UserModel.fromJson` (`lib/src/features/auth/data/models/user_model.dart`).
@freezed
abstract class UserProfileModel with _$UserProfileModel {
  const UserProfileModel._();

  const factory UserProfileModel({
    required String id,
    required String email,
    required String role,
    required String name,
    @JsonKey(name: 'avatars') required String avatar,
    required String nik,
    // Old app's raw `/api/auth/me` response reads as `data['is_regis']` —
    // a field *sibling* to the `data` object the rest of these fields come
    // from (`lib/src/features/auth/data/repositories/auth_repo_impl.dart`,
    // `final userMap = data['data']; UserModel.fromJson(userMap,
    // data['is_regis'])`), not nested inside it. This model parses every
    // field (including this one) at the top level of whatever `json` it's
    // handed, matching the parsing this class already had before this
    // field was added — consistent with the existing code, not a new
    // assumption introduced here. Whether the *real* migrated `/auth/me`
    // (a different route version, `v1` vs the old app's `api`) actually
    // returns a flat envelope, or whether this whole model has been parsing
    // an incorrect level since it was first written, was not re-verified
    // here — no live response was available to check against (same
    // limitation as docs/qa/register.md's other unverified claims). Not
    // fixed as a side effect of this feature; flagged for separate
    // real-backend verification.
    @JsonKey(name: 'is_regis') @Default(false) bool isRegistered,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  User toEntity() =>
      User(id: id, email: email, role: role, isRegistered: isRegistered);

  SessionProfile toSessionProfile() =>
      SessionProfile(avatar: avatar, name: name, nik: nik);
}
