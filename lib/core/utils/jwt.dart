import 'dart:convert';

Map<String, Object?>? jwtClaims(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map<String, Object?> ? payload : null;
  } on FormatException {
    return null;
  }
}

/// Reads the `exp` (expiry) claim of a JWT without verifying it; the server
/// does the verifying. Returns null if [token] isn't a JWT or has no `exp`.
DateTime? jwtExpiry(String token) {
  final exp = jwtClaims(token)?['exp'];
  if (exp is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
}
