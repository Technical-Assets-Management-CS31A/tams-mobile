import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/utils/http_date.dart';

void main() {
  test('parses an IMF-fixdate', () {
    expect(
      parseHttpDate('Wed, 18 Nov 2026 08:49:37 GMT'),
      DateTime.utc(2026, 11, 18, 8, 49, 37),
    );
    expect(
      parseHttpDate(' Sun, 06 Jan 2030 00:00:00 GMT '),
      DateTime.utc(2030, 1, 6),
    );
  });

  test('anything else is null', () {
    expect(parseHttpDate(null), isNull);
    expect(parseHttpDate(''), isNull);
    expect(parseHttpDate('2026-11-18T08:49:37Z'), isNull);
    expect(parseHttpDate('Wed, 18 Foo 2026 08:49:37 GMT'), isNull);
    expect(parseHttpDate('Wednesday, 18-Nov-26 08:49:37 GMT'), isNull);
  });
}
