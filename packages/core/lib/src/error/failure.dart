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
