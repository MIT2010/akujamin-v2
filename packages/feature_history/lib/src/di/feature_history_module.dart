import 'package:injectable/injectable.dart';

/// Marks `feature_history` as an injectable "micro package" (§12), same
/// pattern as every other feature. No `RegisterModule` here — `pdfx`
/// doesn't need DI (it's only ever constructed inside `CertificateView`'s
/// own state, scoped to that one screen, not shared).
@InjectableInit.microPackage()
void configureFeatureHistoryModule() {}
