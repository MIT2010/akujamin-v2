import 'package:injectable/injectable.dart';

/// What [AppRouter] needs to know about first-launch onboarding gating —
/// nothing more. Same cross-package pattern as [AuthSession]: `shared`
/// and `feature_onboarding` are siblings in the dependency graph (§6),
/// neither imports the other, so the router depends on this thin
/// contract instead of the concrete `OnboardingLocalDataSource`.
/// `feature_onboarding` will adapt that datasource to it, superseding
/// this file's default registration — zero changes needed here when
/// that happens.
///
/// Real gap, found 2026-07-16 during the akujamin-app comparison audit:
/// the old app's router `redirect` forces every not-yet-logged-in route
/// to `/onboarding` on a genuine first launch, before the guest is even
/// allowed to reach `/login` (`app_routes.dart`). This had no equivalent
/// at all until now — `/onboarding` was only reachable manually, from an
/// already-authenticated Home screen.
abstract class FirstLaunchGate {
  bool get isFirstLaunch;
}

/// Default: nothing gates on first-launch until `feature_onboarding`
/// registers its real, `shared_preferences`-backed implementation under
/// this same interface — same swap-later pattern as
/// [UnauthenticatedAuthSession].
@LazySingleton(as: FirstLaunchGate)
class AlwaysCompletedFirstLaunchGate implements FirstLaunchGate {
  @override
  bool get isFirstLaunch => false;
}
