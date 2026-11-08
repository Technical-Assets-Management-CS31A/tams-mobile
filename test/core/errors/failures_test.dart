import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';

import '../../helpers/login_fixtures.dart';

void main() {
  final options = RequestOptions(path: '/x');

  Failure fromType(
    DioExceptionType type, {
    int? status,
    Object? body,
    String? rawMessage,
  }) => Failure.fromDio(
    DioException(
      requestOptions: options,
      type: type,
      message: rawMessage,
      response: status == null
          ? null
          : Response(requestOptions: options, statusCode: status, data: body),
    ),
  );

  Failure fromStatus(int status, {Object? body}) =>
      fromType(DioExceptionType.badResponse, status: status, body: body);

  group('Failure.fromDio', () {
    test('timeouts map to a timeout message', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(fromType(t).message, 'Connection timed out. Please try again.');
      }
    });

    test('connection error says the server is unreachable', () {
      expect(
        fromType(DioExceptionType.connectionError).message,
        "Can't reach the server. Check your internet connection.",
      );
    });

    test('unknown errors never show the raw Dio message', () {
      final f = fromType(
        DioExceptionType.unknown,
        rawMessage: 'SocketException: OS Error: errno = 111',
      );
      expect(f.message, 'Something went wrong. Please try again.');
    });

    test('401 means the session expired', () {
      expect(
        fromStatus(401).message,
        'Your session has expired. Please sign in again.',
      );
    });

    test('400/403/404 show the backend message (PascalCase body)', () {
      for (final status in [400, 403, 404]) {
        expect(
          fromStatus(
            status,
            body: errorResponse('Item is already borrowed.'),
          ).message,
          'Item is already borrowed.',
        );
      }
    });

    test('camelCase message is read too', () {
      expect(
        fromStatus(400, body: {'message': 'Bad input.'}).message,
        'Bad input.',
      );
    });

    test('400/403/404 without a message use a default', () {
      expect(fromStatus(400).message, 'The request was invalid.');
      expect(fromStatus(403).message, "You don't have permission to do that.");
      expect(fromStatus(404).message, 'Not found.');
      expect(fromStatus(404, body: 'html page').message, 'Not found.');
    });

    test('5xx stays generic even if the body has details', () {
      expect(
        fromStatus(
          500,
          body: errorResponse('NullReferenceException at ...'),
        ).message,
        'Server error. Please try again later.',
      );
    });

    test('other statuses include the code', () {
      expect(fromStatus(409).message, 'Request failed (409).');
    });

    test('toString returns the message', () {
      expect(const Failure('boom').toString(), 'boom');
    });
  });
}
