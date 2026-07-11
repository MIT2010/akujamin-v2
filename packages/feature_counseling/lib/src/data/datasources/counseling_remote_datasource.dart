import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

/// Deliberately thin: returns the raw decoded envelope, same division of
/// labour as every other migrated feature's remote datasource — see
/// `CounselingRepositoryImpl` for why the envelope check stays at that
/// layer.
@injectable
class CounselingRemoteDataSource {
  final ApiClient _client;
  CounselingRemoteDataSource(this._client);

  Future<Result<Failure, Map<String, dynamic>>> getSessions() {
    return _client.get<Map<String, dynamic>>(
      '/chat/list',
      parser: (json) => json as Map<String, dynamic>,
    );
  }
}
