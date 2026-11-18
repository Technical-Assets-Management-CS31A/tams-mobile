import 'package:flutter/material.dart';

import '../../domain/entities/pending_approval.dart';
import 'student_avatar.dart';

/// One pending request: who is asking, for what, time left, and
/// Approve/Decline.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
    required this.request,
    required this.now,
    required this.onApprove,
    required this.onDecline,
    this.photoHeaders,
    this.busy = false,
    this.canApprove = true,
  });

  final PendingApproval request;

  /// Used for the countdown. Passed in so the whole list agrees on the time.
  final DateTime now;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final Map<String, String>? photoHeaders;

  /// A decision is being sent; the buttons are disabled meanwhile.
  final bool busy;

  /// False while the instructor's approval rights are frozen (FR-2.3).
  final bool canApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final left = request.expiresAt.difference(now);
    final urgent = left < const Duration(seconds: 30);
    final more = request.items.length - 1;

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                Text(
                  timeLeft(left),
                  style: muted?.copyWith(
                    color: urgent ? theme.colorScheme.error : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
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
            const SizedBox(height: 4),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy ? null : onDecline,
                  child: const Text('Decline'),
                ),
                FilledButton.tonal(
                  onPressed: busy || !canApprove ? null : onApprove,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "1:42 left", "0:05 left", "Expired".
String timeLeft(Duration left) {
  if (left <= Duration.zero) return 'Expired';
  final seconds = left.inSeconds;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '${seconds ~/ 60}:$s left';
}
