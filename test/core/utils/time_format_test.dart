import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/utils/time_format.dart';

void main() {
  final now = DateTime(2026, 11, 18, 15, 30);

  test('formatClock is 12-hour', () {
    expect(formatClock(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    expect(formatClock(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
    expect(formatClock(DateTime(2026, 1, 1, 14, 7)), '2:07 PM');
  });

  test('formatDateTime adds the year only for other years', () {
    expect(
      formatDateTime(DateTime(2026, 11, 3, 9, 0), now: now),
      '3 Nov, 9:00 AM',
    );
    expect(
      formatDateTime(DateTime(2025, 12, 31, 18, 0), now: now),
      '31 Dec 2025, 6:00 PM',
    );
  });

  test('formatAge', () {
    String age(Duration d) => formatAge(now.subtract(d), now: now);
    expect(age(const Duration(seconds: 20)), 'Just now');
    expect(age(const Duration(minutes: 5)), '5 min ago');
    expect(age(const Duration(hours: 3, minutes: 10)), '3 h ago');
    expect(
      formatAge(DateTime(2026, 11, 17, 20, 15), now: now),
      'Yesterday, 8:15 PM',
    );
    expect(
      formatAge(DateTime(2026, 11, 10, 8, 0), now: now),
      '10 Nov, 8:00 AM',
    );
  });
}
