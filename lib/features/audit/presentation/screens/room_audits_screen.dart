import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../../../core/theme/brand.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/time_format.dart';
import '../../../../core/widgets/brand_app_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../controllers/audit_providers.dart';
import '../controllers/audit_reports.dart';
import '../widgets/audit_results.dart';
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

    return BrandPage(
      title: room?.label ?? 'Room',
      subtitle: 'Past audits',
      body: !online
          ? const EmptyState(
              icon: Icons.cloud_off_outlined,
              title: "You're offline",
              message: 'Connect to the internet to see past audits.',
            )
          : RefreshIndicator(
              color: BrandColors.primary,
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
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                _ => const Center(
                  child: CircularProgressIndicator(color: BrandColors.primary),
                ),
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
    final counts = audit.counts;
    final when = audit.completedAt ?? audit.startedAt;
    final signedOff = audit.status == AuditStatus.signedOff;
    return BrandCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: signedOff
                      ? BrandColors.successBg
                      : BrandColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  signedOff ? Icons.verified_rounded : Icons.task_alt_rounded,
                  size: 22,
                  color: signedOff ? BrandColors.success : BrandColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Completed ${formatDateTime(when, now: now)}',
                      style: brandText(15, weight: FontWeight.w600, ls: -0.2),
                    ),
                    if (counts != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${counts.matched} of ${counts.expected} found',
                        style: brandText(13, color: BrandColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (signedOff)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: BrandPill(
                    'Signed off',
                    color: BrandColors.success,
                    background: BrandColors.successBg,
                  ),
                ),
            ],
          ),
          if (counts != null) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Count('Missing', counts.missing, BrandColors.error),
                _Count('Misplaced', counts.misplaced, BrandColors.warning),
                _Count('Unknown', counts.unknown, BrandColors.muted),
              ],
            ),
          ],
          const SizedBox(height: 14),
          ReportActions(
            auditId: audit.id,
            roomCode: roomCode,
            status: audit.status,
            onSignedOff: (_) => onSignedOff(),
          ),
        ],
      ),
    );
  }
}

/// "2 missing" in [color], or greyed out when there are none.
class _Count extends StatelessWidget {
  const _Count(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final none = value == 0;
    return BrandPill(
      '$value ${label.toLowerCase()}',
      color: none ? BrandColors.faint : color,
      background: none ? BrandColors.field : color.withValues(alpha: 0.1),
    );
  }
}
