const _months = {
  'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6, //
  'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
};

final _imfFixdate = RegExp(
  r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
);

/// Parses an HTTP `Date` header (`Wed, 18 Nov 2026 08:49:37 GMT`, the only
/// format RFC 9110 lets servers send). Returns null for anything else.
DateTime? parseHttpDate(String? value) {
  final m = _imfFixdate.firstMatch(value?.trim() ?? '');
  if (m == null) return null;
  final month = _months[m[2]];
  if (month == null) return null;
  final year = int.parse(m[3]!);
  final day = int.parse(m[1]!);
  final hour = int.parse(m[4]!);
  final minute = int.parse(m[5]!);
  final second = int.parse(m[6]!);
  // DateTime.utc would roll "32 Nov 25:61" over into a later date.
  // RFC 9110 allows second 60 (a leap second); treat it as 59.
  if (day < 1 || day > _daysIn(year, month)) return null;
  if (hour > 23 || minute > 59 || second > 60) return null;
  return DateTime.utc(year, month, day, hour, minute, second.clamp(0, 59));
}

int _daysIn(int year, int month) =>
    // Day 0 of the next month is the last day of this one.
    DateTime.utc(year, month + 1, 0).day;
