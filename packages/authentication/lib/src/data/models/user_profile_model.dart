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
///
/// **Confirmed against the real Development backend, 2026-07-15**
/// (MIGRATION_LOG.md Permanent Finding #10) — this DTO expects an already
/// *flat* map on purpose: [AuthRemoteDataSource.getProfile] does the
/// unwrapping (`data['data']` plus the sibling `data['is_regis']`, exactly
/// the old app's own `auth_repo_impl.dart` shape) before calling
/// [UserProfileModel.fromJson], so this class itself never has to know
/// about the envelope. `id` arrives as a JSON **number**, not a string
/// (`_idFromJson` below) — also matching the old app's own
/// `json['id'].toString()`. There is **no `role` field anywhere in the
/// real `/auth/me` response** — confirmed both live and by re-reading the
/// old app's `UserModel`, which never had one either; the only place a
/// role genuinely exists is the `role` claim inside the JWT
/// `/auth/login-otp` returns, so [AuthRepositoryImpl] supplies it
/// separately to [toEntity] rather than this DTO carrying it.
@freezed
abstract class UserProfileModel with _$UserProfileModel {
  const UserProfileModel._();

  const factory UserProfileModel({
    @JsonKey(fromJson: _idFromJson) required String id,
    required String email,
    required String name,
    @JsonKey(name: 'avatars') required String avatar,
    required String nik,
    @JsonKey(name: 'is_regis') @Default(false) bool isRegistered,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  /// `role` isn't part of this DTO — see the class doc comment — so every
  /// caller must supply it (from the JWT claim; empty string if it can't be
  /// decoded, never a guessed default).
  User toEntity({required String role}) =>
      User(id: id, email: email, role: role, isRegistered: isRegistered);

  SessionProfile toSessionProfile() =>
      SessionProfile(avatar: avatar, name: name, nik: nik);
}

String _idFromJson(dynamic value) => value.toString();
