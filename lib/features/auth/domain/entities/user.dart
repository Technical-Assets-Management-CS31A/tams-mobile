import 'user_role.dart';

class User {
  final String email;

  /// JWT access token, sent as `Authorization: Bearer <token>`.
  final String token;

  /// Used to get a new access token once [token] expires.
  final String? refreshToken;

  final String? id;
  final UserRole role;

  const User({
    required this.email,
    required this.token,
    this.refreshToken,
    this.id,
    this.role = UserRole.unknown,
  });

  User withToken(String token) => User(
    email: email,
    token: token,
    refreshToken: refreshToken,
    id: id,
    role: role,
  );
}
