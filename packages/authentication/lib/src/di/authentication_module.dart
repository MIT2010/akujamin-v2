import 'package:injectable/injectable.dart';

/// Marks `authentication` as an injectable "micro package" (§12), same
/// pattern as `core`/`shared`. `apps/mobile`'s composition root references
/// the generated `AuthenticationPackageModule` explicitly, since
/// `authentication` depends on `shared` (§6) and not the other way
/// around — `shared` can never be the one aggregating this.
@InjectableInit.microPackage()
void configureAuthenticationModule() {}
