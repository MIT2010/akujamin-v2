import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// External dep the local datasource needs (§12: "@module → external deps
/// ... SharedPreferences"). `@preResolve` because loading it is async and
/// must finish before `get_it` hands out [OnboardingLocalDataSource] —
/// same pattern as `feature_home`'s `homeItemsBox`, just for
/// `shared_preferences` instead of `hive_ce` since `feature_onboarding`
/// is the first (and so far only) feature using it.
@module
abstract class RegisterModule {
  @preResolve
  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();
}
