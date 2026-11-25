import '../../../../core/errors/failures.dart';

class AuditFailure extends Failure {
  const AuditFailure(super.message, {this.code, this.offline = false});

  static const syncInProgress = 'SYNC_IN_PROGRESS';
  static const notInProgress = 'AUDIT_NOT_IN_PROGRESS';
  static const notCompleted = 'AUDIT_NOT_COMPLETED';
  static const noRoster = 'NO_ROSTER';

  final String? code;
  final bool offline;
}
