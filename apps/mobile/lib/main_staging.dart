import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/di/injection.dart';

/// Run with: `flutter run --flavor staging -t lib/main_staging.dart
/// --dart-define=FLAVOR=staging --dart-define=API_BASE_URL=YOUR_API_URL` (§30).
/// Unlike `dev`, `staging` is *not* `Env`'s default flavor, so the
/// `--dart-define=FLAVOR=staging` is required, not optional — the assert
/// below catches the (common) mistake of forgetting it.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(
    Env.current.flavor == Flavor.staging,
    'main_staging.dart expects Flavor.staging — pass '
    '--dart-define=FLAVOR=staging (got ${Env.current.flavor.name}).',
  );
  await configureDependencies(env: Env.current);
  runApp(const App());
}
