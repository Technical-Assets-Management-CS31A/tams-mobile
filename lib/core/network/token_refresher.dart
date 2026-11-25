import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import 'token_provider.dart';

const skipAuthKey = 'skipAuth';
const retriedKey = 'authRetried';

class TokenRefresher {
  TokenRefresher(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;
  Future<String?>? _running;

  Future<String?> renew(String expired) =>
      _running ??= _renew(expired).whenComplete(() => _running = null);

  Future<String?> _renew(String expired) async {
    final storage = _ref.read(tokenStorageProvider);
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null) return null;

    final Response<Object?> res;
    try {
      res = await _dio.post<Object?>(
        ApiConstants.refreshPath,
        data: {'refreshToken': refreshToken},
        options: Options(extra: {skipAuthKey: true}),
      );
    } on DioException catch (e) {
      if (_rejected(e.response?.statusCode)) return null;
      rethrow;
    }

    final tokens = _tokens(res.data);
    if (tokens == null) return null;
    if (_ref.read(authTokenProvider) != expired) {
      return _ref.read(authTokenProvider);
    }
    await storage.saveTokens(token: tokens.$1, refreshToken: tokens.$2);
    _ref.read(authTokenProvider.notifier).set(tokens.$1);
    return tokens.$1;
  }

  static bool _rejected(int? status) =>
      status == 400 || status == 401 || status == 403;

  static (String, String)? _tokens(Object? body) {
    if (body is! Map) return null;
    final data = body['data'] is Map ? body['data'] as Map : body;
    final access = data['accessToken'] ?? data['token'];
    final refresh = data['refreshToken'];
    if (access is! String || access.isEmpty) return null;
    if (refresh is! String || refresh.isEmpty) return null;
    return (access, refresh);
  }
}
