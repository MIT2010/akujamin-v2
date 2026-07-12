import 'package:camera/camera.dart';
import 'package:core/core.dart';

import '../entities/camera_config.dart';

/// Generic camera capture primitive (§1 "extract once" — two real
/// consumers already exist in the old app: `auth`'s selfie capture,
/// `test`'s proctoring feed). Deliberately narrow: initialize, capture a
/// still frame, dispose, and expose the raw `CameraController` for a
/// caller that needs more (e.g. a live image stream) — nothing here
/// references any one feature's domain.
///
/// `initialize()` never silently substitutes a different camera than the
/// one requested — a real bug found in the old app's `CameraDatasourceImpl`
/// (`cameras.firstWhere(..., orElse: () => cameras.first)`), which for
/// proctoring specifically would mean analyzing the wrong camera's feed
/// without anyone knowing. Every failure reason is a distinct,
/// [CameraFailureReason] so each caller can react appropriately —
/// this gateway itself doesn't decide what a failure should mean to the
/// UI, only reports it honestly.
abstract class CameraGateway {
  Future<Result<Failure, void>> initialize(CameraConfig config);

  Future<Result<Failure, String>> captureImage();

  Future<void> dispose();

  bool get isInitialized;

  CameraController? get controller;
}
