import 'package:core/core.dart';

import '../entities/about.dart';

/// Abstract contract (§18). Implemented by [AboutRepositoryImpl].
///
/// No UseCase in front of this (§21/ADR-004) — the old app's
/// `GetAboutUsecase` was a one-line pass-through
/// (`sl<AboutRepository>().getAbout()`), the textbook "no orchestration to
/// name" case docs/MIGRATION_PLAYBOOK.md §2c calls out; the migrated Cubit
/// calls this directly, same shape as `feature_profile`'s `getProfile()`.
abstract class AboutRepository {
  Future<Result<Failure, List<About>>> getAbout();
}
