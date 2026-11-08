class User {
  final String email;

  /// JWT access token, sent as `Authorization: Bearer <token>`.
  final String token;

  /// Used to get a new access token once [token] expires.
  final String? refreshToken;

  const User({required this.email, required this.token, this.refreshToken});
}
