import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

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
  group('LoggingInterceptor', () {
    test('passes requests through without throwing when enabled', () async {
      final dio = Dio()..httpClientAdapter = _OkAdapter();
      dio.interceptors.add(LoggingInterceptor(const AppLogger()));

      final response = await dio.get('https://api.test/thing');

      expect(response.statusCode, 200);
    });

    test('passes requests through without throwing when disabled', () async {
      final dio = Dio()..httpClientAdapter = _OkAdapter();
      dio.interceptors.add(
        LoggingInterceptor(const AppLogger(), enabled: false),
      );

      final response = await dio.get('https://api.test/thing');

      expect(response.statusCode, 200);
    });
  });
}
