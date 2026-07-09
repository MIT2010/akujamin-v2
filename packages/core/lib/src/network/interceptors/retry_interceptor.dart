import 'package:dio/dio.dart';

/// Retries idempotent GETs only, with exponential backoff, up to
/// [maxRetries] times (§10).
class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  RetryInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 300),
  });

  static const _retryCountKey = 'retryCount';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isIdempotentGet = options.method.toUpperCase() == 'GET';
    final isRetryable =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
    final attempt = (options.extra[_retryCountKey] as int?) ?? 0;

    if (!isIdempotentGet || !isRetryable || attempt >= maxRetries) {
      return handler.next(err);
    }

    await Future<void>.delayed(baseDelay * (1 << attempt));
    options.extra[_retryCountKey] = attempt + 1;

    try {
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
