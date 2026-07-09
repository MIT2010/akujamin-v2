/// Cross-cutting glue that is not generic enough for `core`: the DI
/// composition root, `AppRouter`, and the no-op-first Analytics/
/// CrashReporter/FeatureFlags interfaces (§17).
library;

export 'src/analytics/analytics_service.dart';
export 'src/crash/crash_reporter.dart';
export 'src/di/app_environment.dart';
export 'src/di/injection.dart';
export 'src/di/register_module.dart';
export 'src/flags/feature_flags.dart';
export 'src/router/app_route.dart';
export 'src/router/app_router.dart';
export 'src/router/app_shell.dart';
export 'src/router/auth_session.dart';
export 'src/router/feature_routes.dart';
export 'src/router/go_router_refresh_stream.dart';
export 'src/router/not_found_page.dart';
