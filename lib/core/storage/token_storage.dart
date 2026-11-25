import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _emailKey = 'auth_email';
  static const _userIdKey = 'auth_user_id';
  static const _roleKey = 'auth_role';

  final FlutterSecureStorage _storage;
  const TokenStorage(this._storage);

  Future<void> save({
    required String token,
    required String email,
    String? refreshToken,
    String? userId,
    String? role,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _emailKey, value: email);
    await _writeOrDelete(_refreshTokenKey, refreshToken);
    await _writeOrDelete(_userIdKey, userId);
    await _writeOrDelete(_roleKey, role);
  }

  Future<void> _writeOrDelete(String key, String? value) => value == null
      ? _storage.delete(key: key)
      : _storage.write(key: key, value: value);

  Future<void> saveTokens({
    required String token,
    required String refreshToken,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);
  Future<String?> readEmail() => _storage.read(key: _emailKey);
  Future<String?> readUserId() => _storage.read(key: _userIdKey);
  Future<String?> readRole() => _storage.read(key: _roleKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _roleKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const TokenStorage(FlutterSecureStorage()),
);
