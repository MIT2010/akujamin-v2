import 'package:core/core.dart';
// The micro-package module core's own build_runner run generates. Not
// exported through `core.dart`'s barrel (it's a codegen hook, not public
// API) — imported directly here, the one place that needs it.
// ignore: implementation_imports
import 'package:core/src/di/core_module.module.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

/// The one `GetIt` instance for the whole app (§12). Every `@injectable`/
/// `@lazySingleton`-annotated class reachable from `shared` (i.e. `core`,
/// `design_system` and `shared` itself) gets registered here by
/// `configureDependencies()` — no manual `getIt.registerLazySingleton(...)`
/// calls anywhere in feature code.
final getIt = GetIt.instance;

/// Called once from `main_<flavor>.dart` as
/// `await configureDependencies(env: Env.current)` (§12). Threading `Env`
/// through explicitly — rather than having DI-managed classes read the
/// `Env.current` global themselves — is what makes `env.flavor` select
/// the right `@Environment(...)`-tagged registrations below, and keeps
/// anything that needs config (e.g. `RegisterModule.dio`) constructor-
/// injectable instead of reaching for a static.
///
/// `externalPackageModulesBefore` is how `core`'s `@lazySingleton` classes
/// (`ApiClient`, `AppLogger`) end up registered here without `shared`
/// depending on `core`'s internals — `CorePackageModule` is the module
/// `core`'s own `@InjectableInit.microPackage()` (see
/// `core/lib/src/di/core_module.dart`) generates.
@InjectableInit(
  preferRelativeImports: true,
  externalPackageModulesBefore: [ExternalModule(CorePackageModule)],
)
Future<void> configureDependencies({required Env env}) async {
  getIt.registerSingleton<Env>(env);
  await getIt.init(environment: env.flavor.name);
}
