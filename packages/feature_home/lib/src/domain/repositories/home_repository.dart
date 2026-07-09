import 'package:core/core.dart';

import '../entities/home_feed.dart';

/// Abstract contract (§18) — the domain layer defines *what* the app does,
/// never *how*. Implemented by [HomeRepositoryImpl] in the data layer,
/// which owns the §11 offline-cache decision this signature implies.
abstract class HomeRepository {
  Future<Result<Failure, HomeFeed>> getFeed({int page = 1, int pageSize = 20});
}
