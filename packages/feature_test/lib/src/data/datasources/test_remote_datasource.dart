import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Talks to `/pertanyaan/getv2`/`/pertanyaan/savev2` through `core`'s one
/// Dio instance — same base path as `feature_test`'s already-built
/// `FaceMatchDatasource` (`/pertanyaan/face-matchv2`), verified against the
/// old app's `TestApiServiceImpl` in full. `getTests` sends `FormData`
/// (matches the old app, and — per docs/qa/test.md §3 — is not leaked by
/// the old app's logging interceptor either way); `saveTestAnswer` sends a
/// raw JSON string body, exactly as the old app did (the one leaked call,
/// already recorded — `core`'s own logger doesn't log bodies at all, so
/// this doesn't reintroduce that leak here).
@injectable
class TestRemoteDataSource {
  final ApiClient _client;
  TestRemoteDataSource(this._client);

  Future<Result<Failure, Map<String, dynamic>>> getTests(String voucherCode) {
    return _client.post<Map<String, dynamic>>(
      '/pertanyaan/getv2',
      data: FormData.fromMap({'kode_voucher': voucherCode}),
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  Future<Result<Failure, Map<String, dynamic>>> saveTestAnswer(String body) {
    return _client.post<Map<String, dynamic>>(
      '/pertanyaan/savev2',
      data: body,
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
