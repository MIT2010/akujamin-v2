import 'package:core/core.dart';

import '../entities/counseling_session.dart';

/// Abstract contract (§18). No UseCase in front of this (§21/ADR-004) —
/// the old app's `GetCounselingUsecase` was a one-line pass-through, same
/// "no orchestration to name" shape as `feature_about`/`feature_history`.
abstract class CounselingRepository {
  Future<Result<Failure, List<CounselingSession>>> getSessions();
}
