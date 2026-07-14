import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../flags/feature_flags.dart';
import 'app_environment.dart';

/// External/third-party instances that can't carry an `@injectable`
/// annotation themselves (§12: "@module → external deps").
///
/// `AuthInterceptor`/`RefreshTokenInterceptor` wired 2026-07-14, once
/// `TokenProvider`/`TokenRefresher` implementations shipped with
/// `authentication` (see its `RegisterModule`) — GetIt resolves both
/// lazily, so this factory only depends on the abstract `core` contracts,
/// never on `authentication` directly (would be circular: `authentication`
/// depends on `shared`, not the other way around). `ConnectivityInterceptor`
/// still isn't attached — no connectivity-plugin implementation exists in
/// the repo yet.
@module
abstract class RegisterModule {
  @lazySingleton
  Dio dio(
    AppLogger logger,
    Env env,
    TokenProvider tokenProvider,
    TokenRefresher tokenRefresher,
  ) {
    final dio = Dio(BaseOptions(baseUrl: env.apiUrl));
    dio.interceptors.addAll([
      LoggingInterceptor(logger, enabled: env.isDev),
      AuthInterceptor(tokenProvider),
      RefreshTokenInterceptor(
        dio,
        onRefreshToken: tokenRefresher.refresh,
        onRefreshFailed: tokenRefresher.forceLogout,
      ),
    ]);
    return dio;
  }

  /// `@Environment`-scoped example of "implementasi berbeda per
  /// environment" (§12) that doesn't require installing a real remote
  /// config provider yet: `dev` gets a debug banner flag on by default,
  /// `staging`/`prod` start with every flag off. Swapping any one of
  /// these three for a real Firebase Remote Config-backed
  /// implementation later touches only this module — never a call site.
  @Environment(AppEnvironment.dev)
  @lazySingleton
  FeatureFlags devFeatureFlags() =>
      const LocalFeatureFlags.withFlags({'debug_banner': true});

  @Environment(AppEnvironment.staging)
  @lazySingleton
  FeatureFlags stagingFeatureFlags() => const LocalFeatureFlags();

  @Environment(AppEnvironment.prod)
  @lazySingleton
  FeatureFlags prodFeatureFlags() => const LocalFeatureFlags();
}
