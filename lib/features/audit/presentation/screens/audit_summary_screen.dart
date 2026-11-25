import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
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

    return Scaffold(
      appBar: brandAppBar(
        context,
        title: session.value == null
            ? 'Summary'
            : '${session.value!.roster.room.code} summary',
        actions: [ConnectionChip(online: online)],
      ),
      body: switch (session) {
        AsyncValue(:final value?) => _body(value, online),
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

  Widget _body(ScanSession session, bool online) {
    final completed = _completed;
    if (completed != null) {
      return _CompletedView(
        detail: completed,
        roster: session.roster,
        onSignedOff: (audit) => setState(
          () => _completed = AuditDetail(audit: audit, items: completed.items),
        ),
      );
    }
    final audit = session.audit;
    if (audit.status == AuditStatus.completed ||
        audit.status == AuditStatus.signedOff) {
      return _StoredCompleted(audit: audit, roster: session.roster);
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
    final theme = Theme.of(context);
    final reason = _blockedReason(session, online);
    final syncing = ref.watch(
      auditSyncControllerProvider.select((s) => s.running),
    );
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reason != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reason,
                        key: const Key('submit-blocked'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    if (online && !syncing)
                      TextButton(
                        onPressed: () => ref
                            .read(auditSyncControllerProvider.notifier)
                            .syncNow(),
                        child: const Text('Sync now'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                key: const Key('submit-audit'),
                onPressed: reason == null && !_submitting
                    ? () => _confirmSubmit(session)
                    : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
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
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Submit the audit of ${session.roster.room.code}?',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                missing == 0
                    ? 'Every item on the roster was found.'
                    : '${missing == 1 ? '1 item' : '$missing items'} not '
                          'scanned will be recorded as missing.',
                key: const Key('submit-missing'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You cannot scan into this audit after submitting.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('submit-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Submit'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed == true && mounted) await _submit(session.audit);
  }

  Future<void> _submit(LocalAudit audit) async {
    setState(() => _submitting = true);
    try {
      final service = await ref.read(auditSessionServiceProvider.future);
      final detail = await service.complete(audit);
      if (mounted) setState(() => _completed = detail);
    } on AuditFailure catch (f) {
      _say(f.message);
    } on Failure catch (f) {
      _say(f.message);
    } finally {
      ref.read(auditRevisionProvider.notifier).bump();
      if (mounted) setState(() => _submitting = false);
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
    final theme = Theme.of(context);
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
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (session.audit.status == AuditStatus.endedElsewhere)
          const OfflineBanner(
            message:
                'This audit was completed on another device. These scans '
                "can't be submitted.",
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            '${session.found} of ${session.expected} found',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
    final theme = Theme.of(context);
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Icon(Icons.task_alt, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                audit.status == AuditStatus.signedOff
                    ? 'Submitted and signed off'
                    : 'Submitted',
                key: const Key('audit-submitted'),
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        if (audit.counts case final counts?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AuditCountsRow(counts: counts),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
  const _StoredCompleted({required this.audit, required this.roster});

  final LocalAudit audit;
  final Roster roster;

  @override
  Widget build(BuildContext context) {
    final serverId = audit.serverId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Submitted', style: Theme.of(context).textTheme.titleLarge),
        if (audit.counts case final counts?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AuditCountsRow(counts: counts),
          ),
        if (serverId != null)
          ReportActions(
            auditId: serverId,
            roomCode: roster.room.code,
            status: audit.status,
          ),
      ],
    );
  }
}
