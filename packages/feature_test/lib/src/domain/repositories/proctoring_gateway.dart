import '../entities/proctoring_event.dart';

/// Orchestrates the camera feed (`shared`'s `CameraGateway`), on-device
/// face detection, and periodic server-side face-match into one event
/// stream — mirrors the old app's `CameraRepository.startDetection()`,
/// self-contained here rather than in `shared` since nothing outside
/// `test`'s proctoring needs this specific combination (see this
/// package's pubspec description).
abstract class ProctoringGateway {
  Stream<ProctoringEvent> startDetection();

  Future<void> stopDetection();
}
