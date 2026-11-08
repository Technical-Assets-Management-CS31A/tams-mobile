import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/network/redacting_log_interceptor.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (String? msg, {int? wrapWidth}) => logs.add(msg ?? '');
  });

  tearDown(() => debugPrint = originalDebugPrint);

  test('masks password, token and Authorization header', () async {
    final dio = fakeDio(
      FakeHttpAdapter(body: {'id': 1, 'access_token': 'resp-TOKEN-xyz'}),
    )..interceptors.add(RedactingLogInterceptor());

    await dio.post(
      '/auth/login',
      data: {'email': 'me@aclc.edu.ph', 'password': 'super-SECRET-pw'},
      options: Options(headers: {'Authorization': 'Bearer hdr-TOKEN-abc'}),
    );

    final output = logs.join('\n');
    expect(output, isNot(contains('super-SECRET-pw')));
    expect(output, isNot(contains('hdr-TOKEN-abc')));
    expect(output, isNot(contains('resp-TOKEN-xyz')));
    expect(output, contains('***'));
    // Non-sensitive data is still logged.
    expect(output, contains('me@aclc.edu.ph'));
    expect(output, contains('/auth/login'));
  });

  test('masks secrets nested inside lists and maps', () async {
    final dio = fakeDio(
      FakeHttpAdapter(
        body: {
          'users': [
            {'name': 'Ana', 'refresh_token': 'nested-TOKEN-1'},
          ],
        },
      ),
    )..interceptors.add(RedactingLogInterceptor());

    await dio.get('/users');

    final output = logs.join('\n');
    expect(output, isNot(contains('nested-TOKEN-1')));
    expect(output, contains('Ana'));
  });

  test('error responses are redacted too', () async {
    final dio = fakeDio(
      FakeHttpAdapter(statusCode: 401, body: {'token': 'err-TOKEN-9'}),
    )..interceptors.add(RedactingLogInterceptor());

    await expectLater(dio.get('/me'), throwsA(isA<DioException>()));

    final output = logs.join('\n');
    expect(output, contains('ERROR 401'));
    expect(output, isNot(contains('err-TOKEN-9')));
  });
}
