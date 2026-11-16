import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock_approvals.dart';
import '../../domain/entities/pending_approval.dart';

/// Rooms the approver can pick from.
final roomsProvider = Provider<List<String>>((ref) => mockRooms);

/// Requests waiting for review, oldest last.
class ApprovalsController extends Notifier<List<PendingApproval>> {
  @override
  List<PendingApproval> build() => mockPendingApprovals(DateTime.now());

  /// Approves [id] for the chosen room and class length.
  // TODO: send the decision to the API once it exists.
  void approve(String id, ApprovalDecision decision) => _remove(id);

  void reject(String id) => _remove(id);

  /// Puts back a request removed by mistake, at its old [index].
  void restore(PendingApproval request, int index) {
    if (state.any((r) => r.id == request.id)) return;
    final list = [...state];
    list.insert(index.clamp(0, list.length), request);
    state = list;
  }

  void _remove(String id) => state = [
    for (final r in state)
      if (r.id != id) r,
  ];
}

final approvalsControllerProvider =
    NotifierProvider<ApprovalsController, List<PendingApproval>>(
      ApprovalsController.new,
    );
