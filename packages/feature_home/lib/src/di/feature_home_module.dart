import 'package:injectable/injectable.dart';

/// Marks `feature_home` as an injectable "micro package" (§12), same
/// pattern as `core`/`shared`/`authentication`. `apps/mobile`'s composition
/// root references the generated `FeatureHomePackageModule` explicitly.
@InjectableInit.microPackage()
void configureFeatureHomeModule() {}
