import 'package:dio/dio.dart';

import '../../connectivity/connectivity_checker.dart';
import '../../error/failure.dart';

/// Fails fast with [NetworkFailure] when offline, instead of letting the
/// request run into a dead 30s connection timeout (§10).
class ConnectivityInterceptor extends Interceptor {
  final ConnectivityChecker _connectivityChecker;

  ConnectivityInterceptor(this._connectivityChecker);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final connected = await _connectivityChecker.isConnected;
    if (!connected) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const NetworkFailure(),
        ),
      );
    }
    handler.next(options);
  }
}
