import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// Marks `core` as an injectable "micro package" (§12). This has no
/// runtime effect by itself — `build_runner` turns it into
/// `core_module.module.dart`, a small generated module that the app's
/// composition root (`shared`'s `@InjectableInit`) auto-discovers so
/// `core`'s `@lazySingleton` classes (`ApiClient`, `AppLogger`, ...) end up
/// registered in `get_it` without `shared` importing `core`'s internals.
///
/// [Dio] is deliberately ignored here: `core` only *consumes* it
/// (`ApiClient`'s constructor param), it never registers it — that's
/// `shared`'s `RegisterModule` — so this micro-package build can't see it
/// yet and would otherwise warn about a false-positive missing dependency.
@InjectableInit.microPackage(ignoreUnregisteredTypes: [Dio])
void configureCoreModule() {}
