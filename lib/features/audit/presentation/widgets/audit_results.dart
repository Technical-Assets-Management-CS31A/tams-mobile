import 'package:flutter/material.dart';

import '../../domain/entities/audit.dart';

class AuditCountsRow extends StatelessWidget {
  const AuditCountsRow({super.key, required this.counts});

  final AuditCounts counts;

  @override
  Widget build(BuildContext context) {
    final figures = [
      ('Expected', counts.expected),
      ('Matched', counts.matched),
      ('Missing', counts.missing),
      ('Misplaced', counts.misplaced),
      ('Unknown', counts.unknown),
    ];
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final (label, value) in figures)
          Expanded(
            child: Column(
              children: [
                Text(
                  '$value',
                  key: Key('count-${label.toLowerCase()}'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ResultSection extends StatelessWidget {
  const ResultSection({
    super.key,
    required this.title,
    required this.children,
    this.hint,
  });

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$title (${children.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (hint case final hint?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }
}

class ResultTile extends StatelessWidget {
  const ResultTile({
    super.key,
    required this.title,
    this.subtitle,
    this.onLoan = false,
  });

  final String title;
  final String? subtitle;
  final bool onLoan;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onLoan
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.tertiaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'On loan',
                style: TextStyle(
                  color: colors.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            )
          : null,
    );
  }
}
