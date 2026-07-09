import 'package:injectable/injectable.dart';

/// Marks `shared` as an injectable "micro package" (§12), mirroring
/// `core`'s pattern (`core/lib/src/di/core_module.dart`) — this is a
/// *separate* marker from [configureDependencies] in `injection.dart`.
/// That one stays `shared`'s own composition root (used by `shared`'s own
/// test suite); this one lets `apps/mobile` — the only package allowed to
/// depend on both `shared` *and* `authentication` (§6) — fold `shared`'s
/// registrations into the app's real, final composition root without
/// `shared` ever importing `authentication`.
@InjectableInit.microPackage()
void configureSharedModule() {}
