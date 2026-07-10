import 'package:injectable/injectable.dart';

/// Marks `feature_onboarding` as an injectable "micro package" (§12), same
/// pattern as every other feature.
@InjectableInit.microPackage()
void configureFeatureOnboardingModule() {}
