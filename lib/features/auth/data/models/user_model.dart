import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.email,
    required super.token,
    super.refreshToken,
  });

  /// Parses the body of `POST /auth/login-mobile`:
  /// `{success, message, data: {user: {email, username, ...}, accessToken, refreshToken}}`
  ///
  /// Throws [FormatException] if the body doesn't have that shape.
  factory UserModel.fromLoginResponse(Object? body) {
    final data = body is Map ? body['data'] : null;
    if (data is! Map) {
      throw const FormatException('Login response has no "data" object.');
    }

    final token = data['accessToken'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Login response has no access token.');
    }

    final refreshToken = data['refreshToken'];
    final user = data['user'];
    // Email can be "" on the backend; fall back to the username.
    final email = user is Map ? user['email'] : null;
    final username = user is Map ? user['username'] : null;

    return UserModel(
      email: email is String && email.isNotEmpty
          ? email
          : (username is String ? username : ''),
      token: token,
      refreshToken: refreshToken is String ? refreshToken : null,
    );
  }
}
