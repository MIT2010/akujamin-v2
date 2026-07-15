import 'dart:convert';

import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/session_profile.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/secure_token_storage.dart';

/// `/auth/me` never carries a `role` (Permanent Finding #10) — the only
/// place it genuinely exists is this claim inside the JWT `/auth/login-otp`
/// issues. Decodes the payload segment only (no signature check — this app
/// never verifies its own backend's tokens, only reads a claim already
/// trusted by virtue of coming straight from that backend over TLS/the
/// pinned dev network). Returns `null` on anything malformed rather than
/// throwing — a role decode failure must never block login.
String? _decodeRoleClaim(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final payload =
        jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
            as Map<String, dynamic>;
    return payload['role'] as String?;
  } catch (_) {
    return null;
  }
}

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
        final user = profile.toEntity(
          role: _decodeRoleClaim(accessToken) ?? '',
        );
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
  Future<bool> refreshToken() async {
    final result = await _remote.refreshToken();
    return result.fold((failure) async => false, (envelope) async {
      if (envelope['status'] != 'ok') return false;
      final token = envelope['access_token'] as String?;
      if (token == null || token.isEmpty) return false;
      await _tokenStorage.saveAccessToken(token);
      return true;
    });
  }

  @override
  Future<User?> getCachedUser() => _tokenStorage.getCachedUser();

  @override
  Future<SessionProfile?> getCachedSessionProfile() =>
      _tokenStorage.getCachedSessionProfile();

  @override
  Future<Result<Failure, Map<String, String>>> extractKtp({
    required List<int> ktpImageBytes,
    required List<int> selfieImageBytes,
  }) async {
    final result = await _remote.extractKtp(ktpImageBytes, selfieImageBytes);

    return result.fold(Err.new, (envelope) {
      if (envelope['status'] != 'ok') {
        return Err(
          ServerFailure(
            envelope['message'] as String? ?? 'Gagal mengekstrak KTP.',
          ),
        );
      }

      final data = envelope['data'] as Map<String, dynamic>? ?? const {};
      return Ok(
        data.map((key, value) => MapEntry(key, value?.toString() ?? '')),
      );
    });
  }

  @override
  Future<Result<Failure, void>> submitRegistration({
    required Map<String, String> formData,
    required List<int> selfieImageBytes,
  }) async {
    final result = await _remote.submitRegistration(formData, selfieImageBytes);

    return result.fold(Err.new, (envelope) {
      if (envelope['status'] != 'ok') {
        return Err(
          ServerFailure(envelope['message'] as String? ?? 'Registrasi gagal.'),
        );
      }
      return const Ok(null);
    });
  }

  @override
  Future<Result<Failure, (User, SessionProfile)>> refreshProfile() async {
    final profileResult = await _remote.getProfile();

    return profileResult.fold((failure) async => Err(failure), (profile) async {
      final accessToken = await _tokenStorage.accessToken;
      final role = accessToken == null
          ? ''
          : _decodeRoleClaim(accessToken) ?? '';
      final user = profile.toEntity(role: role);
      final sessionProfile = profile.toSessionProfile();
      await _tokenStorage.saveUser(user);
      await _tokenStorage.saveSessionProfile(sessionProfile);
      return Ok((user, sessionProfile));
    });
  }
}
