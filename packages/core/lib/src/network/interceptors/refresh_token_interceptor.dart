import 'package:dio/dio.dart';

/// On a 401, pauses concurrent failing requests behind a single in-flight
/// `/auth/refresh` call, replays each request once refreshed, and forces
/// logout if the refresh itself fails (§9, §10).
///
/// `core` doesn't know about `/auth/refresh` — that call is injected as
/// [onRefreshToken] by the `authentication` package.
class RefreshTokenInterceptor extends Interceptor {
  final Dio _dio;
  final Future<bool> Function() onRefreshToken;
  final void Function() onRefreshFailed;

  RefreshTokenInterceptor(
    this._dio, {
    required this.onRefreshToken,
    required this.onRefreshFailed,
  });

  static const _refreshRetriedKey = 'refreshRetried';

  Future<bool>? _refreshing;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_refreshRetriedKey] == true;

    if (!isUnauthorized || alreadyRetried) {
      return handler.next(err);
    }

    final refreshed = await (_refreshing ??= _refresh());

    if (!refreshed) {
      onRefreshFailed();
      return handler.next(err);
    }

    try {
      final options = err.requestOptions..extra[_refreshRetriedKey] = true;
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    try {
      return await onRefreshToken();
    } finally {
      _refreshing = null;
    }
  }
}
