import 'package:flutter/material.dart';

import '../controllers/scan_controller.dart';

class ScanFeedbackBanner extends StatelessWidget {
  const ScanFeedbackBanner({super.key, required this.feedback});

  final ScanFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      child: feedback == null
          ? Container(
              key: const ValueKey('idle'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Point the camera at an asset QR label.',
                style: theme.textTheme.bodyMedium,
              ),
            )
          : _banner(context, feedback),
    );
  }

  Widget _banner(BuildContext context, ScanFeedback feedback) {
    final theme = Theme.of(context);
    final (bg, fg, icon) = scanFeedbackStyle(feedback.kind);
    return Container(
      key: ValueKey(feedback.serial),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feedback.title,
                  key: const Key('scan-feedback-title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  feedback.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

(Color, Color, IconData) scanFeedbackStyle(ScanFeedbackKind kind) =>
    switch (kind) {
      ScanFeedbackKind.matched => (
        const Color(0xFFDCFCE7),
        const Color(0xFF14532D),
        Icons.check_circle,
      ),
      ScanFeedbackKind.pending => (
        const Color(0xFFFEF3C7),
        const Color(0xFF78350F),
        Icons.schedule,
      ),
      ScanFeedbackKind.misplaced => (
        const Color(0xFFFFEDD5),
        const Color(0xFF7C2D12),
        Icons.wrong_location_outlined,
      ),
      ScanFeedbackKind.unknown => (
        const Color(0xFFFEE2E2),
        const Color(0xFF7F1D1D),
        Icons.help_outline,
      ),
      ScanFeedbackKind.alreadyScanned => (
        const Color(0xFFE5E7EB),
        const Color(0xFF1F2937),
        Icons.repeat,
      ),
    };
