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
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  User toEntity() => User(id: id, email: email, role: role);

  SessionProfile toSessionProfile() =>
      SessionProfile(avatar: avatar, name: name, nik: nik);
}
