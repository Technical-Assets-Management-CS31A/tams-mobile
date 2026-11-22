const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "2:05 PM", in local time.
String formatClock(DateTime at) {
  final t = at.toLocal();
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "18 Nov, 2:05 PM", with the year when it isn't [now]'s.
String formatDateTime(DateTime at, {required DateTime now}) {
  final t = at.toLocal();
  final year = t.year == now.toLocal().year ? '' : ' ${t.year}';
  return '${t.day} ${_months[t.month - 1]}$year, ${formatClock(t)}';
}

/// How long ago [at] was, for a list: "Just now", "5 min ago", "3 h ago",
/// "Yesterday, 2:05 PM", then the date.
String formatAge(DateTime at, {required DateTime now}) {
  final age = now.difference(at);
  if (age < const Duration(minutes: 1)) return 'Just now';
  if (age < const Duration(hours: 1)) return '${age.inMinutes} min ago';
  final day = DateTime(now.year, now.month, now.day);
  final local = at.toLocal();
  final atDay = DateTime(local.year, local.month, local.day);
  if (atDay == day) return '${age.inHours} h ago';
  if (atDay == DateTime(now.year, now.month, now.day - 1)) {
    return 'Yesterday, ${formatClock(local)}';
  }
  return formatDateTime(local, now: now);
}

/// A countdown: "1 h 05 min" an hour or more out, "4:07" (minutes and
/// seconds) under that. Negative durations count up the same way, so the
/// caller words it ("Overdue by ...").
String formatCountdown(Duration left) {
  final d = left.abs();
  if (d >= const Duration(hours: 1)) {
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours} h $minutes min';
  }
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}
