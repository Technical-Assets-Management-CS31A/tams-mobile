import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import 'redacting_log_interceptor.dart';
import 'token_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        // The server rejected our token (expired or revoked). Clearing it
        // signs the user out; AuthController listens for this.
        final sentAuth = err.requestOptions.headers['Authorization'];
        final current = ref.read(authTokenProvider);
        if (err.response?.statusCode == 401 &&
            current != null &&
            sentAuth == 'Bearer $current') {
          ref.read(authTokenProvider.notifier).clear();
        }
        handler.next(err);
      },
    ),
  );

  if (kDebugMode) {
    // Masks passwords/tokens/auth headers — never log secrets.
    dio.interceptors.add(RedactingLogInterceptor());
  }

  return dio;
});