import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../../../core/theme/brand.dart';
import '../../domain/entities/audit.dart';
import '../controllers/audit_providers.dart';
import '../controllers/audit_reports.dart';

/// Open, share and sign off a submitted audit's report. Sign off is the
/// main action when it's available, otherwise Open report is.
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
    final signOff = canSignOff && widget.status == AuditStatus.completed;

    final openPressed = enabled
        ? () =>
              _run('open', () => reports.open(widget.auditId, widget.roomCode))
        : null;
    final openIcon = _icon('open', Icons.picture_as_pdf_outlined, signOff);
    const openLabel = Text('Open report');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: signOff
                  ? TextButton.icon(
                      key: Key('open-report-${widget.auditId}'),
                      onPressed: openPressed,
                      style: BrandButtons.subtle(),
                      icon: openIcon,
                      label: openLabel,
                    )
                  : FilledButton.icon(
                      key: Key('open-report-${widget.auditId}'),
                      onPressed: openPressed,
                      style: BrandButtons.primary(),
                      icon: openIcon,
                      label: openLabel,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextButton.icon(
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
                style: BrandButtons.subtle(),
                icon: _icon('share', Icons.ios_share_rounded, true),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
        if (signOff) ...[
          const SizedBox(height: 10),
          FilledButton.icon(
            key: Key('sign-off-${widget.auditId}'),
            onPressed: enabled ? _signOff : null,
            style: BrandButtons.primary(),
            icon: _icon('sign-off', Icons.verified_outlined, false),
            label: const Text('Sign off'),
          ),
        ],
        if (!online) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 16,
                color: BrandColors.faint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Connect to the internet to get the report.',
                  style: brandText(13, color: BrandColors.muted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// [onLight] picks the spinner colour: blue on grey buttons, white on
  /// blue ones.
  Widget _icon(String action, IconData icon, bool onLight) => _busy == action
      ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: onLight ? BrandColors.primary : Colors.white,
          ),
        )
      : Icon(icon, size: 18);

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
