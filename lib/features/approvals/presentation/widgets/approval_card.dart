import 'package:flutter/material.dart';

import '../../domain/entities/pending_approval.dart';
import 'student_avatar.dart';

/// Under this much time left the countdown turns red.
const urgentTimeLeft = Duration(seconds: 30);

/// One pending request: who is asking, for what, time left before the
/// 120 s approval timeout (PRD 4.1), and Approve/Decline.
///
/// Once the time runs out the card switches to an expired state: the kiosk
/// has denied the borrow, so the only action left is Dismiss.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
    required this.request,
    required this.now,
    required this.onApprove,
    required this.onDecline,
    required this.onDismiss,
    this.photoHeaders,
    this.busy = false,
    this.canApprove = true,
  });

  final PendingApproval request;

  /// Used for the countdown. Passed in so the whole list agrees on the time.
  final DateTime now;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  /// Takes an expired request off the list.
  final VoidCallback onDismiss;
  final Map<String, String>? photoHeaders;

  /// A decision is being sent; the buttons are disabled meanwhile.
  final bool busy;

  /// False while the instructor's approval rights are frozen (FR-2.3).
  final bool canApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    // While a decision is on its way, the server's answer decides.
    final expired = request.isExpired(now) && !busy;
    final left = request.timeLeft(now);
    final urgent = left < urgentTimeLeft;
    final more = request.items.length - 1;

    return Card.outlined(
      key: Key(expired ? 'approval-expired' : 'approval-pending'),
      clipBehavior: Clip.antiAlias,
      color: expired ? colors.surfaceContainerLow : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: request.fractionLeft(now),
            minHeight: 4,
            color: urgent ? colors.error : colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
            semanticsLabel: 'Time left to decide',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StudentAvatar(
                      name: request.studentName,
                      photoUrl: request.photoUrl,
                      headers: photoHeaders,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.studentName,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            [
                              request.studentNumber,
                              ?request.sectionCode,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Countdown(left: expired ? Duration.zero : left),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: expired ? colors.onSurfaceVariant : colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        more > 0
                            ? '${request.itemName} + $more more'
                            : request.itemName,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(request.assetTag, style: muted),
                  ],
                ),
                if (expired) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No decision in time, so the borrow was denied.',
                    style: muted,
                  ),
                ],
                const SizedBox(height: 4),
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: expired
                      ? [
                          TextButton(
                            onPressed: onDismiss,
                            child: const Text('Dismiss'),
                          ),
                        ]
                      : [
                          TextButton(
                            onPressed: busy ? null : onDecline,
                            child: const Text('Decline'),
                          ),
                          FilledButton.tonal(
                            onPressed: busy || !canApprove ? null : onApprove,
                            child: busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Approve'),
                          ),
                        ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          timeLeft(left),
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
String timeLeft(Duration left) {
  if (left <= Duration.zero) return 'Expired';
  final seconds = (left.inMilliseconds + 999) ~/ 1000;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '${seconds ~/ 60}:$s left';
}
