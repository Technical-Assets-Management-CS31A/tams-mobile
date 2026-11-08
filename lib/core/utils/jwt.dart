import 'dart:convert';

/// Reads the `exp` (expiry) claim of a JWT without verifying it; the server
/// does the verifying. Returns null if [token] isn't a JWT or has no `exp`.
DateTime? jwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
  } on FormatException {
    return null;
  }
}
