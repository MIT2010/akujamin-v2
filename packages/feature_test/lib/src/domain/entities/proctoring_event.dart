import 'package:core/core.dart';

import 'attention_status.dart';
import 'face_match_result.dart';

/// Mirrors the old app's `FaceEvent` hierarchy, with one deliberate
/// change: camera failure now carries the specific [CameraFailure] (with
/// its [CameraFailureReason]) instead of being folded into a generic
/// `NoCameraEvent` — see [AttentionStatus]'s doc comment for why.
sealed class ProctoringEvent {
  const ProctoringEvent();
}

final class FaceDetectedEvent extends ProctoringEvent {
  final AttentionStatus status;
  const FaceDetectedEvent(this.status);
}

final class FaceMatchedEvent extends ProctoringEvent {
  final FaceMatchResult result;
  const FaceMatchedEvent(this.result);
}

final class CameraUnavailableEvent extends ProctoringEvent {
  final CameraFailure failure;
  const CameraUnavailableEvent(this.failure);
}
