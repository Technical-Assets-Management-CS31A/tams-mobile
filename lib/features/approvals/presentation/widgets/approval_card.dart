import 'package:flutter/material.dart';

import '../../domain/entities/pending_approval.dart';
import 'countdown.dart';
import 'student_avatar.dart';

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
    final colors = Theme.of(context).colorScheme;
    // While a decision is on its way, the server's answer decides.
    final expired = request.isExpired(now) && !busy;
    final left = request.timeLeft(now);

    return Card.outlined(
      // Only for tests, to tell the two states apart.
      key: Key(expired ? 'approval-expired' : 'approval-pending'),
      clipBehavior: Clip.antiAlias,
      color: expired ? colors.surfaceContainerLow : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: request.fractionLeft(now),
            minHeight: 4,
            color: left < urgentTimeLeft ? colors.error : colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
            semanticsLabel: 'Time left to decide',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  request: request,
                  photoHeaders: photoHeaders,
                  left: expired ? Duration.zero : left,
                ),
                const SizedBox(height: 12),
                _ItemRow(request: request, expired: expired),
                if (expired) ...[
                  const SizedBox(height: 12),
                  Text(
                    'No decision in time, so the borrow was denied.',
                    style: _muted(context),
                  ),
                ],
                const SizedBox(height: 4),
                _Actions(
                  expired: expired,
                  busy: busy,
                  canApprove: canApprove,
                  onApprove: onApprove,
                  onDecline: onDecline,
                  onDismiss: onDismiss,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle? _muted(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
}

/// Photo, name, student number and section, and the countdown.
class _Header extends StatelessWidget {
  const _Header({
    required this.request,
    required this.photoHeaders,
    required this.left,
  });

  final PendingApproval request;
  final Map<String, String>? photoHeaders;
  final Duration left;

  @override
  Widget build(BuildContext context) {
    return Row(
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
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                [
                  request.studentNumber,
                  ?request.sectionCode,
                ].where((s) => s.isNotEmpty).join(' · '),
                style: _muted(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Countdown(left: left),
      ],
    );
  }
}

/// The first item being borrowed, how many more, and its asset tag.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.request, required this.expired});

  final PendingApproval request;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final more = request.items.length - 1;
    return Row(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 18,
          color: expired
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            more > 0 ? '${request.itemName} + $more more' : request.itemName,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(request.assetTag, style: _muted(context)),
      ],
    );
  }
}

/// Decline and Approve, or Dismiss once expired.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.expired,
    required this.busy,
    required this.canApprove,
    required this.onApprove,
    required this.onDecline,
    required this.onDismiss,
  });

  final bool expired;
  final bool busy;
  final bool canApprove;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      spacing: 8,
      children: expired
          ? [TextButton(onPressed: onDismiss, child: const Text('Dismiss'))]
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Approve'),
              ),
            ],
    );
  }
}
