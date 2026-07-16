import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

/// Named channels keep `flutter run`'s console filterable by concern.
enum LogChannel { api, bloc, nav, repo }

/// Thin wrapper around the `logger` package (§10).
///
/// **Switched from `dart:developer.log`, 2026-07-15** — found while
/// debugging why `LoggingInterceptor`'s request/response lines never
/// showed up during a real web run: `dart:developer.log` is never relayed
/// to the `flutter run` terminal on the web platform (native platforms'
/// terminal picks it up via the VM service; web has no such relay, the
/// call effectively goes nowhere the terminal can see). `logger`'s default
/// output (`ConsoleOutput`) ultimately calls `print()`, which Flutter's
/// tooling *does* relay to the terminal on every platform, web included —
/// this is what actually fixes the visibility gap, not just a cosmetic
/// swap. Uses `PrettyPrinter` (boxed, multi-line, colored) rather than a
/// bare one-liner specifically so app-emitted log lines are visually
/// unmistakable against Flutter's own framework/debug console noise —
/// the whole point of a named-channel logger is lost if its output looks
/// like everything else scrolling past it.
@lazySingleton
class AppLogger {
  AppLogger() : _logger = Logger(printer: PrettyPrinter(colors: true));

  final Logger _logger;

  void d(String message, {LogChannel channel = LogChannel.repo}) =>
      _logger.d(_prefixed(channel, message));

  void i(String message, {LogChannel channel = LogChannel.repo}) =>
      _logger.i(_prefixed(channel, message));

  void w(String message, {LogChannel channel = LogChannel.repo}) =>
      _logger.w(_prefixed(channel, message));

  void e(
    String message, {
    LogChannel channel = LogChannel.repo,
    Object? error,
    StackTrace? stackTrace,
  }) => _logger.e(
    _prefixed(channel, message),
    error: error,
    stackTrace: stackTrace,
  );

  /// Convenience shortcut used by [LoggingInterceptor].
  void api(String message) => i(message, channel: LogChannel.api);

  String _prefixed(LogChannel channel, String message) =>
      '[app.${channel.name}] $message';
}
