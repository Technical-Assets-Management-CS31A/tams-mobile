import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:tams_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:tams_mobile/features/auth/domain/entities/user_role.dart';

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
      expect(adapter.lastRequest!.path, '/auth/login');
      expect(adapter.lastRequest!.data, {'email': 'a@b.com', 'password': 'pw'});
    });

    test('parses the user id and role', () async {
      final adapter = FakeHttpAdapter(body: loginResponse(role: 'TECH_STAFF'));
      final user = await repoWith(adapter).login('a@b.com', 'pw');

      expect(user.id, loginUserId);
      expect(user.role, UserRole.techStaff);
    });

    test(
      'reads the id and role from the JWT when the body lacks them',
      () async {
        final token = fakeJwt(DateTime.now(), role: 'ADMIN');
        final adapter = FakeHttpAdapter(body: {'accessToken': token});
        final user = await repoWith(adapter).login('a@b.com', 'pw');

        expect(user.id, 'user-1');
        expect(user.role, UserRole.admin);
      },
    );

    test('an unknown role is unknown', () {
      expect(UserRole.fromClaim('STUDENT'), UserRole.unknown);
      expect(UserRole.fromClaim(null), UserRole.unknown);
      expect(UserRole.fromClaim('custodian'), UserRole.custodian);
      expect(UserRole.fromClaim(['TECH_STAFF']), UserRole.techStaff);
    });

    test('reads tokens at the top level of the response', () async {
      final adapter = FakeHttpAdapter(
        body: {
          'accessToken': 'jwt-2',
          'refreshToken': 'rt-2',
          'user': {'email': 'x@tams.com'},
        },
      );
      final user = await repoWith(adapter).login('x@tams.com', 'pw');

      expect(user.token, 'jwt-2');
      expect(user.refreshToken, 'rt-2');
      expect(user.email, 'x@tams.com');
    });

    test('accepts "token" and uses the typed email without a user', () async {
      final adapter = FakeHttpAdapter(body: {'token': 'jwt-3'});
      final user = await repoWith(adapter).login('typed@tams.com', 'pw');

      expect(user.token, 'jwt-3');
      expect(user.refreshToken, isNull);
      expect(user.email, 'typed@tams.com');
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

    test('HTTP 400 validation problem shows the first field error', () async {
      expect(
        await failureMessage(
          FakeHttpAdapter(
            statusCode: 400,
            body: {
              'title': 'One or more validation errors occurred.',
              'status': 400,
              'errors': {
                'email': ['Email is required.'],
              },
              'code': 'VALIDATION_FAILED',
            },
          ),
        ),
        'Email is required.',
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
