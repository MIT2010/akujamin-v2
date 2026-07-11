import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

/// §19 — deliberately bypasses `core`'s `ApiClient`: `ApiClient.get<T>`
/// forces Dio's default JSON response handling and a `T Function(dynamic
/// json) parser`, neither of which fits downloading a PDF's raw bytes.
/// Injects the same singleton `Dio` `ApiClient` itself wraps (registered
/// in `shared`'s `RegisterModule`) — so the same interceptors (logging,
/// eventually auth/retry/connectivity) still apply — just calls it
/// directly with `responseType: ResponseType.bytes` for this one need.
///
/// `certificateUrl` (from `TestHistoryItem`) is a full absolute URL, not a
/// relative API path — Dio's `get()` already handles an absolute URL
/// overriding `baseUrl` on its own, no special-casing needed here.
@injectable
class CertificateRemoteDataSource {
  final Dio _dio;
  CertificateRemoteDataSource(this._dio);

  Future<Result<Failure, Uint8List>> download(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return Ok(Uint8List.fromList(response.data ?? const []));
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        return const Err(NetworkFailure());
      }
      return Err(
        ServerFailure(
          'Gagal memuat sertifikat',
          statusCode: e.response?.statusCode,
        ),
      );
    }
  }
}
