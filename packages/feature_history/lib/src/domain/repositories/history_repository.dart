import 'package:core/core.dart';

import '../entities/test_history_item.dart';

/// Abstract contract (§18). Implemented by [HistoryRepositoryImpl].
///
/// No UseCase in front of this (§21/ADR-004) — the old app's `GetVouchers`
/// usecase was a one-line pass-through
/// (`sl<PaymentRepository>().getVouchers()`), same "no orchestration to
/// name" shape as `feature_about`'s `getAbout()`.
abstract class HistoryRepository {
  Future<Result<Failure, List<TestHistoryItem>>> getHistory();
}
