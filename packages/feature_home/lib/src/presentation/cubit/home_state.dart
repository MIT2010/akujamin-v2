import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/home_item.dart';

part 'home_state.freezed.dart';

/// freezed 3.x requires `sealed class` for union types with multiple factory
/// constructors (ADR-005).
@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState.initial() = HomeInitial;
  const factory HomeState.loading() = HomeLoading;
  const factory HomeState.loaded(
    List<HomeItem> items, {
    @Default(false) bool isStale,
  }) = HomeLoaded;
  const factory HomeState.error(Failure failure) = HomeError;
}
