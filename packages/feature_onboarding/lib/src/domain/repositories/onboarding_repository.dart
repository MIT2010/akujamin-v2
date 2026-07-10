import 'package:core/core.dart';

/// Abstract contract (§18). No domain entity here — unlike every other
/// migrated feature so far, there's genuinely nothing to model beyond a
/// bool (the old app's own `OnboardingRepository` contract is exactly
/// `Future<bool> getIsFirstLaunch()` / `Future<void> setIsFirstLaunch()`,
/// no entity either). Adding one just to match the usual shape would be
/// exactly the reflexive-abstraction §21/ADR-004 already warns against
/// for UseCases, generalized to entities.
///
/// `Result`-wrapped even though a local `shared_preferences` read/write
/// is failure-rare in practice — kept consistent with §7/§8's boundary
/// rule rather than special-cased, and it's what actually lets this
/// feature exercise `CacheFailure` (declared in `core` since day one,
/// unused by any feature until now — `about`/`feature_profile`/
/// `feature_home` only ever produce `ServerFailure`/`NetworkFailure`).
abstract class OnboardingRepository {
  Future<Result<Failure, bool>> getIsFirstLaunch();
  Future<Result<Failure, void>> setIsFirstLaunch();
}
