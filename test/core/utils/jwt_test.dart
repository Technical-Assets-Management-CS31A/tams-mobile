import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/utils/jwt.dart';

import '../../helpers/login_fixtures.dart';

void main() {
  test('reads the exp claim', () {
    final exp = DateTime.utc(2030, 1, 2, 3, 4, 5);
    expect(jwtExpiry(fakeJwt(exp)), exp);
  });

  test('returns null for things that are not JWTs', () {
    expect(jwtExpiry('not-a-jwt'), isNull);
    expect(jwtExpiry('a.b.c'), isNull);
    expect(jwtExpiry(''), isNull);
  });
}
