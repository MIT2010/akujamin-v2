import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/test_history_item.dart';

part 'history_state.freezed.dart';

/// freezed 3.x `sealed class` state union (ADR-005) — same
/// `initial`/`loading`/`loaded`/`error` shape as `feature_about`'s
/// `AboutState`, since the old app's `VoucherState`
/// (`Init`/`Load`/`Success`/`Error`) maps onto it 1:1
/// (docs/MIGRATION_PLAYBOOK.md §2d).
@freezed
sealed class HistoryState with _$HistoryState {
  const factory HistoryState.initial() = HistoryInitial;
  const factory HistoryState.loading() = HistoryLoading;
  const factory HistoryState.loaded(List<TestHistoryItem> items) =
      HistoryLoaded;
  const factory HistoryState.error(Failure failure) = HistoryError;
}
