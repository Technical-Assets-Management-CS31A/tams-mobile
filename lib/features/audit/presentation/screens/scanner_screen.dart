import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../../../core/theme/brand.dart';
import '../../../../core/widgets/brand_app_bar.dart';
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

    final room = session.value?.roster.room;

    return BrandPage(
      // The code as the header and the name under it, such as STORE-1
      // over Equipment Storage.
      title: room?.code ?? 'Scan',
      subtitle: room == null || room.name.isEmpty || room.name == room.code
          ? null
          : room.name,
      trailing: ConnectionChip(online: online),
      body: switch (session) {
        // Black behind the panel's rounded top corners, so they read as
        // a sheet laid over the camera.
        AsyncValue(:final value?) => ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              Expanded(
                child: value.audit.isOpen
                    ? ref.watch(scanCameraProvider)(
                        ref.read(provider.notifier).onCode,
                      )
                    : ColoredBox(
                        color: Colors.white,
                        child: _Closed(status: value.audit.status),
                      ),
              ),
              _ScanPanel(
                session: value,
                online: online,
                localAuditId: localAuditId,
              ),
            ],
          ),
        ),
        AsyncValue(:final error?) => EmptyState(
          icon: Icons.error_outline,
          title: "Couldn't open this audit",
          message: error is Failure
              ? error.message
              : 'Something went wrong. Please try again.',
        ),
        _ => const Center(
          child: CircularProgressIndicator(color: BrandColors.primary),
        ),
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
          ScanFeedbackKind.unknown ||
          ScanFeedbackKind.saveFailed:
        HapticFeedback.heavyImpact();
    }
  }
}

/// "Online" or "Offline" with a coloured dot, for a screen's header.
class ConnectionChip extends StatelessWidget {
  const ConnectionChip({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final color = online ? BrandColors.success : BrandColors.faint;
    return Row(
      key: const Key('connection-status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          online ? 'Online' : 'Offline',
          style: brandText(
            13,
            weight: FontWeight.w500,
            color: online ? BrandColors.success : BrandColors.muted,
          ),
        ),
      ],
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
    final syncing = ref.watch(
      auditSyncControllerProvider.select((s) => s.running),
    );
    final expected = session.expected;
    final found = session.found;
    final pending = session.count(ScanResult.pending);
    final misplaced = session.count(ScanResult.misplaced);
    final unknown = session.count(ScanResult.unknown);
    final waiting = session.unsynced;

    final progress = expected == 0 ? 0.0 : found / expected;
    final still = MediaQuery.of(context).disableAnimations;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScanFeedbackBanner(feedback: session.feedback),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '$found of $expected found',
                      key: const Key('scan-progress'),
                      style: brandText(18, weight: FontWeight.w700, ls: -0.4),
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: brandText(
                      14,
                      weight: FontWeight.w600,
                      color: BrandColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  color: BrandColors.primary,
                  backgroundColor: BrandColors.field,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                [
                  '$pending pending',
                  if (misplaced > 0) '$misplaced misplaced',
                  '$unknown unknown',
                ].join(' · '),
                key: const Key('scan-counts'),
                style: brandText(13, color: BrandColors.muted),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                  color: BrandColors.field,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      waiting > 0
                          ? Icons.cloud_upload_outlined
                          : Icons.cloud_done_outlined,
                      size: 18,
                      color: waiting > 0
                          ? BrandColors.warning
                          : BrandColors.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        waiting > 0
                            ? waitingLabel(waiting)
                            : 'All scans synced',
                        key: const Key('scan-queue'),
                        style: brandText(
                          13,
                          weight: FontWeight.w500,
                          color: BrandColors.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('scan-sync-now'),
                      onPressed: online && waiting > 0 && !syncing
                          ? () => ref
                                .read(auditSyncControllerProvider.notifier)
                                .syncNow()
                          : null,
                      style: BrandButtons.inline(BrandColors.primary),
                      child: Text(syncing ? 'Syncing…' : 'Sync now'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('scan-review'),
                onPressed: () =>
                    context.push(auditSummaryLocation(localAuditId)),
                style: BrandButtons.primary(height: 54, radius: 14).copyWith(
                  textStyle: WidgetStatePropertyAll(
                    brandText(16, weight: FontWeight.w600),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 20),
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
