import 'package:freezed_annotation/freezed_annotation.dart';

import 'home_item.dart';

part 'home_feed.freezed.dart';

/// Carries the §11 "stale" tag across the repository boundary — the offline
/// flow needs somewhere to put `isStale` that isn't presentation state,
/// since `HomeRepository.getFeed()` (not the Cubit) is what decides it.
/// Still pure Dart, no Flutter/Hive import.
@freezed
abstract class HomeFeed with _$HomeFeed {
  const factory HomeFeed({
    required List<HomeItem> items,
    @Default(false) bool isStale,
  }) = _HomeFeed;
}
