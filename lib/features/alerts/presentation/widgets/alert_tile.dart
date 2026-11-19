import 'package:flutter/material.dart';

import '../../../../core/utils/time_format.dart';
import '../../domain/entities/alert.dart';

/// One alert in the list: kind, title, the student it's about, what
/// happened and when. Unread alerts are bold with a dot.
class AlertTile extends StatelessWidget {
  const AlertTile({
    super.key,
    required this.alert,
    required this.now,
    required this.onTap,
  });

  final Alert alert;
  final DateTime now;

  /// Null when there's no loan to open.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, background, foreground, accent) = _look(alert.kind, colors);
    final unread = alert.isUnread;
    final who = alert.who;

    return Card(
      margin: EdgeInsets.zero,
      color: unread ? colors.surfaceContainerHigh : colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: background,
                child: Icon(icon, color: foreground, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _kindLabel(alert),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '  ·  ${formatAge(alert.createdAt, now: now)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (who != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        who,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (alert.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        alert.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (alert.penaltyTriggered) ...[
                      const SizedBox(height: 8),
                      _PenaltyNote(colors: colors),
                    ],
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Semantics(
                    label: 'Unread',
                    child: Container(
                      key: const Key('unread-dot'),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Late arrival · Warning #2", or just the kind.
  static String _kindLabel(Alert alert) {
    final no = alert.warningNo;
    return alert.kind == AlertKind.lateArrival && no != null
        ? '${alert.kind.label} · Warning #$no'
        : alert.kind.label;
  }

  /// Icon, its circle's colours, and the colour of the kind label.
  /// Warnings are amber-ish (tertiary); anything needing action is red.
  static (IconData, Color, Color, Color) _look(AlertKind kind, ColorScheme c) =>
      switch (kind) {
        AlertKind.lateArrival => (
          Icons.schedule,
          c.tertiaryContainer,
          c.onTertiaryContainer,
          c.tertiary,
        ),
        AlertKind.anomaly => (
          Icons.wrong_location_outlined,
          c.errorContainer,
          c.onErrorContainer,
          c.error,
        ),
        AlertKind.overdue => (
          Icons.alarm,
          c.errorContainer,
          c.onErrorContainer,
          c.error,
        ),
        AlertKind.missing => (
          Icons.report_outlined,
          c.errorContainer,
          c.onErrorContainer,
          c.error,
        ),
        AlertKind.other => (
          Icons.notifications_none_outlined,
          c.surfaceContainerHighest,
          c.onSurfaceVariant,
          c.onSurfaceVariant,
        ),
      };
}

/// US-07: the fourth warning froze my approvals.
class _PenaltyNote extends StatelessWidget {
  const _PenaltyNote({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 16, color: colors.onErrorContainer),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Non-Compliance Mark issued · approvals frozen',
            style: TextStyle(color: colors.onErrorContainer, fontSize: 12.5),
          ),
        ),
      ],
    ),
  );
}
