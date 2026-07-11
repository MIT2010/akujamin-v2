// The generated micro-package modules — not exported through any public
// barrel (they're codegen hooks, not public API), imported directly here
// since this is the one place that aggregates them.
// ignore_for_file: implementation_imports
import 'package:authentication/src/di/authentication_module.module.dart';
import 'package:core/core.dart';
import 'package:core/src/di/core_module.module.dart';
import 'package:feature_about/src/di/feature_about_module.module.dart';
import 'package:feature_counseling/src/di/feature_counseling_module.module.dart';
import 'package:feature_history/src/di/feature_history_module.module.dart';
import 'package:feature_home/src/di/feature_home_module.module.dart';
import 'package:feature_onboarding/src/di/feature_onboarding_module.module.dart';
import 'package:feature_payment/src/di/feature_payment_module.module.dart';
import 'package:feature_profile/src/di/feature_profile_module.module.dart';
import 'package:injectable/injectable.dart';
import 'package:shared/shared.dart' hide configureDependencies;
import 'package:shared/src/di/shared_module.module.dart';

import 'injection.config.dart';

/// The app's real composition root (§12). `apps/mobile` is the only
/// package allowed to depend on `core`, `shared` *and* `authentication`
/// at once (§6), so it's the only place that can fold all three
/// packages' micro-package modules into one `get_it` graph.
///
/// `shared`'s own `configureDependencies` (a *different*, non-micro
/// `@InjectableInit`) stays scoped to `shared`'s own test suite — this is
/// the one every `main_<flavor>.dart` actually calls.
@InjectableInit(
  preferRelativeImports: true,
  externalPackageModulesBefore: [
    ExternalModule(CorePackageModule),
    ExternalModule(SharedPackageModule),
    ExternalModule(AuthenticationPackageModule),
    ExternalModule(FeatureHomePackageModule),
    ExternalModule(FeatureProfilePackageModule),
    ExternalModule(FeatureAboutPackageModule),
    ExternalModule(FeatureOnboardingPackageModule),
    ExternalModule(FeatureHistoryPackageModule),
    ExternalModule(FeatureCounselingPackageModule),
    ExternalModule(FeaturePaymentPackageModule),
  ],
)
Future<void> configureDependencies({required Env env}) async {
  // `shared` registers a no-op `UnauthenticatedAuthSession` as `AuthSession`
  // so it stays constructible before `authentication` exists (see
  // `auth_session.dart`); `authentication`'s `AuthSessionAdapter` registers
  // under the same interface, listed after `shared` above, specifically to
  // supersede it. Without this, the second registration would assert
  // instead of overriding the first.
  getIt.allowReassignment = true;
  getIt.registerSingleton<Env>(env);
  await getIt.init(environment: env.flavor.name);
}
