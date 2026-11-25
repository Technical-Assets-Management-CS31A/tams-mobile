import 'dart:async';

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

  Duration get _limit => ref.read(auditRoomsTimeoutProvider);

  String get _timedOut =>
      'The server took longer than ${_limit.inSeconds} seconds to answer.';

  @override
  Future<AuditRoomsState> build() {
    final online = ref.watch(isOnlineProvider);
    ref.watch(auditRoomsTimeoutProvider);
    return _load(ref.watch(auditStoreProvider.future), online, _query);
  }

  Future<AuditRoomsState> _load(
    Future<AuditStore> pendingStore,
    bool online,
    String query,
  ) async {
    try {
      final store = await pendingStore.timeout(
        _limit,
        onTimeout: () => throw const AuditFailure(
          "Couldn't open the rooms saved on this phone.",
        ),
      );
      String? notice;
      if (online) {
        try {
          final page = await ref
              .read(auditRepositoryProvider)
              .rooms(query: query)
              .timeout(_limit);
          await store.cacheRooms(page.items);
          return AuditRoomsState(
            rooms: page.items,
            query: query,
            page: page.page,
            total: page.total,
            reachedEnd: page.items.isEmpty,
          );
        } on TimeoutException {
          debugPrint('Rooms: gave up after ${_limit.inSeconds} s.');
          notice = _timedOut;
        } on AuditFailure catch (f) {
          // The phone has a network but the server failed or is out of
          // reach, so say why instead of quietly showing saved rooms.
          debugPrint('Rooms: request failed (${f.code ?? '-'}): ${f.message}');
          notice = f.message;
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
    } on AuditFailure {
      rethrow;
    } catch (e, stack) {
      debugPrint('Rooms: could not load: $e\n$stack');
      rethrow;
    }
  }

  Future<void> search(String query) async {
    final q = query.trim();
    _query = q;
    if (state.hasError) state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => _load(
        ref.read(auditStoreProvider.future),
        ref.read(isOnlineProvider),
        q,
      ),
    );
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
          .rooms(query: current.query, page: current.page + 1)
          .timeout(_limit);
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
      // Riverpod would otherwise retry a failed load up to 10 times behind
      // the error screen. The screen offers Try again, and a change in
      // connectivity reloads the list.
      retry: (_, _) => null,
    );
