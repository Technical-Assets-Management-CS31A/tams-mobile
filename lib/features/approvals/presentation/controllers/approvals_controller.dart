import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/token_provider.dart';
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
/// they are dismissed, even across reloads (a new request's push reloads
/// the list, and the server leaves expired requests out).
///
/// Empty while signed out, so the next user never sees the previous one's
/// requests or freeze banner. A Riverpod-paused copy (its screen on a
/// hidden tab) only rebuilds when read, so the app also reads it at
/// sign-out (see `App`).
class ApprovalsController extends AsyncNotifier<PendingApprovals> {
  ApprovalsRepository get _repo => ref.read(approvalsRepositoryProvider);

  // Also runs again when a push invalidates the provider; [state] still
  // holds the previous list then.
  @override
  FutureOr<PendingApprovals> build() {
    final repo = ref.watch(approvalsRepositoryProvider);
    // Signed in or not, not the token itself: a renewed token mustn't
    // reload. Not async, so a sign-out empties the list at once.
    if (!ref.watch(authTokenProvider.select((t) => t != null))) {
      return PendingApprovals.empty;
    }
    return _load(repo);
  }

  /// Reloads the list, keeping the current one on screen meanwhile.
  /// Errors end up in [state]. Does nothing when signed out.
  Future<void> refresh() async {
    final token = ref.read(authTokenProvider);
    if (token == null) return;
    if (state.hasError) state = const AsyncLoading();
    final result = await AsyncValue.guard(() => _load(_repo));
    // Signed out (or in as someone else) meanwhile: build() has already
    // emptied the list, and these requests belong to the previous session.
    if (!ref.mounted || ref.read(authTokenProvider) != token) return;
    state = result;
  }

  /// Fetches the list, keeping the expired requests on screen.
  Future<PendingApprovals> _load(ApprovalsRepository repo) async {
    // Read before the await: ref can't be used once the provider is disposed.
    final shown = state.value;
    final clock = ref.read(clockProvider);
    final fresh = await repo.pending();
    return shown == null ? fresh : fresh.keepingExpired(shown, clock());
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
