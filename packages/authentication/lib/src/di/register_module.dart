import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../data/datasources/secure_token_storage.dart';

/// External dep `SecureTokenStorage` needs (§12: "@module → external
/// deps") — nothing else in `authentication`'s own build_runner scan
/// flagged this, since aggregating packages (`apps/mobile`) deliberately
/// suppress "missing dependency" warnings for anything owned by a
/// micro-package, trusting that package to provide it itself.
@module
abstract class RegisterModule {
  @lazySingleton
  FlutterSecureStorage get flutterSecureStorage => const FlutterSecureStorage();

  /// Exposes the already-registered [SecureTokenStorage] singleton under
  /// `core`'s [TokenProvider] interface too, for `AuthInterceptor`/
  /// `RefreshTokenInterceptor` to resolve once wired into
  /// `shared`'s `RegisterModule.dio`.
  @lazySingleton
  TokenProvider tokenProvider(SecureTokenStorage storage) => storage;
}
