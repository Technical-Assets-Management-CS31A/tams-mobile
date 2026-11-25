import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity.dart';
import '../../domain/entities/audit_failure.dart';
import '../../domain/entities/audit_room.dart';
import '../../domain/repositories/audit_store.dart';
import 'audit_providers.dart';

class AuditRoomsState {
  const AuditRoomsState({
    required this.rooms,
    required this.query,
    this.page = 1,
    this.total = 0,
    this.reachedEnd = false,
    this.cached = false,
    this.notice,
  });

  final List<AuditRoom> rooms;
  final String query;
  final int page;
  final int total;
  final bool reachedEnd;
  final bool cached;
  final String? notice;

  bool get hasMore => !cached && !reachedEnd && rooms.length < total;

  AuditRoomsState adding(RoomsPage next) {
    final ids = {for (final r in rooms) r.id};
    return AuditRoomsState(
      rooms: [
        ...rooms,
        for (final r in next.items)
          if (!ids.contains(r.id)) r,
      ],
      query: query,
      page: next.page,
      total: next.total,
      reachedEnd: next.items.isEmpty,
    );
  }
}

class AuditRoomsController extends AsyncNotifier<AuditRoomsState> {
  String _query = '';
  bool _loadingMore = false;

  @override
  Future<AuditRoomsState> build() async {
    final online = ref.watch(isOnlineProvider);
    final store = await ref.watch(auditStoreProvider.future);
    return _load(store, online, _query);
  }

  Future<AuditRoomsState> _load(
    AuditStore store,
    bool online,
    String query,
  ) async {
    String? notice;
    if (online) {
      try {
        final page = await ref
            .read(auditRepositoryProvider)
            .rooms(query: query);
        await store.cacheRooms(page.items);
        return AuditRoomsState(
          rooms: page.items,
          query: query,
          page: page.page,
          total: page.total,
          reachedEnd: page.items.isEmpty,
        );
      } on AuditFailure catch (f) {
        if (!f.offline) notice = f.message;
      }
    }
    final cached = await store.cachedRooms(query: query);
    if (cached.isEmpty && notice != null) throw AuditFailure(notice);
    return AuditRoomsState(
      rooms: cached,
      query: query,
      cached: true,
      notice: notice,
    );
  }

  Future<void> search(String query) async {
    final q = query.trim();
    _query = q;
    if (state.hasError) state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      final store = await ref.read(auditStoreProvider.future);
      return _load(store, ref.read(isOnlineProvider), q);
    });
    if (!ref.mounted || _query != q) return;
    state = result;
  }

  Future<void> refresh() => search(_query);

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await ref
          .read(auditRepositoryProvider)
          .rooms(query: current.query, page: current.page + 1);
      final store = await ref.read(auditStoreProvider.future);
      await store.cacheRooms(next.items);
      if (ref.mounted && identical(state.value, current)) {
        state = AsyncData(current.adding(next));
      }
    } catch (e) {
      debugPrint('Could not load more rooms: $e');
    } finally {
      _loadingMore = false;
    }
  }
}

final auditRoomsControllerProvider =
    AsyncNotifierProvider<AuditRoomsController, AuditRoomsState>(
      AuditRoomsController.new,
    );
