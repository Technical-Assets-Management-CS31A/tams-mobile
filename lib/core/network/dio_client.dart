import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import 'redacting_log_interceptor.dart';
import 'token_provider.dart';
import 'token_refresher.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    ),
  );
  final refresher = TokenRefresher(ref, dio);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authTokenProvider);
        if (token != null && options.extra[skipAuthKey] != true) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        final options = err.requestOptions;
        final current = ref.read(authTokenProvider);
        if (err.response?.statusCode != 401 ||
            current == null ||
            options.extra[skipAuthKey] == true ||
            options.extra[retriedKey] == true) {
          return handler.next(err);
        }

        final header = options.headers['Authorization'];
        if (header != 'Bearer $current') {
          // Sent with an older token, or none.
          final sent = header is String && header.startsWith('Bearer ')
              ? header.substring('Bearer '.length)
              : null;
          if (refresher.renewedFrom(sent) == null) return handler.next(err);
        } else {
          String? token;
          try {
            token = await refresher.renew(current);
          } on DioException {
            return handler.next(err);
          } catch (e) {
            debugPrint('Could not renew the session: $e');
          }
          if (token == null) {
            if (ref.read(authTokenProvider) == current) {
              ref.read(authTokenProvider.notifier).clear();
            }
            return handler.next(err);
          }
        }

        options.extra[retriedKey] = true;
        try {
          handler.resolve(await dio.fetch<Object?>(options));
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ),
  );

  if (kDebugMode) {
    // Masks passwords/tokens/auth headers — never log secrets.
    dio.interceptors.add(RedactingLogInterceptor());
  }

  return dio;
});
