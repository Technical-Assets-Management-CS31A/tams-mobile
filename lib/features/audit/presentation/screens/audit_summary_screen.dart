import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../../../core/theme/brand.dart';
import '../../../../core/widgets/brand_app_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_failure.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/roster.dart';
import '../controllers/audit_providers.dart';
import '../controllers/audit_sync_controller.dart';
import '../controllers/scan_controller.dart';
import '../widgets/audit_results.dart';
import '../widgets/audit_status_bar.dart';
import '../widgets/report_actions.dart';
import 'scanner_screen.dart';

class AuditSummaryScreen extends ConsumerStatefulWidget {
  const AuditSummaryScreen({super.key, required this.localAuditId});

  final String localAuditId;

  @override
  ConsumerState<AuditSummaryScreen> createState() => _AuditSummaryScreenState();
}

class _AuditSummaryScreenState extends ConsumerState<AuditSummaryScreen> {
  AuditDetail? _completed;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(scanControllerProvider(widget.localAuditId));
    final online = ref.watch(isOnlineProvider);

    return BrandPage(
      title: session.value == null
          ? 'Summary'
          : '${session.value!.roster.room.code} summary',
      trailing: ConnectionChip(online: online),
      body: switch (session) {
        AsyncValue(:final value?) => _body(value, online),
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

  Widget _body(ScanSession session, bool online) {
    final completed = _completed;
    if (completed != null) {
      return _CompletedView(
        detail: completed,
        roster: session.roster,
        onSignedOff: (audit) {
          setState(
            () =>
                _completed = AuditDetail(audit: audit, items: completed.items),
          );
          _saveSignOff(session.audit.localId);
        },
      );
    }
    final audit = session.audit;
    if (audit.status == AuditStatus.completed ||
        audit.status == AuditStatus.signedOff) {
      return _StoredCompleted(
        audit: audit,
        roster: session.roster,
        onSignedOff: (_) => _saveSignOff(audit.localId),
      );
    }
    return Column(
      children: [
        Expanded(child: _OpenSummary(session: session)),
        if (audit.isOpen) _submitBar(session, online),
      ],
    );
  }

  String? _blockedReason(ScanSession session, bool online) {
    if (!online) return 'Connect to the internet to submit.';
    if (session.unsynced > 0) {
      return '${waitingLabel(session.unsynced)}. Sync them to submit.';
    }
    if (session.audit.serverId == null) {
      return "This audit hasn't reached the server yet. Sync it first.";
    }
    return null;
  }

  Widget _submitBar(ScanSession session, bool online) {
    final reason = _blockedReason(session, online);
    final syncing = ref.watch(
      auditSyncControllerProvider.select((s) => s.running),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: BrandColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reason != null) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: BoxDecoration(
                    color: BrandColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: BrandColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          reason,
                          key: const Key('submit-blocked'),
                          style: brandText(
                            13,
                            color: BrandColors.warning,
                          ).copyWith(height: 1.35),
                        ),
                      ),
                      if (online && !syncing)
                        TextButton(
                          onPressed: () => ref
                              .read(auditSyncControllerProvider.notifier)
                              .syncNow(),
                          style: BrandButtons.inline(BrandColors.warning),
                          child: const Text('Sync now'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                key: const Key('submit-audit'),
                onPressed: reason == null && !_submitting
                    ? () => _confirmSubmit(session)
                    : null,
                style: _bigButton(BrandButtons.primary(height: 54, radius: 14)),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: BrandColors.primary,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: const Text('Submit audit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSubmit(ScanSession session) async {
    final missing = session.missing.length;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Sizes to its content instead of the default 9/16 cap, and
      // scrolls on short screens.
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Submit the audit of ${session.roster.room.code}?',
              style: brandText(22, weight: FontWeight.w700, ls: -0.5),
            ),
            const SizedBox(height: 10),
            Text(
              missing == 0
                  ? 'Every item on the roster was found.'
                  : '${missing == 1 ? '1 item' : '$missing items'} not '
                        'scanned will be recorded as missing.',
              key: const Key('submit-missing'),
              style: brandText(
                15,
                color: BrandColors.muted,
              ).copyWith(height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: BrandColors.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: BrandColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You cannot scan into this audit after submitting.',
                      style: brandText(13, color: BrandColors.muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('submit-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              style: _bigButton(BrandButtons.primary(height: 54, radius: 14)),
              child: const Text('Submit'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: _bigButton(BrandButtons.subtle(height: 54, radius: 14)),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && mounted) await _submit(session.audit);
  }

  Future<void> _submit(LocalAudit audit) async {
    setState(() => _submitting = true);
    // Read before any await: the user can leave while the submit runs.
    final revision = ref.read(auditRevisionProvider.notifier);
    try {
      final service = await ref.read(auditSessionServiceProvider.future);
      final detail = await service.complete(audit);
      if (mounted) setState(() => _completed = detail);
    } on AuditFailure catch (f) {
      _say(f.message);
    } on Failure catch (f) {
      _say(f.message);
    } finally {
      revision.bump();
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Keeps the sign-off on this phone, so the audit shows as signed off
  /// here and when it's opened again.
  Future<void> _saveSignOff(String localId) async {
    final revision = ref.read(auditRevisionProvider.notifier);
    try {
      final store = await ref.read(auditStoreProvider.future);
      await store.markSignedOff(localId);
      revision.bump();
    } catch (e) {
      debugPrint("Couldn't save the sign-off on this phone: $e");
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OpenSummary extends StatelessWidget {
  const _OpenSummary({required this.session});

  final ScanSession session;

  @override
  Widget build(BuildContext context) {
    final scans = session.scans;
    List<Widget> tiles(ScanResult result) => [
      for (final s in scans)
        if (s.result == result)
          ResultTile(
            title: s.assetName ?? s.assetCode ?? s.scannedValue,
            subtitle: s.assetName == null ? null : s.assetCode,
          ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (session.audit.status == AuditStatus.endedElsewhere)
          const OfflineBanner(
            message:
                'This audit was completed on another device. These scans '
                "can't be submitted.",
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _ProgressCard(
            found: session.found,
            expected: session.expected,
          ),
        ),
        ResultSection(
          title: 'Missing',
          hint: 'On the roster but not scanned yet.',
          children: [
            for (final i in session.missing)
              ResultTile(
                key: ValueKey('missing-${i.assetId}'),
                title: i.name,
                subtitle: [
                  i.assetCode,
                  i.category,
                ].where((s) => s.isNotEmpty).join(' · '),
                onLoan: i.isOnLoan,
              ),
          ],
        ),
        ResultSection(
          title: 'Misplaced',
          hint: 'These belong to another room.',
          children: tiles(ScanResult.misplaced),
        ),
        ResultSection(
          title: 'Pending',
          hint: 'Not on this roster. The server checks them when they sync.',
          children: tiles(ScanResult.pending),
        ),
        ResultSection(
          title: 'Unknown',
          hint: 'Not TAMS asset labels.',
          children: tiles(ScanResult.unknown),
        ),
        ResultSection(title: 'Matched', children: tiles(ScanResult.matched)),
      ],
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({
    required this.detail,
    required this.roster,
    this.onSignedOff,
  });

  final AuditDetail detail;
  final Roster roster;
  final ValueChanged<ServerAudit>? onSignedOff;

  @override
  Widget build(BuildContext context) {
    final audit = detail.audit;
    List<Widget> tiles(ScanResult result) => [
      for (final l in detail.withResult(result))
        ResultTile(
          title: l.name ?? l.assetCode ?? l.scannedValue,
          subtitle: l.name == null ? null : l.assetCode,
          onLoan:
              result == ScanResult.missing &&
              l.assetId != null &&
              (roster.item(l.assetId!)?.isOnLoan ?? false),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _SubmittedHeader(
            signedOff: audit.status == AuditStatus.signedOff,
            room: roster.room.label,
          ),
        ),
        if (audit.counts case final counts?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AuditCountsRow(counts: counts),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ReportActions(
            auditId: audit.id,
            roomCode: roster.room.code,
            status: audit.status,
            onSignedOff: onSignedOff,
          ),
        ),
        ResultSection(title: 'Missing', children: tiles(ScanResult.missing)),
        ResultSection(
          title: 'Misplaced',
          children: tiles(ScanResult.misplaced),
        ),
        ResultSection(title: 'Unknown', children: tiles(ScanResult.unknown)),
        ResultSection(title: 'Matched', children: tiles(ScanResult.matched)),
      ],
    );
  }
}

class _StoredCompleted extends StatelessWidget {
  const _StoredCompleted({
    required this.audit,
    required this.roster,
    this.onSignedOff,
  });

  final LocalAudit audit;
  final Roster roster;
  final ValueChanged<ServerAudit>? onSignedOff;

  @override
  Widget build(BuildContext context) {
    final serverId = audit.serverId;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        _SubmittedHeader(
          signedOff: audit.status == AuditStatus.signedOff,
          room: roster.room.label,
        ),
        if (audit.counts case final counts?)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AuditCountsRow(counts: counts),
          ),
        if (serverId != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ReportActions(
              auditId: serverId,
              roomCode: roster.room.code,
              status: audit.status,
              onSignedOff: onSignedOff,
            ),
          ),
      ],
    );
  }
}

/// Found count, percentage and bar at the top of an open audit's summary.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.found, required this.expected});

  final int found;
  final int expected;

  @override
  Widget build(BuildContext context) {
    final progress = expected == 0 ? 0.0 : found / expected;
    return BrandCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '$found of $expected found',
                  style: brandText(22, weight: FontWeight.w700, ls: -0.5),
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
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: BrandColors.primary,
            backgroundColor: BrandColors.field,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

/// Green tick, "Submitted" and the room, for an audit that's done.
class _SubmittedHeader extends StatelessWidget {
  const _SubmittedHeader({required this.signedOff, required this.room});

  final bool signedOff;
  final String room;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: BrandColors.successBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          signedOff ? Icons.verified_rounded : Icons.task_alt_rounded,
          color: BrandColors.success,
          size: 26,
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              signedOff ? 'Submitted and signed off' : 'Submitted',
              key: const Key('audit-submitted'),
              style: brandText(20, weight: FontWeight.w700, ls: -0.4),
            ),
            const SizedBox(height: 2),
            Text(
              room,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: brandText(13, color: BrandColors.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The 16 pt label the login screen's button uses, for full-width buttons.
ButtonStyle _bigButton(ButtonStyle style) => style.copyWith(
  textStyle: WidgetStatePropertyAll(brandText(16, weight: FontWeight.w600)),
);
