import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/about.dart';

part 'about_state.freezed.dart';

/// freezed 3.x `sealed class` for the state union (ADR-005). Maps 1:1 onto
/// akujamin-app's `AboutState` union (`Init`/`Loading`/`Success`/`Failed` →
/// `initial`/`loading`/`loaded`/`error`) per docs/MIGRATION_PLAYBOOK.md §2d
/// — no new state was needed, the old shape was already exactly this.
@freezed
sealed class AboutState with _$AboutState {
  const factory AboutState.initial() = AboutInitial;
  const factory AboutState.loading() = AboutLoading;
  const factory AboutState.loaded(List<About> items) = AboutLoaded;
  const factory AboutState.error(Failure failure) = AboutError;
}
