import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../routing/locations.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_scan.dart';
import '../controllers/audit_sync_controller.dart';
import '../controllers/scan_controller.dart';
import '../widgets/asset_qr_camera.dart';
import '../widgets/audit_status_bar.dart';
import '../widgets/scan_feedback_banner.dart';

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key, required this.localAuditId});

  final String localAuditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = scanControllerProvider(localAuditId);
    final session = ref.watch(provider);
    final online = ref.watch(isOnlineProvider);

    ref.listen(provider.select((s) => s.value?.feedback), (previous, next) {
      if (next != null && next.serial != previous?.serial) _haptic(next.kind);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(session.value?.roster.room.label ?? 'Scan'),
        actions: [ConnectionChip(online: online)],
      ),
      body: switch (session) {
        AsyncValue(:final value?) => Column(
          children: [
            Expanded(
              child: value.audit.isOpen
                  ? ref.watch(scanCameraProvider)(
                      ref.read(provider.notifier).onCode,
                    )
                  : _Closed(status: value.audit.status),
            ),
            _ScanPanel(
              session: value,
              online: online,
              localAuditId: localAuditId,
            ),
          ],
        ),
        AsyncValue(:final error?) => EmptyState(
          icon: Icons.error_outline,
          title: "Couldn't open this audit",
          message: error is Failure
              ? error.message
              : 'Something went wrong. Please try again.',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static void _haptic(ScanFeedbackKind kind) {
    switch (kind) {
      case ScanFeedbackKind.matched:
        HapticFeedback.mediumImpact();
      case ScanFeedbackKind.alreadyScanned:
        HapticFeedback.selectionClick();
      case ScanFeedbackKind.pending ||
          ScanFeedbackKind.misplaced ||
          ScanFeedbackKind.unknown:
        HapticFeedback.heavyImpact();
    }
  }
}

class ConnectionChip extends StatelessWidget {
  const ConnectionChip({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Chip(
        key: const Key('connection-status'),
        visualDensity: VisualDensity.compact,
        avatar: Icon(
          online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          size: 18,
          color: online ? colors.primary : colors.error,
        ),
        label: Text(online ? 'Online' : 'Offline'),
      ),
    );
  }
}

class _ScanPanel extends ConsumerWidget {
  const _ScanPanel({
    required this.session,
    required this.online,
    required this.localAuditId,
  });

  final ScanSession session;
  final bool online;
  final String localAuditId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncing = ref.watch(
      auditSyncControllerProvider.select((s) => s.running),
    );
    final expected = session.expected;
    final found = session.found;
    final pending = session.count(ScanResult.pending);
    final misplaced = session.count(ScanResult.misplaced);
    final unknown = session.count(ScanResult.unknown);
    final waiting = session.unsynced;

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScanFeedbackBanner(feedback: session.feedback),
              const SizedBox(height: 14),
              Text(
                '$found of $expected found',
                key: const Key('scan-progress'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: expected == 0 ? 0 : found / expected,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  '$pending pending',
                  if (misplaced > 0) '$misplaced misplaced',
                  '$unknown unknown',
                ].join(' · '),
                key: const Key('scan-counts'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    waiting > 0
                        ? Icons.cloud_upload_outlined
                        : Icons.cloud_done_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      waiting > 0 ? waitingLabel(waiting) : 'All scans synced',
                      key: const Key('scan-queue'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    key: const Key('scan-sync-now'),
                    onPressed: online && waiting > 0 && !syncing
                        ? () => ref
                              .read(auditSyncControllerProvider.notifier)
                              .syncNow()
                        : null,
                    child: Text(syncing ? 'Syncing…' : 'Sync now'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                key: const Key('scan-review'),
                onPressed: () =>
                    context.push(auditSummaryLocation(localAuditId)),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review and submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Closed extends StatelessWidget {
  const _Closed({required this.status});

  final AuditStatus status;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: status == AuditStatus.endedElsewhere
        ? Icons.sync_problem_outlined
        : Icons.task_alt,
    title: status == AuditStatus.endedElsewhere
        ? 'Completed on another device'
        : 'This audit is submitted',
    message: status == AuditStatus.endedElsewhere
        ? "Scans here that didn't sync can't be added to it any more."
        : 'Scanning is closed. Open the summary to see the results.',
  );
}
