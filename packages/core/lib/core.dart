/// Pure-Dart foundation package shared by every feature: `Result`/`Failure`,
/// `UseCase`, `ApiClient` + interceptors, `Env`, `AppLogger` and small
/// cross-cutting extensions. Contains zero Flutter or UI imports.
library;

export 'src/connectivity/connectivity_checker.dart';
export 'src/env/env.dart';
export 'src/error/failure.dart';
export 'src/extensions/formatter_extensions.dart';
export 'src/extensions/validator_extensions.dart';
export 'src/logger/app_logger.dart';
export 'src/network/api_client.dart';
export 'src/network/api_response.dart';
export 'src/network/interceptors/auth_interceptor.dart';
export 'src/network/interceptors/connectivity_interceptor.dart';
export 'src/network/interceptors/logging_interceptor.dart';
export 'src/network/interceptors/refresh_token_interceptor.dart';
export 'src/network/interceptors/retry_interceptor.dart';
export 'src/network/token_provider.dart';
export 'src/network/token_refresher.dart';
export 'src/pagination/pagination.dart';
export 'src/result/result.dart';
export 'src/usecase/usecase.dart';
