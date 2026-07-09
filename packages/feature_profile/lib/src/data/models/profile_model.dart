import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/profile.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

/// DTO that maps to the [Profile] domain entity (§19). Single factory
/// constructor → `abstract class ... with _$ProfileModel` per ADR-005.
///
/// Needs `fromEntity` (unlike `feature_home`'s read-only `HomeItemModel`):
/// `updateProfile` sends the edited [Profile] back to the API, so this is
/// the one place in the app so far that converts domain → DTO, not just
/// DTO → domain.
@freezed
abstract class ProfileModel with _$ProfileModel {
  const ProfileModel._();

  const factory ProfileModel({
    required String name,
    required String email,
    required String bio,
    required String phoneNumber,
  }) = _ProfileModel;

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  factory ProfileModel.fromEntity(Profile profile) => ProfileModel(
    name: profile.name,
    email: profile.email,
    bio: profile.bio,
    phoneNumber: profile.phoneNumber,
  );

  Profile toEntity() =>
      Profile(name: name, email: email, bio: bio, phoneNumber: phoneNumber);
}
