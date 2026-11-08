import 'package:dio/dio.dart';

/// An error with a message that is safe to show to the user.
class Failure implements Exception {
  final String message;
  const Failure(this.message);

  factory Failure.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const Failure('Connection timed out. Please try again.');
      case DioExceptionType.connectionError:
        return const Failure(
          "Can't reach the server. Check your internet connection.",
        );
      case DioExceptionType.badCertificate:
        return const Failure("Couldn't verify the server's security.");
      case DioExceptionType.cancel:
        return const Failure('The request was cancelled.');
      case DioExceptionType.badResponse:
        return _fromStatus(e.response?.statusCode, serverMessage(e));
      case DioExceptionType.unknown:
        // Raw e.message here is technical (socket errors etc.), never show it.
        return const Failure('Something went wrong. Please try again.');
    }
  }

  static Failure _fromStatus(int? status, String? serverMessage) {
    switch (status) {
      case 400:
        return Failure(serverMessage ?? 'The request was invalid.');
      case 401:
        return const Failure('Your session has expired. Please sign in again.');
      case 403:
        return Failure(serverMessage ?? "You don't have permission to do that.");
      case 404:
        return Failure(serverMessage ?? 'Not found.');
    }
    // 5xx messages can contain internal details, so keep them generic.
    if (status != null && status >= 500) {
      return const Failure('Server error. Please try again later.');
    }
    return Failure('Request failed ($status).');
  }

  /// The `message` field of the backend's ApiResponse error body, if any.
  /// The backend's error handler writes PascalCase (`Message`), while normal
  /// responses are camelCase, so check both.
  static String? serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;
    final message = data['message'] ?? data['Message'];
    return message is String && message.trim().isNotEmpty ? message : null;
  }

  @override
  String toString() => message;
}
