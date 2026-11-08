import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only HTTP logger that masks secrets (passwords, tokens, auth
/// headers, cookies) in headers and request/response bodies.
class RedactingLogInterceptor extends Interceptor {
  static const _mask = '***';

  static bool _isSensitive(String key) {
    final k = key.toLowerCase();
    return k.contains('password') ||
        k.contains('token') ||
        k.contains('secret') ||
        k == 'authorization' ||
        k == 'cookie' ||
        k == 'set-cookie';
  }

  /// Redacts a whole request/response body.
  static Object? _redactBody(Object? data) {
    if (data is FormData) {
      return {
        for (final f in data.fields)
          f.key: _isSensitive(f.key) ? _mask : f.value,
        for (final f in data.files) f.key: '<file ${f.value.filename}>',
      };
    }
    if (data is String) {
      // A raw string body may be JSON; never print unparseable text as-is.
      try {
        return _redact(jsonDecode(data));
      } catch (_) {
        return '<non-JSON body, ${data.length} chars>';
      }
    }
    return _redact(data);
  }

  /// Redacts sensitive keys inside decoded JSON (maps/lists, any depth).
  static Object? _redact(Object? data) {
    if (data is Map) {
      return {
        for (final e in data.entries)
          e.key: _isSensitive('${e.key}') ? _mask : _redact(e.value),
      };
    }
    if (data is List) return data.map(_redact).toList();
    return data;
  }

  static Map<String, Object?> _headers(Map<String, dynamic> headers) => {
    for (final e in headers.entries)
      e.key: _isSensitive(e.key) ? _mask : e.value,
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('--> ${options.method} ${options.uri}');
    debugPrint('    headers: ${_headers(options.headers)}');
    if (options.data != null) {
      debugPrint('    body: ${_redactBody(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('<-- ${response.statusCode} ${response.requestOptions.uri}');
    if (response.data != null) {
      debugPrint('    body: ${_redactBody(response.data)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '<-- ERROR ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.uri}',
    );
    if (err.response?.data != null) {
      debugPrint('    body: ${_redactBody(err.response!.data)}');
    }
    handler.next(err);
  }
}
