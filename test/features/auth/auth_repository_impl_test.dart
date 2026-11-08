import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/auth/data/models/datasources/auth_remote_datasource.dart';
import 'package:tams_mobile/features/auth/domain/repositories/auth_repository_impl.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  AuthRepositoryImpl repoWith(FakeHttpAdapter adapter) =>
      AuthRepositoryImpl(AuthRemoteDataSource(fakeDio(adapter)));

  Future<String> failureMessage(FakeHttpAdapter adapter) async {
    try {
      await repoWith(adapter).login('a@b.com', 'pw');
    } on Failure catch (f) {
      return f.message;
    }
    fail('Expected a Failure to be thrown');
  }

  group('AuthRepositoryImpl.login', () {
    test('returns the user on success', () async {
      final adapter = FakeHttpAdapter(body: {'id': 7});
      final user = await repoWith(adapter).login('a@b.com', 'pw');

      expect(user.email, 'a@b.com');
      expect(user.token, 'fake-token-7');
      expect(adapter.lastRequest!.data, {'email': 'a@b.com', 'password': 'pw'});
    });

    for (final status in [400, 401, 422]) {
      test('HTTP $status shows "Incorrect email or password."', () async {
        expect(
          await failureMessage(FakeHttpAdapter(statusCode: status)),
          'Incorrect email or password.',
        );
      });
    }

    test('HTTP 500 is reported as a server error', () async {
      expect(
        await failureMessage(FakeHttpAdapter(statusCode: 500)),
        'Server error (500).',
      );
    });

    test('no connection is reported as no internet', () async {
      expect(
        await failureMessage(
          FakeHttpAdapter(error: DioExceptionType.connectionError),
        ),
        'No internet connection.',
      );
    });
  });
}
