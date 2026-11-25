import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../domain/entities/audit.dart';
import '../controllers/audit_providers.dart';
import '../controllers/audit_reports.dart';

class ReportActions extends ConsumerStatefulWidget {
  const ReportActions({
    super.key,
    required this.auditId,
    required this.roomCode,
    required this.status,
    this.onSignedOff,
  });

  final String auditId;
  final String roomCode;
  final AuditStatus status;
  final ValueChanged<ServerAudit>? onSignedOff;

  @override
  ConsumerState<ReportActions> createState() => _ReportActionsState();
}

class _ReportActionsState extends ConsumerState<ReportActions> {
  String? _busy;

  Future<void> _run(String action, Future<void> Function() call) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      await call();
    } on Failure catch (f) {
      _say(f.message);
    } catch (_) {
      _say('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Rect? _origin() {
    final box = context.findRenderObject();
    return box is RenderBox ? box.localToGlobal(Offset.zero) & box.size : null;
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final canSignOff = ref.watch(canSignOffProvider);
    final reports = ref.read(auditReportsProvider);
    final enabled = online && _busy == null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          key: Key('open-report-${widget.auditId}'),
          onPressed: enabled
              ? () => _run(
                  'open',
                  () => reports.open(widget.auditId, widget.roomCode),
                )
              : null,
          icon: _icon('open', Icons.picture_as_pdf_outlined),
          label: const Text('Open report'),
        ),
        OutlinedButton.icon(
          key: Key('share-report-${widget.auditId}'),
          onPressed: enabled
              ? () => _run(
                  'share',
                  () => reports.share(
                    widget.auditId,
                    widget.roomCode,
                    origin: _origin(),
                  ),
                )
              : null,
          icon: _icon('share', Icons.ios_share),
          label: const Text('Share'),
        ),
        if (canSignOff && widget.status == AuditStatus.completed)
          FilledButton.icon(
            key: Key('sign-off-${widget.auditId}'),
            onPressed: enabled ? _signOff : null,
            icon: _icon('sign-off', Icons.verified_outlined),
            label: const Text('Sign off'),
          ),
        if (!online)
          Text(
            'Connect to the internet to get the report.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _icon(String action, IconData icon) => _busy == action
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon);

  Future<void> _signOff() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign off this audit?'),
        content: const Text(
          'Signing off confirms the results. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('sign-off-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign off'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run('sign-off', () async {
      final audit = await ref
          .read(auditRepositoryProvider)
          .signOff(widget.auditId);
      widget.onSignedOff?.call(audit);
      _say('Audit signed off.');
    });
  }
}
