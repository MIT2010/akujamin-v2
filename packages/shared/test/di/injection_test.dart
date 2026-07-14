import 'package:core/core.dart';
import 'package:shared/shared.dart';
import 'package:flutter_test/flutter_test.dart';

/// `RegisterModule.dio` (§9/§10) now requires a [TokenProvider]/
/// [TokenRefresher] to attach `AuthInterceptor`/`RefreshTokenInterceptor` —
/// real bindings for both only exist in `authentication`'s own module,
/// which this package doesn't (and, by the dependency direction, can't)
/// depend on. `shared`'s own isolated `configureDependencies()` needs a
/// stand-in for each, registered directly, the same way `apps/mobile`'s
/// full DI graph gets the real `authentication`-backed ones.
class _FakeTokenProvider implements TokenProvider {
  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}
  @override
  Future<void> clear() async {}
}

class _FakeTokenRefresher implements TokenRefresher {
  @override
  Future<bool> refresh() async => false;
  @override
  Future<void> forceLogout() async {}
}

void main() {
  group('configureDependencies', () {
    setUp(() {
      getIt.registerLazySingleton<TokenProvider>(() => _FakeTokenProvider());
      getIt.registerLazySingleton<TokenRefresher>(() => _FakeTokenRefresher());
    });
    tearDown(() => getIt.reset());

    test(
      'registers every core + shared service reachable through DI',
      () async {
        await configureDependencies(env: Env.current);

        expect(getIt<Env>(), same(Env.current));
        expect(getIt<AppLogger>(), isA<AppLogger>());
        expect(getIt<ApiClient>(), isA<ApiClient>());
        expect(getIt<AnalyticsService>(), isA<NoopAnalyticsService>());
        expect(getIt<CrashReporter>(), isA<NoopCrashReporter>());
        expect(getIt<FeatureFlags>(), isA<LocalFeatureFlags>());
        expect(getIt<AuthSession>(), isA<UnauthenticatedAuthSession>());
        expect(getIt<AppRouter>(), isA<AppRouter>());
      },
    );

    test(
      'resolves the dev-tagged FeatureFlags when Env.current is dev',
      () async {
        // Env.current defaults to Flavor.dev when no --dart-define is set,
        // which is exactly the case while running tests.
        expect(Env.current.flavor, Flavor.dev);

        await configureDependencies(env: Env.current);

        expect(getIt<FeatureFlags>().isEnabled('debug_banner'), isTrue);
      },
    );

    test('lazy singletons resolve to the same instance every time', () async {
      await configureDependencies(env: Env.current);

      expect(identical(getIt<AppRouter>(), getIt<AppRouter>()), isTrue);
      expect(identical(getIt<ApiClient>(), getIt<ApiClient>()), isTrue);
    });
  });
}
