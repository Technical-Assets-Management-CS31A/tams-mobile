import 'package:flutter/material.dart';

import '../../../../core/theme/brand.dart';

/// Rounded grey notice inset from the screen edges, such as "You're
/// offline".
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _Inset(
      color: BrandColors.field,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: BrandColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: brandText(
                13,
                color: BrandColors.muted,
              ).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinted notice with a Sync now button while scans wait to upload.
class SyncBar extends StatelessWidget {
  const SyncBar({
    super.key,
    required this.waiting,
    required this.online,
    required this.syncing,
    required this.onSync,
  });

  final int waiting;
  final bool online;
  final bool syncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return _Inset(
      color: BrandColors.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            size: 18,
            color: BrandColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              waitingLabel(waiting),
              key: const Key('sync-waiting'),
              style: brandText(
                13,
                weight: FontWeight.w600,
                color: BrandColors.primary,
              ),
            ),
          ),
          if (syncing)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: BrandColors.primary,
                ),
              ),
            )
          else
            TextButton(
              key: const Key('sync-now'),
              onPressed: online ? onSync : null,
              style: BrandButtons.inline(BrandColors.primary),
              child: const Text('Sync now'),
            ),
        ],
      ),
    );
  }
}

class _Inset extends StatelessWidget {
  const _Inset({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  final Color color;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    ),
  );
}

String waitingLabel(int n) =>
    n == 1 ? '1 scan waiting to sync' : '$n scans waiting to sync';
