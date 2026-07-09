import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/secure_token_storage.dart';

/// §20 — converts the remote [UserModel] into a domain [User] and persists
/// tokens (+ the user itself, for [getCachedUser]) on success. Both
/// branches of `fold` are async here so the token-storage write can be
/// awaited before the `Result` resolves.
@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final SecureTokenStorage _tokenStorage;

  AuthRepositoryImpl(this._remote, this._tokenStorage);

  @override
  Future<Result<Failure, User>> login({
    required String email,
    required String password,
  }) async {
    final result = await _remote.login(email, password);
    return result.fold((failure) async => Err(failure), (model) async {
      await _tokenStorage.saveTokens(
        access: model.accessToken,
        refresh: model.refreshToken,
      );
      final user = model.toEntity();
      await _tokenStorage.saveUser(user);
      return Ok(user);
    });
  }

  @override
  Future<Result<Failure, void>> logout() async {
    await _tokenStorage.clear();
    return const Ok(null);
  }

  @override
  Future<User?> getCachedUser() => _tokenStorage.getCachedUser();
}
