import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: colors.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: colors.onSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      color: colors.secondaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 18,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              waitingLabel(waiting),
              key: const Key('sync-waiting'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (syncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              key: const Key('sync-now'),
              onPressed: online ? onSync : null,
              child: const Text('Sync now'),
            ),
        ],
      ),
    );
  }
}

String waitingLabel(int n) =>
    n == 1 ? '1 scan waiting to sync' : '$n scans waiting to sync';
