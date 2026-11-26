import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/token_provider.dart';
import '../../domain/entities/loan_detail.dart';
import 'loan_detail_provider.dart';

/// What Loan History shows: the loans loaded so far for [filter].
class LoanHistory {
  const LoanHistory({
    required this.filter,
    required this.items,
    required this.total,
    required this.page,
    this.reachedEnd = false,
    this.moreFailed = false,
  });

  LoanHistory.first(this.filter, LoansPage page)
    : items = page.items,
      total = page.total,
      page = page.page,
      reachedEnd = page.items.isEmpty,
      moreFailed = false;

  final LoanHistoryFilter filter;
  final List<LoanDetail> items;

  /// Matching loans on the server.
  final int total;

  /// The last page loaded, from 1.
  final int page;

  /// The server sent an empty page: there is nothing after [page].
  final bool reachedEnd;

  /// Loading the page after [page] failed; the screen offers a retry.
  final bool moreFailed;

  /// [items] can stay short of [total] for good (a checkout between page
  /// loads repeats a loan, which is skipped), so an empty page also ends it.
  bool get hasMore => !reachedEnd && items.length < total;

  /// With [next] added, skipping loans already listed (a checkout between
  /// two page loads shifts every page down by one).
  LoanHistory adding(LoansPage next) {
    final ids = {for (final l in items) l.id};
    return LoanHistory(
      filter: filter,
      items: [
        ...items,
        for (final l in next.items)
          if (!ids.contains(l.id)) l,
      ],
      total: next.total,
      page: next.page,
      reachedEnd: next.items.isEmpty,
    );
  }

  LoanHistory withMoreFailed(bool failed) => LoanHistory(
    filter: filter,
    items: items,
    total: total,
    page: page,
    reachedEnd: reachedEnd,
    moreFailed: failed,
  );
}

/// Loan History (FR-2.5): every loan I approved, newest first, filtered by
/// status. Dropped when the screen closes.
class LoanHistoryController extends AsyncNotifier<LoanHistory> {
  LoanHistoryFilter _filter = LoanHistoryFilter.all;

  /// The list a next page is loading for. Tied to the list, not a flag: a
  /// filter change or refresh mid-load shows a new list, which must not
  /// wait on the old one's page.
  LoanHistory? _loadingMoreFor;

  /// The selected filter, also while its first page loads.
  LoanHistoryFilter get filter => _filter;

  @override
  Future<LoanHistory> build() async {
    final repo = ref.watch(loansRepositoryProvider);
    // Signed in or not, not the token itself: a renewed token would
    // otherwise drop every page after the first.
    if (!ref.watch(authTokenProvider.select((t) => t != null))) {
      return LoanHistory.first(_filter, LoansPage.empty);
    }
    return LoanHistory.first(
      _filter,
      await repo.myLoanHistory(filter: _filter),
    );
  }

  /// Shows [filter] from its first page.
  void select(LoanHistoryFilter filter) {
    if (filter == _filter && !state.hasError) return;
    _filter = filter;
    state = const AsyncLoading();
    ref.invalidateSelf();
  }

  /// Reloads the first page, keeping the list on screen meanwhile.
  Future<void> refresh() async {
    if (state.hasError) state = const AsyncLoading();
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The error is in state; the screen shows it with Try again.
    }
  }

  /// Adds the next page. A failure keeps the list and marks it
  /// [LoanHistory.moreFailed]; calling this again retries.
  Future<void> loadMore() async {
    var current = state.value;
    if (current == null || !current.hasMore) return;
    if (identical(_loadingMoreFor, current)) return;
    if (current.moreFailed) {
      current = current.withMoreFailed(false);
      state = AsyncData(current);
    }
    _loadingMoreFor = current;
    try {
      final next = await ref
          .read(loansRepositoryProvider)
          .myLoanHistory(filter: current.filter, page: current.page + 1);
      // A filter change or refresh meanwhile started over; drop this page.
      if (ref.mounted && identical(state.value, current)) {
        state = AsyncData(current.adding(next));
      }
    } catch (e) {
      debugPrint('Could not load more loans: $e');
      if (ref.mounted && identical(state.value, current)) {
        state = AsyncData(current.withMoreFailed(true));
      }
    } finally {
      if (identical(_loadingMoreFor, current)) _loadingMoreFor = null;
    }
  }
}

final loanHistoryProvider =
    AsyncNotifierProvider.autoDispose<LoanHistoryController, LoanHistory>(
      LoanHistoryController.new,
    );
