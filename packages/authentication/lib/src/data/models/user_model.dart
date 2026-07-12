import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// DTO that maps to the [User] domain entity (§19). Single factory
/// constructor → `abstract class ... with _$UserModel` per ADR-005.
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String email,
    required String role,
    required String accessToken,
    required String refreshToken,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  // No isRegistered source in this response (the synthetic email/password
  // login flow, unrelated to the real akujamin backend's register concept)
  // -- defaults false, matching the entity's own default.
  User toEntity() => User(id: id, email: email, role: role);
}
