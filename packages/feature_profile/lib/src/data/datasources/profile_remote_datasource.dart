import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../models/profile_model.dart';

/// §19 — talks to `/profile` through `core`'s one Dio instance. Throws
/// nothing itself; [ApiClient] already converts [DioException] into a
/// typed [Failure] before this ever sees it. No local datasource anywhere
/// in this feature — pure CRUD, no offline cache (unlike `feature_home`).
@injectable
class ProfileRemoteDataSource {
  final ApiClient _client;
  ProfileRemoteDataSource(this._client);

  Future<Result<Failure, ProfileModel>> getProfile() {
    return _client.get(
      '/profile',
      parser: (json) => ProfileModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<Result<Failure, ProfileModel>> updateProfile(ProfileModel profile) {
    return _client.put(
      '/profile',
      data: profile.toJson(),
      parser: (json) => ProfileModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
