import 'dart:developer' as developer;

import 'package:injectable/injectable.dart';

/// Named channels keep `flutter run`'s console filterable by concern.
enum LogChannel { api, bloc, nav, repo }

/// Thin wrapper around `dart:developer`'s logger — no external logging
/// package needed, keeps `core` dependency-free for something this small.
@lazySingleton
class AppLogger {
  const AppLogger();

  void d(String message, {LogChannel channel = LogChannel.repo}) =>
      _log(message, channel, level: 500);

  void i(String message, {LogChannel channel = LogChannel.repo}) =>
      _log(message, channel, level: 800);

  void w(String message, {LogChannel channel = LogChannel.repo}) =>
      _log(message, channel, level: 900);

  void e(
    String message, {
    LogChannel channel = LogChannel.repo,
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(message, channel, level: 1000, error: error, stackTrace: stackTrace);

  /// Convenience shortcut used by [LoggingInterceptor].
  void api(String message) => i(message, channel: LogChannel.api);

  void _log(
    String message,
    LogChannel channel, {
    required int level,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'app.${channel.name}',
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
