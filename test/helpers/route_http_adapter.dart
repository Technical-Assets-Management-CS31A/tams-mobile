import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef Reply = ({int status, Object? body});

Reply ok([Object? body = const {}]) => (status: 200, body: body);

Reply problem(int status, String code, [String detail = 'Request failed.']) =>
    (status: status, body: {'status': status, 'code': code, 'detail': detail});

Never offline(RequestOptions request) => throw DioException(
  requestOptions: request,
  type: DioExceptionType.connectionError,
);

class RouteHttpAdapter implements HttpClientAdapter {
  RouteHttpAdapter(this.reply);

  FutureOr<Reply> Function(RequestOptions request) reply;
  final requests = <RequestOptions>[];

  Iterable<RequestOptions> to(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final r = await reply(options);
    final body = r.body;
    if (body is List<int>) {
      return ResponseBody.fromBytes(
        body,
        r.status,
        headers: {
          Headers.contentTypeHeader: ['application/pdf'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      r.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio routeDio(RouteHttpAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://test.local'))..httpClientAdapter = adapter;
