import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// §19/§24 — the first feature to use `shared_preferences` rather than
/// `hive_ce` (structured cache, `feature_home`) or nothing at all
/// (`feature_about`/`feature_profile`). Correct per ARCHITECTURE.md §24's
/// storage-choice table ("small, non-sensitive flags: theme mode,
/// onboarding-seen, locale → shared_preferences") — and a deliberate
/// *correction* of the old app, not a faithful port: `OnboardingLocalServiceImpl`
/// (akujamin-app) stored this same flag in `flutter_secure_storage`, which
/// is the wrong tier for a non-sensitive boolean. Moving a non-sensitive
/// value to a *lighter* tier isn't the "storage tier must not downgrade"
/// case docs/MIGRATION_PLAYBOOK.md §3 warns about — that rule protects
/// actually-sensitive fields from landing somewhere weaker; there was
/// never anything here worth protecting.
@injectable
class OnboardingLocalDataSource {
  final SharedPreferences _prefs;
  OnboardingLocalDataSource(this._prefs);

  static const _key = 'has_completed_onboarding';

  /// `true` until the flag has ever been set — same polarity as the old
  /// app's `getIsFirstLaunch()` (kept for direct behavior traceability,
  /// docs/MIGRATION_PLAYBOOK.md §0).
  bool getIsFirstLaunch() => !(_prefs.getBool(_key) ?? false);

  Future<void> setIsFirstLaunch() => _prefs.setBool(_key, true);
}
