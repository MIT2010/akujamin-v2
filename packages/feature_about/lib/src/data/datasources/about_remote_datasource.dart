import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

/// §19 — talks to `/faq/get` through `core`'s one Dio instance. Deliberately
/// thin: returns the raw decoded envelope, same division of labour as the
/// old app's `AboutApiService` (which also returned the raw
/// `Map<String, dynamic>` and left interpreting it to the repository) —
/// see [AboutRepositoryImpl] for why that split is kept, not "improved"
/// away, in the migrated version.
@injectable
class AboutRemoteDataSource {
  final ApiClient _client;
  AboutRemoteDataSource(this._client);

  Future<Result<Failure, Map<String, dynamic>>> getAbout() {
    return _client.get<Map<String, dynamic>>(
      '/faq/get',
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
