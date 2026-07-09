import 'package:injectable/injectable.dart';

/// Wired once in `main.dart` (§27):
/// ```dart
/// FlutterError.onError = (details) => getIt<CrashReporter>().recordError(
///       details.exception, details.stack ?? StackTrace.empty, fatal: true,
///     );
/// ```
abstract class CrashReporter {
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  });
  Future<void> setUserId(String? id);
}

/// Same swap-later pattern as [AnalyticsService]: a `NoopCrashReporter` in
/// dev, `FirebaseCrashlyticsReporter` behind `@Environment('prod')` later.
@LazySingleton(as: CrashReporter)
class NoopCrashReporter implements CrashReporter {
  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {}

  @override
  Future<void> setUserId(String? id) async {}
}
