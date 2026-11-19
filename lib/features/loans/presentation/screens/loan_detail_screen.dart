import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/token_provider.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/loan_detail.dart';
import '../controllers/loan_detail_provider.dart';

/// The loan an alert is about: who has which item, where it was sent, when
/// it is due, and what has happened to it so far.
class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId});

  final String loanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loanDetailProvider(loanId));
    Future<void> reload() => ref.refresh(loanDetailProvider(loanId).future);

    return Scaffold(
      appBar: AppBar(title: Text(state.value?.loanNo ?? 'Loan')),
      body: switch (state) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: reload,
          child: _Body(loan: value, now: ref.watch(clockProvider)()),
        ),
        AsyncValue(:final error?) => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load this loan",
          message: error is Failure
              ? error.message
              : 'Something went wrong. Please try again.',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(loanDetailProvider(loanId)),
            child: const Text('Try again'),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.loan, required this.now});

  final LoanDetail loan;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final token = ref.watch(authTokenProvider);
    final photo = loan.photoUrl;
    String at(DateTime t) => formatDateTime(t, now: now);

    final borrower = switch (loan) {
      LoanDetail(:final studentName?) => (
        'Student',
        studentName,
        [loan.studentNo, loan.sectionCode].nonNulls.join(' · '),
      ),
      LoanDetail(:final eventTitle?) => (
        'Event',
        eventTitle,
        loan.borrowerName ?? '',
      ),
      _ => null,
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.assetName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    loan.assetCode,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip(status: loan.status),
          ],
        ),
        if (photo != null) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                photo,
                fit: BoxFit.cover,
                headers: token == null
                    ? null
                    : {'Authorization': 'Bearer $token'},
                errorBuilder: (_, _, _) => ColoredBox(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              if (borrower case (final label, final name, final sub))
                _Fact(
                  icon: Icons.person_outline,
                  label: label,
                  value: name,
                  sub: sub.isEmpty ? null : sub,
                ),
              if (loan.room case final room?)
                _Fact(
                  icon: Icons.meeting_room_outlined,
                  label: 'Room',
                  value: room,
                  sub: _custody(loan.custodyState),
                ),
              _Fact(
                icon: Icons.logout,
                label: 'Checked out',
                value: at(loan.checkedOutAt),
              ),
              if (loan.dueAt case final due?)
                _Fact(icon: Icons.event_outlined, label: 'Due', value: at(due)),
              if (loan.overdueAt case final t?)
                _Fact(
                  icon: Icons.alarm,
                  label: 'Overdue since',
                  value: at(t),
                  warn: true,
                ),
              if (loan.missingAt case final t?)
                _Fact(
                  icon: Icons.report_outlined,
                  label: 'Declared missing',
                  value: at(t),
                  warn: true,
                ),
              if (loan.returnedAt case final t?)
                _Fact(
                  icon: Icons.assignment_return_outlined,
                  label: 'Returned',
                  value: at(t),
                ),
              if (loan.lateArrivalWarningNo case final no?)
                _Fact(
                  icon: Icons.schedule,
                  label: 'Late arrival warning',
                  value: '#$no this term',
                  warn: true,
                ),
            ],
          ),
        ),
        if (loan.ledger.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Activity', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in loan.ledger.reversed)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle, size: 10),
              minLeadingWidth: 16,
              title: Text(humanize(entry.event)),
              trailing: Text(at(entry.occurredAt)),
            ),
        ],
      ],
    );
  }

  static String? _custody(String? state) => switch (state) {
    'AWAITING_ARRIVAL' => 'Not checked in at the room yet',
    'VERIFIED' => 'Checked in at the room',
    'ANOMALY' => 'Not checked in at the room in time',
    _ => null,
  };
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.warn = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = warn ? colors.error : null;
    return ListTile(
      leading: Icon(icon, color: color ?? colors.onSurfaceVariant),
      title: Text(label),
      subtitle: sub == null ? null : Text(sub!),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ),
    );
  }
}

/// ACTIVE, OVERDUE, RETURNED, MISSING or CANCELLED, coloured by urgency.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      'OVERDUE' || 'MISSING' => (c.errorContainer, c.onErrorContainer),
      'ACTIVE' => (c.primaryContainer, c.onPrimaryContainer),
      _ => (c.surfaceContainerHighest, c.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        humanize(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "LATE_ARRIVAL_WARNING" → "Late arrival warning".
String humanize(String code) {
  final words = code.toLowerCase().replaceAll('_', ' ').trim();
  return words.isEmpty ? code : words[0].toUpperCase() + words.substring(1);
}
