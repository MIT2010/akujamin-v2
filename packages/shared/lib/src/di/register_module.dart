import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../flags/feature_flags.dart';
import 'app_environment.dart';

/// External/third-party instances that can't carry an `@injectable`
/// annotation themselves (§12: "@module → external deps").
///
/// `AuthInterceptor`/`RefreshTokenInterceptor`/`ConnectivityInterceptor`
/// aren't attached yet — they depend on `TokenProvider`/`ConnectivityChecker`
/// implementations that ship with `authentication` and a connectivity
/// plugin, neither of which exists in the repo yet. `LoggingInterceptor`
/// only needs `AppLogger` (already in `core`), so it's safe to wire now.
@module
abstract class RegisterModule {
  @lazySingleton
  Dio dio(AppLogger logger, Env env) {
    return Dio(BaseOptions(baseUrl: env.apiUrl))
      ..interceptors.add(LoggingInterceptor(logger, enabled: env.isDev));
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
