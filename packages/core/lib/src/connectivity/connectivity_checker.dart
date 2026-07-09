/// Thin contract `ConnectivityInterceptor` depends on. The concrete
/// implementation (wrapping `connectivity_plus`) is a Flutter plugin, so it
/// is wired outside `core` to keep this package pure Dart.
abstract class ConnectivityChecker {
  Future<bool> get isConnected;
}
