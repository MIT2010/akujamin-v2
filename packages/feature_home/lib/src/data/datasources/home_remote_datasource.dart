import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../models/home_item_model.dart';

/// §19 — talks to `/home/feed` through `core`'s one Dio instance. Throws
/// nothing itself; [ApiClient] already converts [DioException] into a
/// typed [Failure] before this ever sees it.
@injectable
class HomeRemoteDataSource {
  final ApiClient _client;
  HomeRemoteDataSource(this._client);

  Future<Result<Failure, Pagination<HomeItemModel>>> getFeed({
    int page = 1,
    int pageSize = 20,
  }) {
    return _client.get(
      '/home/feed',
      query: {'page': page, 'pageSize': pageSize},
      parser: (json) => Pagination<HomeItemModel>.fromJson(
        json as Map<String, dynamic>,
        (itemJson) => HomeItemModel.fromJson(itemJson as Map<String, dynamic>),
      ),
    );
  }
}
