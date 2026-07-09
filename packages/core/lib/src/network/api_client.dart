import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../error/failure.dart';
import '../result/result.dart';

/// One Dio instance app-wide (§10). Every method converts a thrown
/// [DioException] into a typed [Failure] so nothing above the data layer
/// ever needs a try/catch (§7, §8).
@lazySingleton
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Future<Result<Failure, T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic json) parser,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: query);
      return Ok(parser(response.data));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    }
  }

  Future<Result<Failure, T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    required T Function(dynamic json) parser,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: query,
      );
      return Ok(parser(response.data));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    }
  }

  Future<Result<Failure, T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    required T Function(dynamic json) parser,
  }) async {
    try {
      final response = await _dio.put(path, data: data, queryParameters: query);
      return Ok(parser(response.data));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    }
  }

  Future<Result<Failure, T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? query,
    required T Function(dynamic json) parser,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: query,
      );
      return Ok(parser(response.data));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    }
  }

  Future<Result<Failure, T>> multipart<T>(
    String path, {
    required FormData data,
    required T Function(dynamic json) parser,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        onSendProgress: onSendProgress,
      );
      return Ok(parser(response.data));
    } on DioException catch (e) {
      return Err(_mapDioError(e));
    }
  }

  Failure _mapDioError(DioException e) {
    // Interceptors (e.g. ConnectivityInterceptor) may already attach a
    // typed Failure to the exception — prefer that over re-deriving one.
    final attached = e.error;
    if (attached is Failure) return attached;

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => const NetworkFailure(),
      DioExceptionType.badResponse when e.response?.statusCode == 401 =>
        const UnauthorizedFailure(),
      DioExceptionType.badResponse => ServerFailure(
        _extractMessage(e.response?.data) ?? 'Server error',
        statusCode: e.response?.statusCode,
      ),
      _ => const NetworkFailure(),
    };
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
