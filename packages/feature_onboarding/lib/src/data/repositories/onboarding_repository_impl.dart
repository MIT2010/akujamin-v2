import 'package:core/core.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_datasource.dart';

/// §20 — the one place allowed to catch a raw exception and convert it to
/// a [Failure] (§7). `shared_preferences` methods rarely throw, but "rare"
/// isn't "never" (a platform-channel failure is possible), and this is
/// the layer responsible for that boundary regardless of how likely the
/// failure is — not special-cased away just because it's local storage.
@LazySingleton(as: OnboardingRepository)
class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource _local;
  OnboardingRepositoryImpl(this._local);

  @override
  Future<Result<Failure, bool>> getIsFirstLaunch() async {
    try {
      return Ok(_local.getIsFirstLaunch());
    } catch (e) {
      return Err(CacheFailure('Gagal membaca status onboarding: $e'));
    }
  }

  @override
  Future<Result<Failure, void>> setIsFirstLaunch() async {
    try {
      await _local.setIsFirstLaunch();
      return const Ok(null);
    } catch (e) {
      return Err(CacheFailure('Gagal menyimpan status onboarding: $e'));
    }
  }
}
