import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:feature_history/feature_history.dart';
import 'package:flutter_test/flutter_test.dart';

/// Same fake-adapter shape as `core`'s `api_client_test.dart` — this
/// datasource deliberately bypasses `ApiClient`, so it needs its own Dio
/// wiring to test, not `core`'s.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
}

Dio _buildDio(Future<ResponseBody> Function(RequestOptions) handler) {
  return Dio()..httpClientAdapter = _FakeAdapter(handler);
}

void main() {
  group('CertificateRemoteDataSource.download', () {
    test('returns Ok with the raw bytes on success', () async {
      final bytes = [1, 2, 3, 4];
      final dio = _buildDio(
        (options) async => ResponseBody.fromBytes(bytes, 200),
      );
      final datasource = CertificateRemoteDataSource(dio);

      final result = await datasource.download('https://example.com/cert.pdf');

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, Uint8List>).value, bytes);
    });

    test('maps a connection timeout to NetworkFailure', () async {
      final dio = _buildDio(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final datasource = CertificateRemoteDataSource(dio);

      final result = await datasource.download('https://example.com/cert.pdf');

      expect(result.isErr, isTrue);
      expect(
        (result as Err<Failure, Uint8List>).failure,
        isA<NetworkFailure>(),
      );
    });

    test('maps a non-timeout DioException to ServerFailure', () async {
      final dio = _buildDio(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(requestOptions: options, statusCode: 404),
        ),
      );
      final datasource = CertificateRemoteDataSource(dio);

      final result = await datasource.download('https://example.com/cert.pdf');

      expect(result.isErr, isTrue);
      final failure = (result as Err<Failure, Uint8List>).failure;
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 404);
    });
  });
}
