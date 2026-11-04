import 'package:dio/dio.dart';

class Failure implements Exception {
  final String message;
  const Failure(this.message);

  factory Failure.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const Failure('Connection timed out. Please try again.');
      case DioExceptionType.connectionError:
        return const Failure('No internet connection.');
      case DioExceptionType.badResponse:
        return Failure('Server error (${e.response?.statusCode}).');
      default:
        return Failure(e.message ?? 'Something went wrong.');
    }
  }

  @override
  String toString() => message;
}