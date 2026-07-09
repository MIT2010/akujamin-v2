import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/home_feed.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_local_datasource.dart';
import '../datasources/home_remote_datasource.dart';

/// §11's offline flow, concretely:
/// 1. Remote succeeds → write-through to the local cache → `Ok(isStale: false)`.
/// 2. Remote fails with [NetworkFailure] and something is cached → fall back
///    to the cache → `Ok(isStale: true)`, so the UI can show a banner.
/// 3. Remote fails with [NetworkFailure] but the cache is empty (first ever
///    launch, offline) → nothing to fall back to → `Err(failure)`.
/// 4. Remote fails with anything else (`ServerFailure`, `UnauthorizedFailure`,
///    ...) → `Err(failure)` immediately, cache never touched — a real server
///    error must surface, not get silently papered over with stale data.
///
/// No offline queue here (§37/YAGNI): the home feed is read-only, so there's
/// nothing to queue for a later flush.
@LazySingleton(as: HomeRepository)
class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remote;
  final HomeLocalDataSource _local;

  HomeRepositoryImpl(this._remote, this._local);

  @override
  Future<Result<Failure, HomeFeed>> getFeed({
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await _remote.getFeed(page: page, pageSize: pageSize);
    return result.fold(
      (failure) async {
        if (failure is NetworkFailure) {
          final cached = _local.getCached();
          if (cached.isNotEmpty) {
            return Ok(
              HomeFeed(
                items: cached.map((model) => model.toEntity()).toList(),
                isStale: true,
              ),
            );
          }
        }
        return Err(failure);
      },
      (paginated) async {
        await _local.cacheItems(paginated.items);
        return Ok(
          HomeFeed(
            items: paginated.items.map((model) => model.toEntity()).toList(),
            isStale: false,
          ),
        );
      },
    );
  }
}
