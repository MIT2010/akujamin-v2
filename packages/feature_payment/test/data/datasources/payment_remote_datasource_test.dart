import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:feature_payment/src/data/datasources/payment_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

class _CapturingAdapter implements HttpClientAdapter {
  RequestOptions? capturedOptions;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedOptions = options;
    return ResponseBody.fromString(
      jsonEncode({'status': 'ok'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('PaymentRemoteDataSource.sendPayment', () {
    late _CapturingAdapter adapter;
    late Dio dio;
    late PaymentRemoteDataSource dataSource;
    late File tempFile;

    setUp(() {
      adapter = _CapturingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      dataSource = PaymentRemoteDataSource(ApiClient(dio));
      tempFile = File(
        '${Directory.systemTemp.path}/payment_remote_datasource_test_proof.jpg',
      )..writeAsBytesSync([1, 2, 3, 4]);
    });

    tearDown(() {
      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    test('reads the proof image via XFile (not dart:io\'s File directly) and '
        'sends it as a multipart "bukti" field -- real bug, found 2026-07-17 '
        'from a live web submit: the old MultipartFile.fromFile(imagePath) '
        'call reads through dart:io internally, which throws "Unsupported '
        'operation: _Namespace" on Flutter Web the same way a direct '
        'File(path).readAsBytes() call does', () async {
      final result = await dataSource.sendPayment(tempFile.path);

      expect(result.isOk, isTrue);
      final sentData = adapter.capturedOptions!.data as FormData;
      final buktiEntry = sentData.files.firstWhere((f) => f.key == 'bukti');
      expect(buktiEntry.value.filename, 'bukti.jpg');
      expect(buktiEntry.value.length, 4);
    });

    test('sends no "bukti" field at all when imagePath is null -- matches the '
        'old app\'s own null-file resume-confirmation call', () async {
      final result = await dataSource.sendPayment(null);

      expect(result.isOk, isTrue);
      final sentData = adapter.capturedOptions!.data as FormData;
      expect(sentData.files, isEmpty);
    });
  });
}
