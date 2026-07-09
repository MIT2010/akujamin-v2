import 'package:dio/dio.dart';

import '../../logger/app_logger.dart';

/// Dev-only request/response logging (§10). Wire `enabled: Env.current.isDev`
/// at the composition root so this is a no-op in staging/prod builds.
class LoggingInterceptor extends Interceptor {
  final AppLogger _logger;
  final bool enabled;

  LoggingInterceptor(this._logger, {this.enabled = true});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      _logger.api('--> ${options.method} ${options.uri}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      _logger.api('<-- ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      _logger.api('<-- ERROR ${err.requestOptions.uri}: ${err.message}');
    }
    handler.next(err);
  }
}
