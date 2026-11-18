import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/approvals_remote_datasource.dart';
import '../../data/repositories/approvals_repository_impl.dart';
import '../../domain/entities/pending_approval.dart';
import '../../domain/repositories/approvals_repository.dart';

final approvalsRepositoryProvider = Provider<ApprovalsRepository>(
  (ref) => ApprovalsRepositoryImpl(
    ApprovalsRemoteDataSource(ref.watch(dioProvider)),
  ),
);

/// Requests waiting for my decision, oldest first, from
/// `GET /approvals/pending`.
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

  Future<void> _decide(String id, Future<void> Function() call) async {
    try {
      await call();
    } on ApprovalFailure catch (f) {
      if (f.requestGone) _remove(id);
      rethrow;
    }
    _remove(id);
  }

  void _remove(String id) {
    final current = state.value;
    if (current != null) state = AsyncData(current.without(id));
  }
}

final approvalsControllerProvider =
    AsyncNotifierProvider<ApprovalsController, PendingApprovals>(
      ApprovalsController.new,
    );
