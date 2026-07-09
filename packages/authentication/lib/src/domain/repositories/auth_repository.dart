import 'package:core/core.dart';

import '../entities/user.dart';

/// Abstract contract (§18) — the domain layer defines *what* the app does,
/// never *how*. Implemented by [AuthRepositoryImpl] in the data layer.
abstract class AuthRepository {
  Future<Result<Failure, User>> login({
    required String email,
    required String password,
  });
  Future<Result<Failure, void>> logout();
  Future<User?> getCachedUser();
}
