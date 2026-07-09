import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/di/injection.dart';

/// Run with: `flutter run --flavor dev -t lib/main_dev.dart
/// --dart-define=API_BASE_URL=YOUR_API_URL` (§30). `dev` is `Env`'s default
/// flavor, so this works even without an explicit
/// `--dart-define=FLAVOR=dev` — the assert below only guards against
/// accidentally passing a *different* FLAVOR define to this entrypoint.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(
    Env.current.flavor == Flavor.dev,
    'main_dev.dart expects Flavor.dev — pass --dart-define=FLAVOR=dev '
    '(or omit it) instead of ${Env.current.flavor.name}.',
  );
  await configureDependencies(env: Env.current);
  runApp(const App());
}
