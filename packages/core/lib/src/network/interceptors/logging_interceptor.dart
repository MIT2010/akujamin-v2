import 'dart:convert';

import 'package:dio/dio.dart';

import '../../logger/app_logger.dart';

/// Dev-only request/response logging (§10). Wire `enabled: Env.current.isDev`
/// at the composition root so this is a no-op in staging/prod builds.
///
/// **Logs full request/response bodies, 2026-07-15 — an explicit,
/// informed choice, not an oversight.** This app's traffic can include OTP
/// codes, NIK, KTP/test answers, and chat messages (MIGRATION_LOG.md
/// Permanent Finding #3) — the project owner asked for this level of
/// detail after being shown that history, specifically to see things like
/// a real `send-otp` response's `otp_code` during local dev testing. Still
/// gated by `enabled`/`Env.isDev` exactly as before, so this never fires
/// in staging/prod. One thing stays redacted even here: the
/// `Authorization` header (the session token) — leaking that is a
/// different risk (session hijack) than leaking this app's own domain
/// data, and nothing asked for it to be shown.
class LoggingInterceptor extends Interceptor {
  final AppLogger _logger;
  final bool enabled;

  LoggingInterceptor(this._logger, {this.enabled = true});

  static const _startTimeKey = 'logging_interceptor_start_time';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      options.extra[_startTimeKey] = DateTime.now();
      _logger.api(
        '--> ${options.method} ${options.uri}\n'
        '${_formatHeaders(options.headers)}'
        '${_formatBody(options.data)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      _logger.api(
        '<-- ${response.statusCode} ${response.statusMessage ?? ''} '
        '${response.requestOptions.uri} '
        '(${_durationSince(response.requestOptions)}ms)\n'
        '${_formatHeaders(response.headers.map)}'
        '${_formatBody(response.data)}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      final response = err.response;
      _logger.api(
        '<-- ERROR ${response?.statusCode ?? ''} ${err.requestOptions.uri} '
        '(${_durationSince(err.requestOptions)}ms): ${err.message}\n'
        '${response != null ? _formatBody(response.data) : ''}',
      );
    }
    handler.next(err);
  }

  int _durationSince(RequestOptions options) {
    final start = options.extra[_startTimeKey] as DateTime?;
    if (start == null) return -1;
    return DateTime.now().difference(start).inMilliseconds;
  }

  String _formatHeaders(Map<String, dynamic> headers) {
    if (headers.isEmpty) return '';
    final lines = headers.entries
        .map((e) {
          final value = e.key.toLowerCase() == 'authorization'
              ? 'Bearer ***'
              : e.value;
          return '    ${e.key}: $value';
        })
        .join('\n');
    return 'Headers:\n$lines\n';
  }

  String _formatBody(dynamic data) {
    if (data == null) return '';
    if (data is FormData) {
      final fields = data.fields
          .map((e) => '    ${e.key}: ${e.value}')
          .join('\n');
      final files = data.files
          .map(
            (e) =>
                '    ${e.key}: <file ${e.value.filename}, '
                '${e.value.length} bytes>',
          )
          .join('\n');
      final parts = [
        if (fields.isNotEmpty) fields,
        if (files.isNotEmpty) files,
      ].join('\n');
      return 'Body (multipart):\n$parts\n';
    }

    var toEncode = data;
    if (data is String) {
      try {
        toEncode = jsonDecode(data);
      } catch (_) {
        return 'Body: $data\n';
      }
    }
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(toEncode);
      return 'Body:\n$pretty\n';
    } catch (_) {
      return 'Body: $data\n';
    }
  }
}
