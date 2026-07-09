import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/profile_model.dart';

/// §20 — converts the remote [ProfileModel] into a domain [Profile] and
/// back. No write-through cache, no stale-fallback branch: unlike
/// `HomeRepositoryImpl` (§11), there's no local datasource to fall back to
/// here at all — a failed request is just a failed request.
@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remote;

  ProfileRepositoryImpl(this._remote);

  @override
  Future<Result<Failure, Profile>> getProfile() async {
    final result = await _remote.getProfile();
    return result.fold(
      (failure) => Err(failure),
      (model) => Ok(model.toEntity()),
    );
  }

  @override
  Future<Result<Failure, Profile>> updateProfile(Profile profile) async {
    final result = await _remote.updateProfile(
      ProfileModel.fromEntity(profile),
    );
    return result.fold(
      (failure) => Err(failure),
      (model) => Ok(model.toEntity()),
    );
  }
}
