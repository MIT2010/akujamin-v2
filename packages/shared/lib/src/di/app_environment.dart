import 'package:injectable/injectable.dart';

/// Environment tags used to select per-flavor DI registrations (§12).
/// Named to mirror `core`'s `Flavor` enum 1:1 so `configureDependencies`
/// can pass `env.flavor.name` straight through to `get_it` — injectable's
/// own `Environment` class only pre-defines `dev`/`prod`/`test`, so
/// `staging` is added here as a plain string tag.
abstract class AppEnvironment {
  static const dev = Environment.dev;
  static const staging = 'staging';
  static const prod = Environment.prod;
}
