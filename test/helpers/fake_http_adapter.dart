import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Replaces Dio's network layer so tests never hit a real server.
/// Returns [statusCode]/[body], or throws [error] if one is given.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter({this.statusCode = 200, this.body = const {}, this.error});

  final int statusCode;
  final Object body;
  final DioExceptionType? error;

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
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeHttpAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://test.local'))..httpClientAdapter = adapter;
