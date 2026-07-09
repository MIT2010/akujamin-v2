import 'package:go_router/go_router.dart';

/// Lets a feature package contribute its own [RouteBase]s to [AppRouter]
/// without `shared` ever importing a feature (§17: "feature_home
/// contributes its own GoRoute objects instead of shared knowing about
/// home's screens").
///
/// Every feature registers an implementation via
/// `@Injectable(as: FeatureRoutes)`; `get_it` resolves all of them for
/// `AppRouter` as `List<FeatureRoutes>` (many-implementations-of-one-
/// interface, no changes needed here as features are added later).
abstract class FeatureRoutes {
  List<RouteBase> get routes;
}
