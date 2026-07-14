import 'package:core/core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart' show getIt;

import '../data/datasources/secure_token_storage.dart';
import '../presentation/cubit/auth_cubit.dart';

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
  /// `RefreshTokenInterceptor`, now wired into `shared`'s
  /// `RegisterModule.dio` (§9/§10). No cycle: [SecureTokenStorage]'s own
  /// dependency chain never reaches back to `Dio`/`ApiClient`.
  @lazySingleton
  TokenProvider tokenProvider(SecureTokenStorage storage) => storage;

  /// Deliberately does *not* take [AuthCubit] as a constructor parameter
  /// (a real, previously-hit circular dependency: `Dio` needs
  /// `TokenRefresher` needs `AuthCubit` needs `AuthRepository` needs
  /// `AuthRemoteDataSource` needs `ApiClient` needs `Dio` — GetIt deadlocks
  /// resolving `Dio` for the very first time, confirmed by every full-DI
  /// `apps/mobile` test timing out at once). [_LazyAuthTokenRefresher]
  /// only resolves `AuthCubit` from `getIt` inside its methods, at call
  /// time — by then `Dio` has already finished constructing, so no cycle.
  @lazySingleton
  TokenRefresher tokenRefresher() => const _LazyAuthTokenRefresher();
}

class _LazyAuthTokenRefresher implements TokenRefresher {
  const _LazyAuthTokenRefresher();

  @override
  Future<bool> refresh() => getIt<AuthCubit>().refresh();

  @override
  Future<void> forceLogout() => getIt<AuthCubit>().forceLogout();
}
