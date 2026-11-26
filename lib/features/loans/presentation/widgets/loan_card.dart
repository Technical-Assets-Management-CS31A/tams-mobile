import 'package:flutter/material.dart';

import '../../../../core/utils/time_format.dart';
import '../../domain/entities/loan_detail.dart';

/// A row of My Loans or Loan History: the item, who has it and where, its
/// live status, and the countdown to when it is due back (grace included).
/// A closed loan says when it ended instead.
class LoanCard extends StatelessWidget {
  const LoanCard({
    super.key,
    required this.loan,
    required this.now,
    this.onTap,
  });

  final LoanDetail loan;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = loan.liveStatus(now);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final who = [
      loan.assetCode,
      if (loan.borrower case final b?)
        loan.sectionCode == null ? b : '$b (${loan.sectionCode})',
    ].where((s) => s.isNotEmpty).join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.assetName.isEmpty ? loan.loanNo : loan.assetName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (who.isNotEmpty) Text(who, style: muted),
                        if (loan.room case final room?)
                          Text(room, style: muted),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  LiveStatusChip(status: status),
                ],
              ),
              if (_countdown(context, status) case final countdown?) ...[
                const SizedBox(height: 12),
                countdown,
              ],
              if (_transit(context, status) case final transit?) ...[
                const SizedBox(height: 8),
                transit,
              ],
              if (_ended(context) case final ended?) ...[
                const SizedBox(height: 12),
                ended,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// "Due in 1 h 05 min", or "Overdue by 12:04" once past due.
  Widget? _countdown(BuildContext context, LoanLiveStatus status) {
    final due = loan.dueAt;
    final left = loan.dueIn(now);
    if (!loan.isOpen || due == null || left == null) return null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final overdue = status == LoanLiveStatus.overdue;
    // Under 15 minutes left: time to remind the class.
    final soon = !overdue && left < const Duration(minutes: 15);
    final color = overdue
        ? colors.error
        : soon
        ? colors.tertiary
        : colors.primary;

    final grace = loan.graceMinutes;
    final classEnds = loan.classEndsAt;
    final detail = overdue
        ? 'Was due ${formatClock(due)}'
        : [
            'Due ${formatClock(due)}',
            if (classEnds != null && grace != null)
              'class ends ${formatClock(classEnds)} + $grace min grace'
            else if (grace != null)
              'includes $grace min grace',
          ].join(' · ');

    return Row(
      children: [
        Icon(overdue ? Icons.alarm : Icons.timer_outlined, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overdue
                    ? 'Overdue by ${formatCountdown(left)}'
                    : 'Due in ${formatCountdown(left)}',
                key: ValueKey('countdown-${loan.id}'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// For a closed loan: "Checked out 18 Nov, 1:00 PM · returned 3:05 PM".
  Widget? _ended(BuildContext context) {
    if (loan.isOpen) return null;
    final theme = Theme.of(context);
    final out = loan.checkedOutAt;
    String sameDay(DateTime at) =>
        DateUtils.isSameDay(at.toLocal(), out.toLocal())
        ? formatClock(at)
        : formatDateTime(at, now: now);
    final end = switch (loan.status) {
      'RETURNED' =>
        loan.returnedAt == null
            ? 'returned'
            : 'returned ${sameDay(loan.returnedAt!)}',
      'MISSING' =>
        loan.missingAt == null
            ? 'marked missing'
            : 'marked missing ${sameDay(loan.missingAt!)}',
      'CANCELLED' => 'cancelled',
      _ => null,
    };
    return Text(
      ['Checked out ${formatDateTime(out, now: now)}', ?end].join(' · '),
      key: ValueKey('ended-${loan.id}'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// While in transit: how long the student has left to tap in at the room.
  Widget? _transit(BuildContext context, LoanLiveStatus status) {
    final deadline = loan.transitDeadlineAt;
    if (status != LoanLiveStatus.inTransit || deadline == null) return null;
    final left = deadline.difference(now);
    final theme = Theme.of(context);
    return Text(
      left.isNegative
          ? 'Not checked in at the room in time'
          : 'Check in at the room within ${formatCountdown(left)}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: left.isNegative
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// At Counter, In Transit, Verified in Room, Overdue..., coloured by
/// urgency.
class LiveStatusChip extends StatelessWidget {
  const LiveStatusChip({super.key, required this.status});

  final LoanLiveStatus status;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      _ when status.isUrgent => (c.errorContainer, c.onErrorContainer),
      LoanLiveStatus.inTransit => (c.tertiaryContainer, c.onTertiaryContainer),
      LoanLiveStatus.verifiedInRoom => (
        c.primaryContainer,
        c.onPrimaryContainer,
      ),
      LoanLiveStatus.atCounter => (
        c.secondaryContainer,
        c.onSecondaryContainer,
      ),
      _ => (c.surfaceContainerHighest, c.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
