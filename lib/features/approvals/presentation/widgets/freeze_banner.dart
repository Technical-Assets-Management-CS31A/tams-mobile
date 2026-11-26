import 'package:flutter/material.dart';

import '../../domain/entities/pending_approval.dart';

/// Shown while staff have frozen my approval rights (FR-2.3, US-06): names
/// the item and student behind each freeze, and what clears it. On
/// Pending Approvals and My Loans (PRD 6.6).
class FreezeBanner extends StatelessWidget {
  const FreezeBanner({
    super.key,
    required this.freezes,
    this.canStillDecline = false,
  });

  /// Newest first. May be empty when the server sent no details.
  final List<ApprovalFreeze> freezes;

  /// Says that declining still works; true on Pending Approvals.
  final bool canStillDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onErrorContainer;
    final body = theme.textTheme.bodyMedium?.copyWith(color: fg);

    return Card(
      key: const Key('freeze-banner'),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approvals frozen',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  for (final f in freezes) ...[
                    const SizedBox(height: 6),
                    Text(freezeLine(f), style: body),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    [
                      'Technical staff must lift the freeze before you can '
                          'approve.',
                      if (canStillDecline) 'You can still decline.',
                    ].join(' '),
                    style: body,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Overdue: Epson Projector (PRJ-0012), borrowed by Maria Santos".
String freezeLine(ApprovalFreeze f) {
  final student = f.studentName;
  final what = [
    ?f.item,
    if (student != null) 'borrowed by $student',
  ].join(', ');
  return what.isEmpty ? f.reason.label : '${f.reason.label}: $what';
}
