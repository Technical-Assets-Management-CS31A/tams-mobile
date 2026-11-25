import 'package:flutter/material.dart';

import '../../../../core/theme/brand.dart';
import '../controllers/scan_controller.dart';

/// What the last scan was, or a hint while nothing has been scanned yet.
/// Each new scan cross-fades in.
class ScanFeedbackBanner extends StatelessWidget {
  const ScanFeedbackBanner({super.key, required this.feedback});

  final ScanFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    return AnimatedSwitcher(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      child: feedback == null
          ? const _Banner(
              key: ValueKey('idle'),
              bg: BrandColors.field,
              fg: BrandColors.muted,
              icon: Icons.qr_code_2_rounded,
              detail: 'Point the camera at an asset QR label.',
            )
          : _banner(feedback),
    );
  }

  Widget _banner(ScanFeedback feedback) {
    final (bg, fg, icon) = scanFeedbackStyle(feedback.kind);
    return _Banner(
      key: ValueKey(feedback.serial),
      bg: bg,
      fg: fg,
      icon: icon,
      title: feedback.title,
      detail: feedback.detail,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.detail,
    this.title,
  });

  final Color bg;
  final Color fg;
  final IconData icon;
  final String? title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Container(
      width: double.infinity,
      // Same height idle or not, so the panel doesn't jump on first scan.
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title,
                    key: const Key('scan-feedback-title'),
                    style: brandText(15, weight: FontWeight.w700, color: fg),
                  ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: brandText(
                    13,
                    color: title == null ? fg : fg.withValues(alpha: 0.85),
                  ).copyWith(height: 1.35),
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
        Icons.check_circle_rounded,
      ),
      ScanFeedbackKind.pending => (
        const Color(0xFFFEF3C7),
        const Color(0xFF78350F),
        Icons.schedule_rounded,
      ),
      ScanFeedbackKind.misplaced => (
        const Color(0xFFFFEDD5),
        const Color(0xFF7C2D12),
        Icons.wrong_location_outlined,
      ),
      ScanFeedbackKind.unknown => (
        const Color(0xFFFEE2E2),
        const Color(0xFF7F1D1D),
        Icons.help_outline_rounded,
      ),
      ScanFeedbackKind.alreadyScanned => (
        BrandColors.field,
        const Color(0xFF1F2937),
        Icons.repeat_rounded,
      ),
    };
