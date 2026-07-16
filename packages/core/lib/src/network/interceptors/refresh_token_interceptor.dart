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

  /// Endpoints that never carry an access token in the first place, so a
  /// 401 from them must never enter the refresh-and-retry branch below.
  /// `/auth/refresh` is the load-bearing entry here — real bug, found
  /// 2026-07-16 during live UI testing: without this exclusion, a failed
  /// login's 401 triggered a refresh attempt, and that refresh call's own
  /// 401 re-entered this exact `onError` (same interceptor instance, same
  /// `Dio`), recursing into awaiting the very `_refreshing` Future it was
  /// itself a step of. Neither the login nor the refresh request's
  /// handler was ever resolved/rejected, so both hung forever — visible
  /// as a login button whose spinner never stops and no error shown.
  static const _excludedPaths = {
    '/auth/login',
    '/auth/refresh',
    '/auth/send-otp',
    '/auth/login-otp',
  };

  Future<bool>? _refreshing;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra[_refreshRetriedKey] == true;
    final isExcluded = _excludedPaths.contains(err.requestOptions.path);

    if (!isUnauthorized || alreadyRetried || isExcluded) {
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
