/// Cross-cutting glue that is not generic enough for `core`: the DI
/// composition root, `AppRouter`, and the no-op-first Analytics/
/// CrashReporter/FeatureFlags interfaces (§17).
library;

export 'src/analytics/analytics_service.dart';
export 'src/camera/data/datasources/camera_datasource.dart';
export 'src/camera/data/repositories/camera_gateway_impl.dart';
export 'src/camera/domain/entities/camera_config.dart';
export 'src/camera/domain/repositories/camera_gateway.dart';
export 'src/crash/crash_reporter.dart';
export 'src/di/app_environment.dart';
export 'src/di/injection.dart';
export 'src/di/register_module.dart';
export 'src/flags/feature_flags.dart';
export 'src/form_input/data/datasources/form_input_remote_datasource.dart';
export 'src/form_input/data/models/form_field_option_model.dart';
export 'src/form_input/data/models/form_input_field_model.dart';
export 'src/form_input/data/repositories/form_input_repository_impl.dart';
export 'src/form_input/domain/cascading_options.dart';
export 'src/form_input/domain/entities/form_field_option.dart';
export 'src/form_input/domain/entities/form_input_field.dart';
export 'src/form_input/domain/repositories/form_input_repository.dart';
export 'src/notification/data/datasources/notification_datasource.dart';
export 'src/notification/data/repositories/notification_gateway_impl.dart';
export 'src/notification/domain/repositories/notification_gateway.dart';
export 'src/realtime/reconnect_backoff.dart';
export 'src/realtime/socket_event.dart';
export 'src/realtime/socket_gateway.dart';
export 'src/realtime/socket_gateway_impl.dart';
export 'src/router/app_route.dart';
export 'src/router/app_router.dart';
export 'src/router/app_shell.dart';
export 'src/router/auth_session.dart';
export 'src/router/feature_routes.dart';
export 'src/router/go_router_refresh_stream.dart';
export 'src/router/not_found_page.dart';
