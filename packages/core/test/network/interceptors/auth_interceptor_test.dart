import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class _FakeTokenProvider implements TokenProvider {
  _FakeTokenProvider(this._token);
  final String? _token;

  @override
  Future<String?> get accessToken async => _token;

  @override
  Future<String?> get refreshToken async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _EchoAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString('{}', 200);
  }
}

void main() {
  group('AuthInterceptor', () {
    test('attaches a Bearer header when a token is present', () async {
      final adapter = _EchoAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(AuthInterceptor(_FakeTokenProvider('abc123')));

      await dio.get('https://api.test/thing');

      expect(adapter.lastOptions!.headers['Authorization'], 'Bearer abc123');
    });

    test('does not attach a header when there is no token', () async {
      final adapter = _EchoAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(AuthInterceptor(_FakeTokenProvider(null)));

      await dio.get('https://api.test/thing');

      expect(
        adapter.lastOptions!.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });
}
