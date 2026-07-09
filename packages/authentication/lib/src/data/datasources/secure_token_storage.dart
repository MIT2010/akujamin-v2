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

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _cachedUserKey = 'cached_user';

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
