import 'package:flutter/material.dart';

import '../../../../core/theme/brand.dart';
import '../../../../core/utils/time_format.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../../domain/entities/roster.dart';

/// One room on the Audit tab, in the login screen's flat style: a
/// hairline-bordered white card with the room, its roster state, and the
/// download and start buttons side by side.
class RoomCard extends StatelessWidget {
  const RoomCard({
    super.key,
    required this.room,
    required this.now,
    required this.online,
    this.roster,
    this.audit,
    this.busy = false,
    this.onOpen,
    this.onDownload,
    this.onStart,
    this.onDiscard,
  });

  final AuditRoom room;
  final DateTime now;
  final bool online;
  final RosterInfo? roster;
  final LocalAudit? audit;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback? onDownload;
  final VoidCallback? onStart;
  final VoidCallback? onDiscard;

  static final _radius = BorderRadius.circular(16);

  @override
  Widget build(BuildContext context) {
    final roster = this.roster;
    final audit = this.audit;
    final open = audit?.isOpen ?? false;
    final endedElsewhere = audit?.status == AuditStatus.endedElsewhere;
    final canStart = open || online || roster != null;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: _radius,
        side: BorderSide(
          color: open
              ? BrandColors.primary.withValues(alpha: 0.35)
              : BrandColors.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _RoomIcon(storage: room.isStorage, active: open),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The code as the header and the name under it,
                        // such as STORE-1 over Equipment Storage. Both wrap
                        // rather than cut off.
                        Text(
                          room.code,
                          style: brandText(
                            16,
                            weight: FontWeight.w600,
                            ls: -0.3,
                          ).copyWith(height: 1.3),
                        ),
                        if (room.name.isNotEmpty && room.name != room.code) ...[
                          const SizedBox(height: 2),
                          Text(
                            room.name,
                            style: brandText(
                              13,
                              color: BrandColors.muted,
                            ).copyWith(height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (open)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: BrandPill('In progress'),
                    )
                  else if (endedElsewhere)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: BrandPill(
                        'Completed elsewhere',
                        color: BrandColors.error,
                        background: BrandColors.errorBg,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _RosterLine(roster: roster, now: now),
              if (!canStart) ...[
                const SizedBox(height: 10),
                const _Warning(
                  'Download the roster while online to audit this room '
                  'offline.',
                ),
              ],
              const SizedBox(height: 14),
              _ActionRow(
                download: TextButton.icon(
                  key: Key('download-${room.id}'),
                  onPressed: online && !busy ? onDownload : null,
                  style: _compact(BrandButtons.subtle()),
                  icon: Icon(
                    roster == null
                        ? Icons.download_rounded
                        : Icons.refresh_rounded,
                    size: _iconSize,
                  ),
                  label: Text(_downloadLabel),
                ),
                downloadLabel: _downloadLabel,
                main: _mainAction(open, endedElsewhere, canStart),
                mainLabel: _mainLabel(open, endedElsewhere),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _downloadLabel =>
      roster == null ? 'Download roster' : 'Download again';

  static String _mainLabel(bool open, bool endedElsewhere) => endedElsewhere
      ? 'Discard'
      : open
      ? 'Resume'
      : 'Start';

  Widget _mainAction(bool open, bool endedElsewhere, bool canStart) {
    if (busy) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: BrandColors.primary,
            ),
          ),
        ),
      );
    }
    if (endedElsewhere) {
      return OutlinedButton(
        key: Key('discard-${room.id}'),
        onPressed: onDiscard,
        style: _compact(BrandButtons.danger()),
        child: Text(_mainLabel(open, endedElsewhere)),
      );
    }
    return FilledButton.icon(
      key: Key('start-${room.id}'),
      onPressed: canStart ? onStart : null,
      style: _compact(BrandButtons.primary()),
      icon: Icon(
        open ? Icons.play_arrow_rounded : Icons.qr_code_scanner_rounded,
        size: _iconSize,
      ),
      label: Text(_mainLabel(open, endedElsewhere)),
    );
  }
}

const _iconSize = 16.0;
const _hPad = 12.0;
const _gap = 10.0;

/// Tighter side padding than the shared style, so both labels fit whole.
ButtonStyle _compact(ButtonStyle style) => style.copyWith(
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: _hPad),
  ),
);

/// The download and main buttons side by side, download as wide as its
/// label and the main one taking the rest. When both labels can't fit in
/// full, such as on a narrow phone or with large system text, the buttons
/// stack full-width instead of cutting a label short.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.download,
    required this.downloadLabel,
    required this.main,
    required this.mainLabel,
  });

  final Widget download;
  final String downloadLabel;
  final Widget main;
  final String mainLabel;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = brandText(14, weight: FontWeight.w600);
    double width(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      // Padding both sides, the icon, and the button's icon-to-label gap.
      return w + _hPad * 2 + _iconSize + 8;
    }

    // A little slack for rounding and font hinting.
    final needed = width(downloadLabel) + width(mainLabel) + _gap + 8;

    return LayoutBuilder(
      builder: (context, box) => needed <= box.maxWidth
          ? Row(
              children: [
                download,
                const SizedBox(width: _gap),
                Expanded(child: main),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [main, const SizedBox(height: 8), download],
            ),
    );
  }
}

class _RoomIcon extends StatelessWidget {
  const _RoomIcon({required this.storage, required this.active});

  final bool storage;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: active
          ? BrandColors.primary
          : BrandColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(
      storage ? Icons.inventory_2_outlined : Icons.meeting_room_outlined,
      size: 22,
      color: active ? Colors.white : BrandColors.primary,
    ),
  );
}

/// Whether the room's roster is on this phone, and how fresh it is.
class _RosterLine extends StatelessWidget {
  const _RosterLine({required this.roster, required this.now});

  final RosterInfo? roster;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final roster = this.roster;
    final saved = roster != null;
    return Row(
      children: [
        Icon(
          saved ? Icons.offline_pin_rounded : Icons.cloud_download_outlined,
          size: 16,
          color: saved ? BrandColors.success : BrandColors.faint,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            saved
                ? '${_items(roster.itemCount)} · downloaded '
                      '${formatAge(roster.downloadedAt, now: now)}'
                : 'Roster not downloaded',
            style: brandText(13, color: BrandColors.muted),
          ),
        ),
      ],
    );
  }

  static String _items(int n) => n == 1 ? '1 item' : '$n items';
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: BrandColors.errorBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: BrandColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: brandText(
              12.5,
              color: BrandColors.error,
            ).copyWith(height: 1.4),
          ),
        ),
      ],
    ),
  );
}
