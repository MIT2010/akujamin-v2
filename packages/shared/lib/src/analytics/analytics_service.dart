import 'package:injectable/injectable.dart';

/// Business logic calls `analyticsService.logEvent(...)` and never knows
/// which provider is live (§17, §26).
abstract class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object?>? params});
  Future<void> setUserId(String? id);
}

/// Default no-op so the app runs before a provider has been picked.
/// Later: `@Environment('prod') class FirebaseAnalyticsService implements
/// AnalyticsService {...}` swaps in without touching any call site.
@LazySingleton(as: AnalyticsService)
class NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent(String name, {Map<String, Object?>? params}) async {}

  @override
  Future<void> setUserId(String? id) async {}
}
