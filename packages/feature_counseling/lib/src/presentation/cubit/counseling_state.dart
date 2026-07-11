import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/counseling_session.dart';

part 'counseling_state.freezed.dart';

/// freezed 3.x `sealed class` state union (ADR-005) — same
/// `initial`/`loading`/`loaded`/`error` shape as `HistoryState`. No
/// realtime here — the old app's `CounselingPage` (session list) never
/// touches the websocket at all, only `ChatPage` (one thread) does.
@freezed
sealed class CounselingState with _$CounselingState {
  const factory CounselingState.initial() = CounselingInitial;
  const factory CounselingState.loading() = CounselingLoading;
  const factory CounselingState.loaded(List<CounselingSession> sessions) =
      CounselingLoaded;
  const factory CounselingState.error(Failure failure) = CounselingError;
}
