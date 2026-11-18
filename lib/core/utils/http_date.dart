const _months = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, //
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

final _imfFixdate = RegExp(
  r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
);

/// Parses an HTTP `Date` header (`Wed, 18 Nov 2026 08:49:37 GMT`, the only
/// format RFC 9110 lets servers send). Returns null for anything else.
///
/// `dart:io`'s `HttpDate` does this too, but isn't available on the web.
DateTime? parseHttpDate(String? value) {
  final m = _imfFixdate.firstMatch(value?.trim() ?? '');
  if (m == null) return null;
  final month = _months[m[2]];
  if (month == null) return null;
  return DateTime.utc(
    int.parse(m[3]!),
    month,
    int.parse(m[1]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
    int.parse(m[6]!),
  );
}
