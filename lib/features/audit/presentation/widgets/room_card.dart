import 'package:flutter/material.dart';

import '../../../../core/utils/time_format.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../../domain/entities/roster.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final roster = this.roster;
    final audit = this.audit;
    final open = audit?.isOpen ?? false;
    final endedElsewhere = audit?.status == AuditStatus.endedElsewhere;
    final canStart = open || online || roster != null;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (room.place.isNotEmpty)
                          Text(room.place, style: muted),
                      ],
                    ),
                  ),
                  if (open)
                    _Tag(
                      'In progress',
                      bg: colors.tertiaryContainer,
                      fg: colors.onTertiaryContainer,
                    )
                  else if (endedElsewhere)
                    _Tag(
                      'Completed elsewhere',
                      bg: colors.errorContainer,
                      fg: colors.onErrorContainer,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    roster == null
                        ? Icons.cloud_download_outlined
                        : Icons.offline_pin_outlined,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      roster == null
                          ? 'Roster not downloaded'
                          : '${_items(roster.itemCount)} · downloaded '
                                '${formatAge(roster.downloadedAt, now: now)}',
                      style: muted,
                    ),
                  ),
                ],
              ),
              if (!canStart) ...[
                const SizedBox(height: 4),
                Text(
                  'Download the roster while online to audit this room '
                  'offline.',
                  style: muted?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    key: Key('download-${room.id}'),
                    onPressed: online && !busy ? onDownload : null,
                    icon: Icon(
                      roster == null ? Icons.download : Icons.refresh,
                      size: 18,
                    ),
                    label: Text(
                      roster == null ? 'Download roster' : 'Download again',
                    ),
                  ),
                  const Spacer(),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (endedElsewhere)
                    OutlinedButton(
                      key: Key('discard-${room.id}'),
                      onPressed: onDiscard,
                      child: const Text('Discard'),
                    )
                  else
                    FilledButton.icon(
                      key: Key('start-${room.id}'),
                      onPressed: canStart ? onStart : null,
                      icon: Icon(
                        open ? Icons.play_arrow : Icons.qr_code_scanner,
                        size: 18,
                      ),
                      label: Text(open ? 'Resume' : 'Start'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _items(int n) => n == 1 ? '1 item' : '$n items';
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}
