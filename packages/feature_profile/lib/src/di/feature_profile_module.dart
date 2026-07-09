import 'package:injectable/injectable.dart';

/// Marks `feature_profile` as an injectable "micro package" (§12), same
/// pattern as `core`/`shared`/`authentication`/`feature_home`. No
/// `RegisterModule` here — unlike `feature_home` (Hive box), this feature
/// has no external, non-`@injectable`-able dependency to provide.
@InjectableInit.microPackage()
void configureFeatureProfileModule() {}
