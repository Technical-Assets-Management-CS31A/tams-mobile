import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/clock.dart';
import '../../data/datasources/approvals_remote_datasource.dart';
import '../../data/repositories/approvals_repository_impl.dart';
import '../../domain/entities/pending_approval.dart';
import '../../domain/repositories/approvals_repository.dart';

final approvalsRepositoryProvider = Provider<ApprovalsRepository>(
  (ref) => ApprovalsRepositoryImpl(
    ApprovalsRemoteDataSource(
      ref.watch(dioProvider),
      now: ref.watch(clockProvider),
    ),
  ),
);

/// Requests waiting for my decision, oldest first, from
/// `GET /approvals/pending`.
///
/// Requests whose 120 s run out stay in the list, shown as expired, until
/// they are dismissed or the list is reloaded (the server drops them).
class ApprovalsController extends AsyncNotifier<PendingApprovals> {
  ApprovalsRepository get _repo => ref.read(approvalsRepositoryProvider);

  @override
  Future<PendingApprovals> build() =>
      ref.watch(approvalsRepositoryProvider).pending();

  /// Reloads the list, keeping the current one on screen meanwhile.
  /// Errors end up in [state].
  Future<void> refresh() async {
    if (state.hasError) state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.pending);
  }

  /// Approves [id] for the chosen room and class length. Throws a
  /// [Failure] if the server refuses; the request stays unless it can't be
  /// decided any more.
  Future<void> approve(String id, ApprovalDecision decision) =>
      _decide(id, () => _repo.approve(id, decision));

  /// Declines [id]; the kiosk denies the borrow. Throws like [approve].
  Future<void> decline(String id) => _decide(id, () => _repo.decline(id));

  /// Takes an expired request off the list.
  void dismiss(String id) => _update((list) => list.without(id));

  Future<void> _decide(String id, Future<void> Function() call) async {
    try {
      await call();
    } on ApprovalFailure catch (f) {
      if (f.code == ApprovalFailure.expired) {
        // Keep it on screen as expired so the instructor sees why.
        final now = ref.read(clockProvider)();
        _update((list) => list.updating(id, (r) => r.expiredAt(now)));
      } else if (f.requestGone) {
        _update((list) => list.without(id));
      }
      rethrow;
    }
    _update((list) => list.without(id));
  }

  void _update(PendingApprovals Function(PendingApprovals) change) {
    final current = state.value;
    if (current != null) state = AsyncData(change(current));
  }
}

final approvalsControllerProvider =
    AsyncNotifierProvider<ApprovalsController, PendingApprovals>(
      ApprovalsController.new,
    );
