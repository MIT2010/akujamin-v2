import 'dart:convert';
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/src/di/injection.dart';
import 'package:shared/shared.dart' show getIt;
import 'package:shared_preferences/shared_preferences.dart';

/// Closes a real methodological blind spot found during the 2026-07-14
/// reconciliation audit: `AuthInterceptor` was never actually attached to
/// the app's real `Dio` instance at all (see `refresh_token_flow_test.dart`
/// and `MIGRATION_LOG.md`'s `auth` row) — every feature-level test in this
/// codebase mocks `ApiClient`/`AuthRemoteDataSource` at the repository
/// boundary and only ever checks that a call happened and its *response*
/// was parsed correctly. None of them exercise the real Dio interceptor
/// chain, so none of them could have caught a missing/malformed
/// `Authorization` header — "the endpoint was called" and "the header was
/// attached correctly" are different claims, and this codebase's test
/// suite, until this file, only ever proved the first one.
///
/// This test proves the second one directly, against the real DI-wired
/// `Dio` instance: for an ordinary authenticated request (no 401, no
/// retry — that path is `refresh_token_flow_test.dart`'s job), the
/// `Authorization` header is present and matches the exact
/// `Bearer <token>` format, byte for byte, not just "some non-empty
/// header exists." See ARCHITECTURE.md §28 (flutter_starter_kit) for this
/// as a named regression-proof technique: verify request headers/metadata,
/// not just response content.
class _RecordingAdapter implements HttpClientAdapter {
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
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => getIt.reset());

  test('a real authenticated request through the real DI-wired Dio instance '
      'carries a well-formed "Bearer <token>" Authorization header — not '
      'just some header, not just "the request completed"', () async {
    FlutterSecureStorage.setMockInitialValues({
      'com.akujamin.mobile.access_token': 'real-session-token-xyz',
    });

    await configureDependencies(env: Env.current);

    final adapter = _RecordingAdapter();
    getIt<Dio>().httpClientAdapter = adapter;

    final result = await getIt<ApiClient>().get<Map<String, dynamic>>(
      '/protected/anything',
      parser: (json) => json as Map<String, dynamic>,
    );

    expect(result.isOk, isTrue);
    final sentOptions = adapter.lastOptions;
    expect(sentOptions, isNotNull);
    expect(
      sentOptions!.headers.containsKey('Authorization'),
      isTrue,
      reason: 'no Authorization header was attached at all',
    );
    expect(
      sentOptions.headers['Authorization'],
      'Bearer real-session-token-xyz',
      reason:
          'the header must be exactly "Bearer <token>" — wrong scheme, '
          'missing the space, or a stale/wrong token would all satisfy '
          '"a header exists" while still being a real auth bug',
    );
  });
}
