import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';

void main() {
  final options = RequestOptions(path: '/x');

  Failure fromType(DioExceptionType type, {int? status}) => Failure.fromDio(
    DioException(
      requestOptions: options,
      type: type,
      response: status == null
          ? null
          : Response(requestOptions: options, statusCode: status),
    ),
  );

  group('Failure.fromDio', () {
    test('timeouts map to a timeout message', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          fromType(t).message,
          'Connection timed out. Please try again.',
        );
      }
    });

    test('connection error maps to no internet', () {
      expect(
        fromType(DioExceptionType.connectionError).message,
        'No internet connection.',
      );
    });

    test('bad response includes the status code', () {
      expect(
        fromType(DioExceptionType.badResponse, status: 500).message,
        'Server error (500).',
      );
    });

    test('toString returns the message', () {
      expect(const Failure('boom').toString(), 'boom');
    });
  });
}
