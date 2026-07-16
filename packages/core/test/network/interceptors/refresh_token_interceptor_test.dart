import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class _UnauthorizedThenOkAdapter implements HttpClientAdapter {
  int callCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    final alreadyRetried = options.extra['refreshRetried'] == true;
    if (!alreadyRetried) {
      return ResponseBody.fromString('{}', 401);
    }
    return ResponseBody.fromString('{"ok":true}', 200);
  }
}

class _AlwaysUnauthorizedAdapter implements HttpClientAdapter {
  int callCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    return ResponseBody.fromString('{}', 401);
  }
}

void main() {
  group('RefreshTokenInterceptor', () {
    test('replays the request once after a successful refresh', () async {
      final adapter = _UnauthorizedThenOkAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      var refreshCalls = 0;
      var loggedOut = false;
      dio.interceptors.add(
        RefreshTokenInterceptor(
          dio,
          onRefreshToken: () async {
            refreshCalls++;
            return true;
          },
          onRefreshFailed: () => loggedOut = true,
        ),
      );

      final response = await dio.get('https://api.test/thing');

      expect(response.statusCode, 200);
      expect(refreshCalls, 1);
      expect(loggedOut, isFalse);
      expect(adapter.callCount, 2);
    });

    test('forces logout and rethrows when the refresh itself fails', () async {
      final adapter = _UnauthorizedThenOkAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      var loggedOut = false;
      dio.interceptors.add(
        RefreshTokenInterceptor(
          dio,
          onRefreshToken: () async => false,
          onRefreshFailed: () => loggedOut = true,
        ),
      );

      await expectLater(
        () => dio.get('https://api.test/thing'),
        throwsA(isA<DioException>()),
      );
      expect(loggedOut, isTrue);
    });

    test('does not attempt a refresh for auth endpoints that never carry a '
        'token, e.g. /auth/login -- real bug, found 2026-07-16: a failed '
        'login used to trigger a spurious refresh attempt', () async {
      final adapter = _AlwaysUnauthorizedAdapter();
      // A baseUrl + relative path, matching how the real app's Dio is
      // configured (RegisterModule.dio) -- unlike the two tests above,
      // this one relies on requestOptions.path actually being "/auth/
      // login" for the exclusion check to mean anything; passing a full
      // absolute URL here would make `path` the whole URL instead.
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      var refreshCalls = 0;
      dio.interceptors.add(
        RefreshTokenInterceptor(
          dio,
          onRefreshToken: () async {
            refreshCalls++;
            return true;
          },
          onRefreshFailed: () {},
        ),
      );

      await expectLater(
        () => dio.post('/auth/login'),
        throwsA(isA<DioException>()),
      );
      expect(refreshCalls, 0);
      expect(adapter.callCount, 1);
    });

    test('does not deadlock when the refresh call itself gets a 401 through '
        'the same Dio instance -- real bug, found 2026-07-16 during live UI '
        'testing: a failed login triggered a refresh attempt whose own 401 '
        're-entered this interceptor and hung both requests forever (stuck '
        'login spinner, no error shown). Guarded with a short timeout so a '
        'regression fails fast instead of hanging the test suite.', () async {
      final adapter = _AlwaysUnauthorizedAdapter();
      // baseUrl + relative paths, matching RegisterModule.dio in the
      // real app -- required for the exclusion check on "/auth/refresh"
      // to actually match (see the test above).
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      var loggedOut = false;
      dio.interceptors.add(
        RefreshTokenInterceptor(
          dio,
          onRefreshToken: () async {
            // Mirrors AuthRepositoryImpl.refreshToken(): the real call
            // goes through the same Dio/ApiClient, and a DioException
            // from it is caught and folded into `false`, never rethrown.
            try {
              final response = await dio.post('/auth/refresh');
              return response.statusCode == 200;
            } on DioException {
              return false;
            }
          },
          onRefreshFailed: () => loggedOut = true,
        ),
      );

      await expectLater(
        () => dio.get('/protected').timeout(const Duration(seconds: 5)),
        throwsA(isA<DioException>()),
      );
      expect(loggedOut, isTrue);
    });
  });
}
