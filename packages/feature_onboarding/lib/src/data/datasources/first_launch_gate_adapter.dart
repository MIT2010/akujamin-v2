import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart';

import 'onboarding_local_datasource.dart';

/// The adapter `shared`'s `first_launch_gate.dart` comment promised:
/// `shared` and `feature_onboarding` are siblings (§6), so `AppRouter`
/// depends on the thin `FirstLaunchGate` contract instead of this
/// package's concrete `OnboardingLocalDataSource`. Registering as
/// `@LazySingleton(as: FirstLaunchGate)` supersedes `shared`'s own
/// `AlwaysCompletedFirstLaunchGate` default registration — same
/// mechanism `authentication`'s `AuthSessionAdapter` uses for
/// `AuthSession`; `apps/mobile`'s `injection.dart` lists
/// `FeatureOnboardingPackageModule` after `SharedPackageModule` so this
/// registration is the one that wins.
@LazySingleton(as: FirstLaunchGate)
class FirstLaunchGateAdapter implements FirstLaunchGate {
  final OnboardingLocalDataSource _localDataSource;
  FirstLaunchGateAdapter(this._localDataSource);

  @override
  bool get isFirstLaunch => _localDataSource.getIsFirstLaunch();
}
