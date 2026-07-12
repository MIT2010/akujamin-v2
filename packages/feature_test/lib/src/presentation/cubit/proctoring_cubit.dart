import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/attention_status.dart';
import '../../domain/entities/face_match_result.dart';
import '../../domain/entities/proctoring_event.dart';
import '../../domain/repositories/proctoring_gateway.dart';
import 'proctoring_state.dart';

/// Mirrors the old app's `FaceDetectorStateCubit` exactly on timing (2s
/// grace period, 10s violation threshold) and transition logic
/// (`_handleDetection`/`_handleMatch`). Two changes, both approved during
/// the camera prerequisite audit: (1) `CameraUnavailableEvent` moves the
/// whole cubit into [ProctoringCameraUnavailable] — a hard, permanent
/// state, not another momentary attention status subject to the grace
/// period; (2) the event stream's `onError` is handled explicitly, so a
/// failure that isn't even a [CameraUnavailableEvent] (an actual
/// uncaught exception somewhere in the gateway) still surfaces instead of
/// leaving the UI silently stuck — the old app's `.listen()` had no
/// `onError` at all.
@injectable
class ProctoringCubit extends Cubit<ProctoringState> {
  ProctoringCubit(this._gateway, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const ProctoringState.detecting());

  final ProctoringGateway _gateway;

  /// Injectable only so tests can drive the grace-period/violation-
  /// threshold logic with a fake clock instead of real multi-second
  /// `Future.delayed` waits — defaults to real time in production,
  /// nothing about the actual behavior changes.
  final DateTime Function() _clock;

  StreamSubscription<ProctoringEvent>? _sub;

  static const gracePeriod = Duration(seconds: 2);
  static const violationThreshold = Duration(seconds: 10);

  DateTime? _violationStartedAt;

  static const _errorMessages = {
    AttentionStatus.noFace: 'Wajah tidak terdeteksi.',
    AttentionStatus.multipleFaces: 'Terdeteksi lebih dari satu wajah.',
  };

  void start() {
    _sub = _gateway.startDetection().listen(
      (event) => switch (event) {
        FaceDetectedEvent(:final status) => _handleDetection(status),
        FaceMatchedEvent(:final result) => _handleMatch(result),
        CameraUnavailableEvent(:final failure) => emit(
          ProctoringState.cameraUnavailable(
            reason: failure.reason,
            message: failure.message,
          ),
        ),
      },
      onError: (Object error, StackTrace stackTrace) {
        emit(
          const ProctoringState.cameraUnavailable(
            reason: CameraFailureReason.permissionDenied,
            message: 'Terjadi kesalahan saat mengakses kamera.',
          ),
        );
      },
    );
  }

  void _handleDetection(AttentionStatus status) {
    final current = state;
    if (current is! ProctoringDetecting) return;

    final now = _clock();

    if (status == AttentionStatus.attentive) {
      _violationStartedAt = null;

      emit(
        current.copyWith(
          status: status,
          violationDuration: Duration.zero,
          showWarning: current.matchStatus != FaceMatchStatus.matched,
          isViolation: current.matchStatus != FaceMatchStatus.matched,
          error: null,
        ),
      );
      return;
    }

    _violationStartedAt ??= now;
    final duration = now.difference(_violationStartedAt!);

    emit(
      current.copyWith(
        status: status,
        violationDuration: duration,
        showWarning: duration >= gracePeriod,
        isViolation: duration >= violationThreshold,
        error: _errorMessages[status],
      ),
    );
  }

  void _handleMatch(FaceMatchResult result) {
    final current = state;
    if (current is! ProctoringDetecting) return;
    if (current.status != AttentionStatus.attentive) return;

    emit(
      current.copyWith(
        matchStatus: result.status,
        isViolation: result.status == FaceMatchStatus.notMatched,
      ),
    );
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    await _gateway.stopDetection();
  }

  @override
  Future<void> close() async {
    await _stop();
    return super.close();
  }
}
