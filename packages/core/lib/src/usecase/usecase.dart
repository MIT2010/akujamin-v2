import '../error/failure.dart';
import '../result/result.dart';

/// Orchestration boundary for real business logic. Skip this for trivial
/// pass-through CRUD — the Cubit may call the repository directly instead
/// (see §21 / ADR-004 in ARCHITECTURE.md).
abstract class UseCase<R, Params> {
  Future<Result<Failure, R>> call(Params params);
}

class NoParams {
  const NoParams();
}
