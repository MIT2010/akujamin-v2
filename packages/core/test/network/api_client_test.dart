import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

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
  return Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = _FakeAdapter(handler);
}

/// Dio's default transformer only auto-decodes the body as JSON when the
/// response carries a JSON content-type header, so fakes must set it too.
ResponseBody _jsonBody(Map<String, dynamic> json, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(json),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('ApiClient', () {
    test('get() returns Ok and parses a successful body', () async {
      final dio = _buildDio((options) async => _jsonBody({'id': 1}, 200));
      final client = ApiClient(dio);

      final result = await client.get<int>(
        '/thing',
        parser: (json) => (json as Map)['id'] as int,
      );

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, int>).value, 1);
    });

    test('post() returns Ok and parses a successful body', () async {
      final dio = _buildDio(
        (options) async => _jsonBody({'created': true}, 201),
      );
      final client = ApiClient(dio);

      final result = await client.post<bool>(
        '/thing',
        data: {'name': 'x'},
        parser: (json) => (json as Map)['created'] as bool,
      );

      expect(result.isOk, isTrue);
      expect((result as Ok<Failure, bool>).value, isTrue);
    });

    test(
      'maps a 401 response to UnauthorizedFailure carrying the backend\'s '
      'own message -- real bug, found 2026-07-16: this used to always be '
      'the fixed "Session expired" text, so a fresh failed login attempt '
      '(e.g. "Email atau password salah") showed a misleading message',
      () async {
        final dio = _buildDio(
          (options) async => _jsonBody({'message': 'unauth'}, 401),
        );
        final client = ApiClient(dio);

        final result = await client.get<Map>(
          '/thing',
          parser: (json) => json as Map,
        );

        expect(result.isErr, isTrue);
        final failure = (result as Err<Failure, Map>).failure;
        expect(failure, isA<UnauthorizedFailure>());
        expect(failure.message, 'unauth');
      },
    );

    test('falls back to the generic "Session expired" message when a 401 '
        'response carries no message field', () async {
      final dio = _buildDio((options) async => _jsonBody({}, 401));
      final client = ApiClient(dio);

      final result = await client.get<Map>(
        '/thing',
        parser: (json) => json as Map,
      );

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, Map>).failure.message, 'Session expired');
    });

    test(
      'maps a 500 response to ServerFailure with the server message',
      () async {
        final dio = _buildDio(
          (options) async => _jsonBody({'message': 'db down'}, 500),
        );
        final client = ApiClient(dio);

        final result = await client.get<Map>(
          '/thing',
          parser: (json) => json as Map,
        );

        expect(result.isErr, isTrue);
        final failure = (result as Err<Failure, Map>).failure as ServerFailure;
        expect(failure.message, 'db down');
        expect(failure.statusCode, 500);
      },
    );

    test('falls back to a generic message when the body has none', () async {
      final dio = _buildDio((options) async => _jsonBody({}, 503));
      final client = ApiClient(dio);

      final result = await client.get<Map>(
        '/thing',
        parser: (json) => json as Map,
      );

      final failure = (result as Err<Failure, Map>).failure as ServerFailure;
      expect(failure.message, 'Server error');
    });

    test('maps a connection timeout to NetworkFailure', () async {
      final dio = _buildDio(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final client = ApiClient(dio);

      final result = await client.get<Map>(
        '/thing',
        parser: (json) => json as Map,
      );

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, Map>).failure, isA<NetworkFailure>());
    });

    test('prefers a Failure already attached to the DioException', () async {
      final dio = _buildDio(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const NetworkFailure(),
        ),
      );
      final client = ApiClient(dio);

      final result = await client.get<Map>(
        '/thing',
        parser: (json) => json as Map,
      );

      expect((result as Err<Failure, Map>).failure, isA<NetworkFailure>());
    });
  });

  group('ApiClient parser-exception safety -- real gap, found 2026-07-16 '
      'auditing ApiClient after MIGRATION_LOG.md finding #10: that finding\'s '
      'crash (a TypeError from a response shape UserProfileModel.fromJson '
      'didn\'t expect) propagated straight past ApiClient uncaught, since '
      'only DioException was ever caught -- fixed for that one model, but '
      'every method here needed the same general safety net so any *other* '
      'endpoint not yet exercised against a real backend fails the same '
      'handleable way instead of crashing', () {
    test('get() converts a parser TypeError into Result.Err(ParsingFailure) '
        'instead of letting it propagate uncaught', () async {
      final dio = _buildDio((options) async => _jsonBody({}, 200));
      final client = ApiClient(dio);

      final result = await client.get<String>(
        '/thing',
        // Same shape of failure as finding #10: a required field is
        // absent, and the generated cast throws a real TypeError.
        parser: (json) => (json as Map)['missing'] as String,
      );

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, String>).failure, isA<ParsingFailure>());
    });

    test(
      'post() converts a parser TypeError into Result.Err(ParsingFailure)',
      () async {
        final dio = _buildDio((options) async => _jsonBody({}, 201));
        final client = ApiClient(dio);

        final result = await client.post<String>(
          '/thing',
          data: {'name': 'x'},
          parser: (json) => (json as Map)['missing'] as String,
        );

        expect(result.isErr, isTrue);
        expect((result as Err<Failure, String>).failure, isA<ParsingFailure>());
      },
    );

    test(
      'put() converts a parser TypeError into Result.Err(ParsingFailure)',
      () async {
        final dio = _buildDio((options) async => _jsonBody({}, 200));
        final client = ApiClient(dio);

        final result = await client.put<String>(
          '/thing',
          data: {'name': 'x'},
          parser: (json) => (json as Map)['missing'] as String,
        );

        expect(result.isErr, isTrue);
        expect((result as Err<Failure, String>).failure, isA<ParsingFailure>());
      },
    );

    test(
      'delete() converts a parser TypeError into Result.Err(ParsingFailure)',
      () async {
        final dio = _buildDio((options) async => _jsonBody({}, 200));
        final client = ApiClient(dio);

        final result = await client.delete<String>(
          '/thing',
          parser: (json) => (json as Map)['missing'] as String,
        );

        expect(result.isErr, isTrue);
        expect((result as Err<Failure, String>).failure, isA<ParsingFailure>());
      },
    );

    test('multipart() converts a parser TypeError into '
        'Result.Err(ParsingFailure)', () async {
      final dio = _buildDio((options) async => _jsonBody({}, 200));
      final client = ApiClient(dio);

      final result = await client.multipart<String>(
        '/thing',
        data: FormData.fromMap({'field': 'value'}),
        parser: (json) => (json as Map)['missing'] as String,
      );

      expect(result.isErr, isTrue);
      expect((result as Err<Failure, String>).failure, isA<ParsingFailure>());
    });

    test(
      'also catches a FormatException from the parser, not just TypeError',
      () async {
        final dio = _buildDio(
          (options) async => _jsonBody({'value': 'not-a-number'}, 200),
        );
        final client = ApiClient(dio);

        final result = await client.get<int>(
          '/thing',
          parser: (json) => int.parse((json as Map)['value'] as String),
        );

        expect(result.isErr, isTrue);
        expect((result as Err<Failure, int>).failure, isA<ParsingFailure>());
      },
    );

    test(
      'keeps the underlying exception description in the failure message '
      '-- useful for logs/diagnostics, and safe to keep since it '
      'originates from this app\'s own Dart type-cast code, never from '
      'the response body (unlike finding #11\'s raw-SQL disclosure)',
      () async {
        final dio = _buildDio((options) async => _jsonBody({}, 200));
        final client = ApiClient(dio);

        final result = await client.get<String>(
          '/thing',
          parser: (json) => (json as Map)['missing'] as String,
        );

        final failure = (result as Err<Failure, String>).failure;
        expect(failure.message, contains('Format respons tidak sesuai'));
        expect(failure.message, contains('type'));
      },
    );
  });
}
