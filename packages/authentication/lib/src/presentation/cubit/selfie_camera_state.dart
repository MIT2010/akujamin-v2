import 'package:core/core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'selfie_camera_state.freezed.dart';

/// Flat class, not a sealed union — `isLoading`/`isReady`/`imagePath`/
/// `error` all need to be read together while rendering (same reasoning as
/// `TestState`, unlike `ProctoringState`'s genuinely disjoint variants).
/// Mirrors the old app's own flat `CameraState` shape.
@freezed
abstract class SelfieCameraState with _$SelfieCameraState {
  const factory SelfieCameraState({
    @Default(false) bool isLoading,
    @Default(false) bool isReady,
    String? imagePath,
    Failure? error,
  }) = _SelfieCameraState;
}
