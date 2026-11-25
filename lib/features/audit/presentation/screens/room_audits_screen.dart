import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../controllers/audit_providers.dart';
import '../controllers/audit_reports.dart';
import '../widgets/report_actions.dart';

final _cachedRoomProvider = FutureProvider.autoDispose
    .family<AuditRoom?, String>((ref, roomId) async {
      final store = await ref.watch(auditStoreProvider.future);
      for (final r in await store.cachedRooms()) {
        if (r.id == roomId) return r;
      }
      return (await store.roster(roomId))?.room;
    });

class RoomAuditsScreen extends ConsumerWidget {
  const RoomAuditsScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(_cachedRoomProvider(roomId)).value;
    final online = ref.watch(isOnlineProvider);
    final audits = ref.watch(roomAuditsProvider(roomId));
    final now = ref.watch(clockProvider)();
    final code = room?.code ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(room?.label ?? 'Room')),
      body: !online
          ? const EmptyState(
              icon: Icons.cloud_off_outlined,
              title: "You're offline",
              message: 'Connect to the internet to see past audits.',
            )
          : RefreshIndicator(
              onRefresh: () => ref.refresh(roomAuditsProvider(roomId).future),
              child: switch (audits) {
                AsyncValue(:final value?) when value.isEmpty => ListView(
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.history,
                      title: 'No completed audits',
                      message:
                          'Audits of this room show here once they are '
                          'submitted.',
                    ),
                  ],
                ),
                AsyncValue(:final value?) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: value.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _AuditCard(
                    audit: value[i],
                    roomCode: code,
                    now: now,
                    onSignedOff: () => ref.invalidate(roomAuditsProvider),
                  ),
                ),
                AsyncValue(:final error?) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: "Couldn't load past audits",
                      message: error is Failure
                          ? error.message
                          : 'Something went wrong. Please try again.',
                    ),
                  ],
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({
    required this.audit,
    required this.roomCode,
    required this.now,
    required this.onSignedOff,
  });

  final ServerAudit audit;
  final String roomCode;
  final DateTime now;
  final VoidCallback onSignedOff;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = audit.counts;
    final when = audit.completedAt ?? audit.startedAt;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Completed ${formatDateTime(when, now: now)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (audit.status == AuditStatus.signedOff)
                  Icon(Icons.verified, color: theme.colorScheme.primary),
              ],
            ),
            if (counts != null)
              Text(
                '${counts.matched} of ${counts.expected} found · '
                '${counts.missing} missing · ${counts.misplaced} misplaced · '
                '${counts.unknown} unknown',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (audit.status == AuditStatus.signedOff)
              Text('Signed off', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            ReportActions(
              auditId: audit.id,
              roomCode: roomCode,
              status: audit.status,
              onSignedOff: (_) => onSignedOff(),
            ),
          ],
        ),
      ),
    );
  }
}
