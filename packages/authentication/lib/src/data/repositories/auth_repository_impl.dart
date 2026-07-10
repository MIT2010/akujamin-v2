import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/session_profile.dart';
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
  Future<Result<Failure, DateTime>> sendOtp({required String phoneNumber}) {
    return _remote.sendOtp(phoneNumber);
  }

  /// Three-step orchestration mirroring [login]'s shape: verify → persist
  /// the (single) access token → fetch the profile the login-otp response
  /// doesn't carry → persist the user *and* the session profile (as two
  /// separate objects — see [SessionProfile]'s doc comment). Both `fold`s
  /// are async for the same reason [login]'s is.
  @override
  Future<Result<Failure, (User, SessionProfile)>> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    final tokenResult = await _remote.verifyOtp(phoneNumber, otpCode);
    return tokenResult.fold((failure) async => Err(failure), (
      accessToken,
    ) async {
      await _tokenStorage.saveAccessToken(accessToken);
      final profileResult = await _remote.getProfile();
      return profileResult.fold((failure) async => Err(failure), (
        profile,
      ) async {
        final user = profile.toEntity();
        final sessionProfile = profile.toSessionProfile();
        await _tokenStorage.saveUser(user);
        await _tokenStorage.saveSessionProfile(sessionProfile);
        return Ok((user, sessionProfile));
      });
    });
  }

  @override
  Future<Result<Failure, void>> logout() async {
    await _tokenStorage.clear();
    return const Ok(null);
  }

  @override
  Future<User?> getCachedUser() => _tokenStorage.getCachedUser();

  @override
  Future<SessionProfile?> getCachedSessionProfile() =>
      _tokenStorage.getCachedSessionProfile();
}
