import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

/// §19 — talks to `/tes/list-voucher` through `core`'s one Dio instance.
/// Deliberately thin: returns the raw decoded envelope, same division of
/// labour as [AboutRemoteDataSource] in `feature_about` — see
/// `HistoryRepositoryImpl` for why the envelope check stays at that layer.
@injectable
class HistoryRemoteDataSource {
  final ApiClient _client;
  HistoryRemoteDataSource(this._client);

  Future<Result<Failure, Map<String, dynamic>>> getHistory() {
    return _client.get<Map<String, dynamic>>(
      '/tes/list-voucher',
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
