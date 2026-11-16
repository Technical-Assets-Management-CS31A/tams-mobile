import 'package:flutter/material.dart';

import '../../domain/entities/pending_approval.dart';
import 'student_avatar.dart';

/// One pending request: who is asking, for what, and Approve/Reject.
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
    required this.request,
    required this.now,
    required this.onApprove,
    required this.onReject,
  });

  final PendingApproval request;

  /// Used for "4 min ago". Passed in so the whole list agrees on the time.
  final DateTime now;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

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
                      Text(request.studentNumber, style: muted),
                    ],
                  ),
                ),
                Text(timeAgo(request.requestedAt, now), style: muted),
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
                    request.itemName,
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
                TextButton(onPressed: onReject, child: const Text('Reject')),
                FilledButton.tonal(
                  onPressed: onApprove,
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Just now", "4 min ago", "1 h ago", "2 d ago".
String timeAgo(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
