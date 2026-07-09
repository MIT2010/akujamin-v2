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
  });
}
