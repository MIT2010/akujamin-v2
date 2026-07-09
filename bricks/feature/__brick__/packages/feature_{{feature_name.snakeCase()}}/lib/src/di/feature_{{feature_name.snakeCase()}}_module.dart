import 'package:injectable/injectable.dart';

/// Marks `feature_{{feature_name.snakeCase()}}` as an injectable "micro
/// package" (§12), same pattern as every other package here. After
/// `melos run gen`, wire the generated
/// `Feature{{feature_name.pascalCase()}}PackageModule` into
/// `apps/mobile/lib/src/di/injection.dart` manually — the composition
/// root is the one place that aggregates every feature's module.
@InjectableInit.microPackage()
void configureFeature{{feature_name.pascalCase()}}Module() {}
