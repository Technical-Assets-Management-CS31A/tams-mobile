import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:tams_mobile/features/auth/data/repositories/auth_repository_impl.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/login_fixtures.dart';

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
    test('parses the user and tokens from the response', () async {
      final adapter = FakeHttpAdapter(
        body: loginResponse(accessToken: 'jwt-1', refreshToken: 'rt-1'),
      );
      final user = await repoWith(adapter).login('a@b.com', 'pw');

      expect(user.email, 'a@b.com');
      expect(user.token, 'jwt-1');
      expect(user.refreshToken, 'rt-1');
      expect(adapter.lastRequest!.path, '/auth/login-mobile');
      expect(adapter.lastRequest!.data, {
        'identifier': 'a@b.com',
        'password': 'pw',
      });
    });

    test('falls back to the username when the email is empty', () async {
      final adapter = FakeHttpAdapter(
        body: loginResponse(email: '', username: 'juan'),
      );
      final user = await repoWith(adapter).login('juan', 'pw');

      expect(user.email, 'juan');
    });

    for (final body in <Object>[
      {},
      {'success': true, 'data': null},
      {
        'success': true,
        'data': {'user': {}},
      },
      ['not', 'a', 'map'],
    ]) {
      test('unexpected body $body is a readable failure', () async {
        expect(
          await failureMessage(FakeHttpAdapter(body: body)),
          'Unexpected response from the server.',
        );
      });
    }

    test('HTTP 401 shows "Incorrect email or password."', () async {
      expect(
        await failureMessage(
          FakeHttpAdapter(
            statusCode: 401,
            body: errorResponse('Invalid username or password.'),
          ),
        ),
        'Incorrect email or password.',
      );
    });

    test('HTTP 403 shows the backend\'s blocked-account message', () async {
      const msg = 'Your account has been permanently blocked. Reason: test';
      expect(
        await failureMessage(
          FakeHttpAdapter(statusCode: 403, body: errorResponse(msg)),
        ),
        msg,
      );
    });

    test('HTTP 403 without a message still explains the block', () async {
      expect(
        await failureMessage(FakeHttpAdapter(statusCode: 403)),
        'Your account is blocked. Please contact an administrator.',
      );
    });

    test('HTTP 400 shows the backend message', () async {
      expect(
        await failureMessage(
          FakeHttpAdapter(statusCode: 400, body: errorResponse('Bad input.')),
        ),
        'Bad input.',
      );
    });

    test('HTTP 500 is reported as a server error', () async {
      expect(
        await failureMessage(FakeHttpAdapter(statusCode: 500)),
        'Server error. Please try again later.',
      );
    });

    test('no connection says the server is unreachable', () async {
      expect(
        await failureMessage(
          FakeHttpAdapter(error: DioExceptionType.connectionError),
        ),
        "Can't reach the server. Check your internet connection.",
      );
    });
  });
}
