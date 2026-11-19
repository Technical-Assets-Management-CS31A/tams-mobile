import 'package:flutter/material.dart';

/// Under this much time left the countdown turns red.
const urgentTimeLeft = Duration(seconds: 30);

/// "1:42 left" with a timer icon, red when urgent, or "Expired".
class Countdown extends StatelessWidget {
  const Countdown({super.key, required this.left});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final expired = left <= Duration.zero;
    final color = expired || left < urgentTimeLeft
        ? colors.error
        : colors.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          expired ? Icons.timer_off_outlined : Icons.timer_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          formatTimeLeft(left),
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// "2:00 left", "0:05 left", "Expired". Rounds up, so the last second
/// shows "0:01 left" rather than "0:00 left".
String formatTimeLeft(Duration left) {
  if (left <= Duration.zero) return 'Expired';
  final seconds = (left.inMilliseconds + 999) ~/ 1000;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '${seconds ~/ 60}:$s left';
}
