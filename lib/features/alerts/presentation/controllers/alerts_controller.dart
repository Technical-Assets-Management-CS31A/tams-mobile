import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/token_provider.dart';
import '../../../../core/utils/clock.dart';
import '../../data/datasources/alerts_remote_datasource.dart';
import '../../data/repositories/alerts_repository_impl.dart';
import '../../domain/entities/alert.dart';
import '../../domain/repositories/alerts_repository.dart';

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => AlertsRepositoryImpl(AlertsRemoteDataSource(ref.watch(dioProvider))),
);

/// My warnings, anomalies and overdue notices, newest first, from
/// `GET /notifications` (FR-2.6, US-05, US-07). A notice push reloads it.
class AlertsController extends AsyncNotifier<AlertsFeed> {
  AlertsRepository get _repo => ref.read(alertsRepositoryProvider);

  bool _loadingMore = false;

  // Rebuilt on sign-in and sign-out, so one user never sees another's
  // alerts on a shared phone.
  @override
  Future<AlertsFeed> build() async {
    final repo = ref.watch(alertsRepositoryProvider);
    if (ref.watch(authTokenProvider) == null) return AlertsFeed.empty;
    return AlertsFeed.first(await repo.list());
  }

  /// Reloads the first page, keeping the current list on screen meanwhile.
  /// Errors end up in [state]. Does nothing when signed out.
  Future<void> refresh() async {
    final token = ref.read(authTokenProvider);
    if (token == null) return;
    if (state.hasError) state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () async => AlertsFeed.first(await _repo.list()),
    );
    // Signed out (or in as someone else) meanwhile: build() has already
    // reset the list, and these alerts belong to the previous session.
    if (!ref.mounted || ref.read(authTokenProvider) != token) return;
    state = result;
  }

  /// Adds the next page. A failure leaves the list as it is; scrolling to
  /// the end again retries.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await _repo.list(page: current.page + 1);
      final latest = state.value;
      // A refresh meanwhile started the list over; this page is stale.
      if (latest != null && identical(latest, current)) {
        state = AsyncData(latest.adding(next));
      }
    } catch (e) {
      debugPrint('Could not load more alerts: $e');
    } finally {
      _loadingMore = false;
    }
  }

  /// Marks [id] read on screen at once, then on the server. If the server
  /// call fails the alert simply shows as unread again on the next reload.
  Future<void> markRead(String id) async {
    final current = state.value;
    if (current == null) return;
    final updated = current.markingRead(id, ref.read(clockProvider)());
    if (identical(updated, current)) return;
    state = AsyncData(updated);
    try {
      await _repo.markRead(id);
    } catch (e) {
      debugPrint('Could not mark alert $id read: $e');
    }
  }
}

final alertsControllerProvider =
    AsyncNotifierProvider<AlertsController, AlertsFeed>(AlertsController.new);
