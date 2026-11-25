import 'package:flutter/material.dart';

import '../../../../core/theme/brand.dart';
import '../../domain/entities/audit.dart';

/// Hairline-bordered white box shared by the audit result cards.
class BrandCard extends StatelessWidget {
  const BrandCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: BrandColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}

/// The five audit totals side by side, each number in its result's colour.
class AuditCountsRow extends StatelessWidget {
  const AuditCountsRow({super.key, required this.counts});

  final AuditCounts counts;

  @override
  Widget build(BuildContext context) {
    final figures = [
      ('Expected', counts.expected, BrandColors.ink),
      ('Matched', counts.matched, BrandColors.success),
      ('Missing', counts.missing, BrandColors.error),
      ('Misplaced', counts.misplaced, BrandColors.warning),
      ('Unknown', counts.unknown, BrandColors.muted),
    ];
    return BrandCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Row(
        children: [
          for (final (label, value, color) in figures)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$value',
                    key: Key('count-${label.toLowerCase()}'),
                    style: brandText(
                      20,
                      weight: FontWeight.w700,
                      color: value == 0 ? BrandColors.faint : color,
                      ls: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: brandText(11.5, color: BrandColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A titled group of [ResultTile]s in one card, hidden when empty.
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title (${children.length})',
            style: brandText(15, weight: FontWeight.w600, ls: -0.2),
          ),
          if (hint case final hint?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(hint, style: brandText(13, color: BrandColors.muted)),
            ),
          const SizedBox(height: 10),
          BrandCard(
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 14,
                      color: BrandColors.line,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One asset in a [ResultSection], with an "On loan" pill when it's
/// borrowed rather than lost.
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
    final subtitle = this.subtitle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: brandText(14, weight: FontWeight.w500),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: brandText(12.5, color: BrandColors.muted),
                  ),
                ],
              ],
            ),
          ),
          if (onLoan)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: BrandPill(
                'On loan',
                color: BrandColors.warning,
                background: BrandColors.warningBg,
              ),
            ),
        ],
      ),
    );
  }
}
