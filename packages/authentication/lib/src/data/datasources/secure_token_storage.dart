import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/user.dart';

/// §24's local-cache example, concretely: `flutter_secure_storage` needs
/// the Flutter SDK, so this lives here rather than in pure-Dart `core` —
/// `core` only owns the abstract [TokenProvider] contract that
/// `AuthInterceptor`/`RefreshTokenInterceptor` depend on.
///
/// Registered under its *own* concrete type (not `as: TokenProvider`)
/// because [AuthRepositoryImpl] needs the extra [getCachedUser]/[saveUser]
/// methods that aren't part of the `TokenProvider` interface — `core`
/// doesn't have a concept of "user," only opaque token strings. It's
/// *also* exposed as `TokenProvider` via `RegisterModule.tokenProvider`,
/// for `AuthInterceptor`/`RefreshTokenInterceptor` to resolve once they're
/// wired into `RegisterModule.dio`.
///
/// Also caches the last-known [User] alongside the tokens.
@lazySingleton
class SecureTokenStorage implements TokenProvider {
  final FlutterSecureStorage _storage;
  SecureTokenStorage(this._storage);

  // Prefixed, not just 'access_token': Android/iOS/macOS sandbox secure
  // storage per app automatically (Keychain access group / app-private
  // Keystore), but Windows does not -- flutter_secure_storage_windows
  // writes each key as a Windows Credential Manager entry named literally
  // after the key string, with no per-app namespacing at all (confirmed by
  // reading flutter_secure_storage_windows_plugin.cpp: TargetName is set
  // directly from the key). Two different Flutter projects on the same
  // Windows account that both call `write(key: 'access_token', ...)`
  // collide in the *same* global credential, regardless of bundle
  // identifier -- this prefix is what actually prevents that on Windows,
  // not the platform bundle IDs (which fix the equivalent Android/iOS/
  // macOS non-issue but do nothing here).
  static const _keyPrefix = 'com.akujamin.mobile.';
  static const _accessTokenKey = '${_keyPrefix}access_token';
  static const _refreshTokenKey = '${_keyPrefix}refresh_token';
  static const _cachedUserKey = '${_keyPrefix}cached_user';

  @override
  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  @override
  Future<void> clear() => _storage.deleteAll();

  /// OTP login only ever returns a single access token, no refresh token
  /// (docs/qa/auth_login.md §2 — a real architecture mismatch with
  /// [saveTokens], not a placeholder-value workaround). Writes just the
  /// access-token key, leaves whatever refresh token is already stored
  /// untouched.
  Future<void> saveAccessToken(String access) {
    return _storage.write(key: _accessTokenKey, value: access);
  }

  Future<void> saveUser(User user) {
    return _storage.write(
      key: _cachedUserKey,
      value: jsonEncode({
        'id': user.id,
        'email': user.email,
        'role': user.role,
      }),
    );
  }

  Future<User?> getCachedUser() async {
    final raw = await _storage.read(key: _cachedUserKey);
    if (raw == null) return null;

    final json = jsonDecode(raw) as Map<String, dynamic>;
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}
