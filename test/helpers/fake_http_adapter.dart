import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Replaces Dio's network layer so tests never hit a real server.
/// Returns [statusCode]/[body], or throws [error] if one is given.
/// Fields are mutable so a test can change the next response.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter({this.statusCode = 200, this.body = const {}, this.error});

  int statusCode;
  Object body;
  DioExceptionType? error;

  /// Extra response headers, e.g. `{'date': ['Wed, 18 Nov 2026 ...']}`.
  Map<String, List<String>> headers = {};

  /// Last request seen, so tests can inspect what was sent.
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (error != null) {
      throw DioException(requestOptions: options, type: error!);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeHttpAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://test.local'))..httpClientAdapter = adapter;
