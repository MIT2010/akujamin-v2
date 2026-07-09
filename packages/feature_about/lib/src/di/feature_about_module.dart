import 'package:injectable/injectable.dart';

/// Marks `feature_about` as an injectable "micro package" (§12), same
/// pattern as every other feature. No `RegisterModule` here — no external,
/// non-`@injectable`-able dependency to provide (no cache box, unlike
/// `feature_home`).
@InjectableInit.microPackage()
void configureFeatureAboutModule() {}
