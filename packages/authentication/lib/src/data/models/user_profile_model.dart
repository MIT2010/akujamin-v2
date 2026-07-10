import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

/// DTO for `/auth/me` (§19). Unlike [UserModel], OTP verification only
/// returns an access token — no user fields — so the profile has to be
/// fetched separately afterwards (see [AuthRemoteDataSource.getProfile],
/// used by [AuthRepositoryImpl.verifyOtp]) to produce a full [User].
@freezed
abstract class UserProfileModel with _$UserProfileModel {
  const UserProfileModel._();

  const factory UserProfileModel({
    required String id,
    required String email,
    required String role,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  User toEntity() => User(id: id, email: email, role: role);
}
