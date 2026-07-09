import 'package:core/core.dart';

import '../entities/profile.dart';

/// Abstract contract (§18) — the domain layer defines *what* the app does,
/// never *how*. Implemented by [ProfileRepositoryImpl] in the data layer.
/// No local datasource involved anywhere behind this — pure CRUD against
/// the API, unlike `feature_home`'s offline-cache flow (§11).
abstract class ProfileRepository {
  Future<Result<Failure, Profile>> getProfile();
  Future<Result<Failure, Profile>> updateProfile(Profile profile);
}
