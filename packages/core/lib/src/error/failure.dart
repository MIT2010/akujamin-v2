/// Base type for every error that can cross the data → domain boundary.
/// The repository implementation is the only place allowed to catch a raw
/// exception and convert it into one of these (§7 of ARCHITECTURE.md).
sealed class Failure {
  final String message;
  const Failure(this.message);
}

final class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

final class NetworkFailure extends Failure {
  const NetworkFailure() : super('No internet connection');
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('Session expired');
}

/// Distinguishes *why* a camera operation failed — added so a caller can
/// react differently to each (e.g. `test`'s proctoring treats every
/// reason as a hard block with its own message, never lumping "no front
/// camera" in with "face not currently in frame"). Deliberately does not
/// distinguish device-permission-denied from other native
/// `CameraException`s beyond that one case — no evidence yet that finer
/// granularity is needed by any real consumer.
enum CameraFailureReason {
  noCameraOnDevice,
  requestedLensNotFound,
  permissionDenied,
  captureFailed,
}

final class CameraFailure extends Failure {
  final CameraFailureReason reason;
  const CameraFailure(this.reason, super.message);
}

/// Mirrors [CameraFailureReason]'s reasoning: the old app's
/// `NotificationLocalServiceImpl.show()` requested permission but never
/// checked the result before calling `plugin.show()` regardless — a
/// silent-substitution bug in the same class as the camera lens fallback,
/// just for notifications instead of camera lenses. `permissionDenied`
/// lets `NotificationGatewayImpl` return an honest `Err` instead of
/// calling the plugin anyway.
enum NotificationFailureReason { permissionDenied, showFailed }

final class NotificationFailure extends Failure {
  final NotificationFailureReason reason;
  const NotificationFailure(this.reason, super.message);
}
