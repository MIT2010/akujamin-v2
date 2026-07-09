import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class _FakeConnectivityChecker implements ConnectivityChecker {
  _FakeConnectivityChecker(this._connected);
  final bool _connected;

  @override
  Future<bool> get isConnected async => _connected;
}

class _NeverCalledAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw StateError('adapter should never be reached while offline');
  }
}

class _OkAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', 200);
}

void main() {
  group('ConnectivityInterceptor', () {
    test('fails fast with NetworkFailure when offline', () async {
      final dio = Dio()..httpClientAdapter = _NeverCalledAdapter();
      dio.interceptors.add(
        ConnectivityInterceptor(_FakeConnectivityChecker(false)),
      );

      await expectLater(
        () => dio.get('https://api.test/thing'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<NetworkFailure>(),
          ),
        ),
      );
    });

    test('passes the request through when online', () async {
      final dio = Dio()..httpClientAdapter = _OkAdapter();
      dio.interceptors.add(
        ConnectivityInterceptor(_FakeConnectivityChecker(true)),
      );

      final response = await dio.get('https://api.test/thing');

      expect(response.statusCode, 200);
    });
  });
}
