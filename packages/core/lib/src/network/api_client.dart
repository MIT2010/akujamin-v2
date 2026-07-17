import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../error/failure.dart';
import '../result/result.dart';

/// One Dio instance app-wide (§10). Every method converts a thrown
/// [DioException] into a typed [Failure] so nothing above the data layer
/// ever needs a try/catch (§7, §8).
///
/// Every method also catches non-`DioException` failures from [parser]
/// itself (a `TypeError`/`FormatException`/etc. from a response shape
/// the caller's model didn't expect) into [ParsingFailure] — real gap,
/// found 2026-07-16 auditing `ApiClient` after MIGRATION_LOG.md finding
/// #10: that finding's crash (`GET /auth/me`'s real envelope not
/// matching `UserProfileModel.fromJson`'s assumption) was fixed in the
/// one model, but this class itself had no general catch for it, so any
/// *other* endpoint not yet exercised against a real backend would
/// crash the exact same uncaught way the first one did.
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
    } catch (e) {
      return Err(ParsingFailure(_parsingMessage(e)));
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
    } catch (e) {
      return Err(ParsingFailure(_parsingMessage(e)));
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
    } catch (e) {
      return Err(ParsingFailure(_parsingMessage(e)));
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
    } catch (e) {
      return Err(ParsingFailure(_parsingMessage(e)));
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
    } catch (e) {
      return Err(ParsingFailure(_parsingMessage(e)));
    }
  }

  /// Keeps the exception's own description (e.g. "type 'Null' is not a
  /// subtype of type 'String' in type cast") in the `Failure.message`
  /// rather than a purely generic string — useful in logs/error reports
  /// without leaking anything server-side (unlike finding #11's raw SQL
  /// disclosure, this text originates entirely from *this app's own*
  /// Dart type-cast machinery, never from the response body itself).
  String _parsingMessage(Object e) => 'Format respons tidak sesuai: $e';

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
        UnauthorizedFailure(
          _extractMessage(e.response?.data) ?? 'Session expired',
        ),
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
