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

  test('out-of-range fields are null, not rolled over', () {
    expect(parseHttpDate('Wed, 32 Nov 2026 08:49:37 GMT'), isNull);
    expect(parseHttpDate('Mon, 31 Nov 2026 08:49:37 GMT'), isNull);
    expect(parseHttpDate('Sun, 29 Feb 2026 08:49:37 GMT'), isNull);
    expect(parseHttpDate('Wed, 00 Nov 2026 08:49:37 GMT'), isNull);
    expect(parseHttpDate('Wed, 18 Nov 2026 24:00:00 GMT'), isNull);
    expect(parseHttpDate('Wed, 32 Nov 2026 25:61:00 GMT'), isNull);
    expect(parseHttpDate('Wed, 18 Nov 2026 08:60:00 GMT'), isNull);
    expect(parseHttpDate('Wed, 18 Nov 2026 08:49:61 GMT'), isNull);
  });

  test('edge values that are valid', () {
    expect(
      parseHttpDate('Tue, 29 Feb 2028 23:59:59 GMT'),
      DateTime.utc(2028, 2, 29, 23, 59, 59),
    );
    // A leap second is clamped, not rolled into the next minute.
    expect(
      parseHttpDate('Sat, 31 Dec 2016 23:59:60 GMT'),
      DateTime.utc(2016, 12, 31, 23, 59, 59),
    );
  });
}
