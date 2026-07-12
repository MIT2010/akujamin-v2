import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/attention_status.dart';
import '../../domain/entities/face_match_result.dart';

part 'proctoring_state.freezed.dart';

/// freezed sealed union (ADR-005) — a genuine two-variant split, unlike
/// `PaymentState`'s single flat class: once the camera is unavailable,
/// none of `detecting`'s fields (status/matchStatus/violation timing)
/// mean anything anymore, so a nullable-field flat class would just
/// invite reading stale values. Old app's `FaceDetectorState` was one
/// flat class with `AttentionStatus.noCamera` folded in as just another
/// status value — this migration deliberately doesn't inherit that,
/// per the camera prerequisite audit's approved fix.
@freezed
sealed class ProctoringState with _$ProctoringState {
  const factory ProctoringState.detecting({
    @Default(AttentionStatus.attentive) AttentionStatus status,
    @Default(FaceMatchStatus.unknown) FaceMatchStatus matchStatus,
    @Default(Duration.zero) Duration violationDuration,
    @Default(false) bool isViolation,
    @Default(false) bool showWarning,
    String? error,
  }) = ProctoringDetecting;

  const factory ProctoringState.cameraUnavailable({
    required CameraFailureReason reason,
    required String message,
  }) = ProctoringCameraUnavailable;
}
