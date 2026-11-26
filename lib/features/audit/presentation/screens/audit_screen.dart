import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../../../core/theme/brand.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../routing/locations.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../controllers/audit_providers.dart';
import '../controllers/audit_rooms_controller.dart';
import '../controllers/audit_sync_controller.dart';
import '../widgets/audit_status_bar.dart';
import '../widgets/room_card.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _search = TextEditingController();
  final _busy = <String>{};
  Timer? _debounce;

  AuditRoomsController get _rooms =>
      ref.read(auditRoomsControllerProvider.notifier);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _rooms.search(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final rooms = ref.watch(auditRoomsControllerProvider);
    final overview =
        ref.watch(auditOverviewProvider).value ?? AuditOverview.empty;
    final sync = ref.watch(auditSyncControllerProvider);
    final now = ref.watch(clockProvider)();

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          if (!online)
            const OfflineBanner(
              message:
                  "You're offline. Showing saved rooms; downloading rosters "
                  'needs a connection.',
            )
          else if (rooms.value?.notice case final notice?)
            OfflineBanner(message: '$notice Showing saved rooms.'),
          if (overview.unsynced > 0)
            SyncBar(
              waiting: overview.unsynced,
              online: online,
              syncing: sync.running,
              onSync: () =>
                  ref.read(auditSyncControllerProvider.notifier).syncNow(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _SearchField(controller: _search, onChanged: _onSearch),
          ),
          Expanded(
            child: switch (rooms) {
              AsyncValue(:final value?) => RefreshIndicator(
                onRefresh: _refresh,
                child: value.rooms.isEmpty
                    ? _FillScrollable(
                        child: EmptyState(
                          icon: Icons.meeting_room_outlined,
                          title: value.query.isEmpty
                              ? 'No rooms yet'
                              : 'No rooms match "${value.query}"',
                          message: value.cached
                              ? 'Rooms you have opened while online are saved '
                                    'here for offline audits.'
                              : 'Rooms set up by staff will appear here.',
                        ),
                      )
                    : _list(value, overview, online, now),
              ),
              AsyncValue(:final error?) => RefreshIndicator(
                onRefresh: _refresh,
                child: _FillScrollable(
                  child: EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load rooms",
                    message: error is Failure
                        ? error.message
                        : 'Something went wrong. Please try again.',
                    action: FilledButton(
                      onPressed: _refresh,
                      style: BrandButtons.primary(),
                      child: const Text('Try again'),
                    ),
                  ),
                ),
              ),
              _ => const Center(
                child: CircularProgressIndicator(color: BrandColors.primary),
              ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await _rooms.refresh();
    ref.invalidate(auditOverviewProvider);
  }

  Widget _list(
    AuditRoomsState state,
    AuditOverview overview,
    bool online,
    DateTime now,
  ) {
    final rooms = state.rooms;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: rooms.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == rooms.length && state.moreFailed) {
          return Center(
            child: TextButton.icon(
              key: const ValueKey('rooms-load-more-retry'),
              onPressed: _rooms.loadMore,
              icon: const Icon(Icons.refresh),
              label: const Text("Couldn't load more. Try again"),
            ),
          );
        }
        if (i == rooms.length) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _rooms.loadMore(),
          );
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: BrandColors.primary),
            ),
          );
        }
        final room = rooms[i];
        final audit = overview.audits[room.id];
        return RoomCard(
          key: ValueKey(room.id),
          room: room,
          now: now,
          online: online,
          roster: overview.rosters[room.id],
          audit: audit,
          busy: _busy.contains(room.id),
          onOpen: () => context.push(auditRoomLocation(room.id)),
          onDownload: () => _download(room),
          onStart: () => _start(room),
          onDiscard: audit == null ? null : () => _discard(room, audit),
        );
      },
    );
  }

  Future<void> _run(AuditRoom room, Future<void> Function() action) async {
    if (_busy.contains(room.id)) return;
    setState(() => _busy.add(room.id));
    try {
      await action();
    } on Failure catch (f) {
      _say(f.message);
    } catch (_) {
      _say('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(room.id));
    }
  }

  Future<void> _download(AuditRoom room) => _run(room, () async {
    final revision = ref.read(auditRevisionProvider.notifier);
    final service = await ref.read(auditSessionServiceProvider.future);
    final roster = await service.downloadRoster(room);
    revision.bump();
    final n = roster.items.length;
    _say('Downloaded ${n == 1 ? '1 item' : '$n items'} for ${room.code}.');
  });

  Future<void> _start(AuditRoom room) => _run(room, () async {
    final revision = ref.read(auditRevisionProvider.notifier);
    final online = ref.read(isOnlineProvider);
    final service = await ref.read(auditSessionServiceProvider.future);
    final audit = await service.start(room, online: online);
    revision.bump();
    if (mounted) await context.push(auditScanLocation(audit.localId));
  });

  Future<void> _discard(AuditRoom room, LocalAudit audit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this audit?'),
        content: Text(
          'The audit of ${room.code} was completed on another device. '
          "Scans on this phone that didn't sync will be deleted.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('discard-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(room, () async {
      final revision = ref.read(auditRevisionProvider.notifier);
      final service = await ref.read(auditSessionServiceProvider.future);
      await service.discard(audit);
      revision.bump();
    });
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FillScrollable extends StatelessWidget {
  const _FillScrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: constraints.maxHeight, child: child),
    ),
  );
}

/// Grey filled search box matching the login screen's fields.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: w == 0 ? BorderSide.none : BorderSide(color: c, width: w),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      cursorColor: BrandColors.primary,
      style: brandText(15, weight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Search rooms',
        hintStyle: brandText(15, color: BrandColors.faint),
        filled: true,
        fillColor: BrandColors.field,
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: BrandColors.faint,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: border(Colors.transparent, 0),
        enabledBorder: border(Colors.transparent, 0),
        focusedBorder: border(BrandColors.primary),
      ),
    );
  }
}
