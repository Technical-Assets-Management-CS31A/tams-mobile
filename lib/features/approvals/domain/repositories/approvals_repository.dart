import '../../../../core/errors/failures.dart';
import '../entities/pending_approval.dart';

abstract interface class ApprovalsRepository {
  /// Requests waiting for my decision, oldest first.
  Future<PendingApprovals> pending();

  Future<void> approve(String id, ApprovalDecision decision);

  Future<void> decline(String id);
}

/// A failed approve or decline. [requestGone] means the request can't be
/// decided any more (timed out, already decided, or not found), so it should
/// leave the list.
class ApprovalFailure extends Failure {
  const ApprovalFailure(super.message, {this.code, this.requestGone = false});

  /// [code] when the request's 120 s ran out before the decision arrived.
  static const expired = 'APPROVAL_EXPIRED';

  final String? code;
  final bool requestGone;
}
