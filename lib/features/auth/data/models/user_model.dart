import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.email,
    required super.token,
    super.refreshToken,
  });

  /// Parses the body of `POST /auth/login`. The tokens can sit at the top
  /// level (`{accessToken, refreshToken, user}`) or inside an ApiResponse
  /// wrapper (`{success, message, data: {accessToken, refreshToken, user}}`).
  /// The access token may also be called `token`.
  ///
  /// The email comes from `user.email`, then `user.username`, then
  /// [fallbackEmail] (what the user typed).
  ///
  /// Throws [FormatException] if there is no access token.
  factory UserModel.fromLoginResponse(
    Object? body, {
    String fallbackEmail = '',
  }) {
    if (body is! Map) {
      throw const FormatException('Login response is not an object.');
    }
    final wrapped = body['data'];
    final data = wrapped is Map ? wrapped : body;

    final token = _string(data['accessToken']) ?? _string(data['token']);
    if (token == null) {
      throw const FormatException('Login response has no access token.');
    }

    final user = data['user'];
    final email =
        (user is Map
            ? _string(user['email']) ?? _string(user['username'])
            : null) ??
        _string(data['email']) ??
        fallbackEmail;

    return UserModel(
      email: email,
      token: token,
      refreshToken: _string(data['refreshToken']),
    );
  }

  static String? _string(Object? value) =>
      value is String && value.isNotEmpty ? value : null;
}
