import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/di/injection.dart';

/// Run with: `flutter run --flavor prod -t lib/main_prod.dart
/// --dart-define=FLAVOR=prod --dart-define=API_BASE_URL=YOUR_API_URL` (§29, §30).
/// `prod` is *not* `Env`'s default flavor, so `--dart-define=FLAVOR=prod`
/// is required — the assert below catches the (common) mistake of
/// forgetting it and silently shipping a prod build wired as `dev`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(
    Env.current.flavor == Flavor.prod,
    'main_prod.dart expects Flavor.prod — pass --dart-define=FLAVOR=prod '
    '(got ${Env.current.flavor.name}).',
  );
  await configureDependencies(env: Env.current);
  runApp(const App());
}
