import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.failuresBeforeSuccess);
  final int failuresBeforeSuccess;
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
    if (callCount <= failuresBeforeSuccess) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return ResponseBody.fromString('{}', 200);
  }
}

void main() {
  group('RetryInterceptor', () {
    test(
      'retries idempotent GETs on connection errors until success',
      () async {
        final adapter = _CountingAdapter(2);
        final dio = Dio()..httpClientAdapter = adapter;
        dio.interceptors.add(
          RetryInterceptor(
            dio,
            maxRetries: 3,
            baseDelay: const Duration(milliseconds: 1),
          ),
        );

        final response = await dio.get('https://api.test/thing');

        expect(response.statusCode, 200);
        expect(adapter.callCount, 3);
      },
    );

    test('gives up after maxRetries and rethrows', () async {
      final adapter = _CountingAdapter(10);
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 1),
        ),
      );

      await expectLater(
        () => dio.get('https://api.test/thing'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 3); // initial attempt + 2 retries
    });

    test('never retries a non-GET request', () async {
      final adapter = _CountingAdapter(10);
      final dio = Dio()..httpClientAdapter = adapter;
      dio.interceptors.add(
        RetryInterceptor(
          dio,
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 1),
        ),
      );

      await expectLater(
        () => dio.post('https://api.test/thing'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 1);
    });
  });
}
