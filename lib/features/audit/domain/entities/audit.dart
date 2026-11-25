enum AuditStatus {
  inProgress('IN_PROGRESS'),
  completed('COMPLETED'),
  signedOff('SIGNED_OFF'),
  endedElsewhere('ENDED_ELSEWHERE');

  const AuditStatus(this.label);

  final String label;

  static AuditStatus? tryParse(Object? value) {
    for (final s in values) {
      if (s.label == value) return s;
    }
    return null;
  }
}

class AuditCounts {
  const AuditCounts({
    required this.expected,
    required this.matched,
    required this.missing,
    required this.misplaced,
    required this.unknown,
  });

  final int expected;
  final int matched;
  final int missing;
  final int misplaced;
  final int unknown;
}

class LocalAudit {
  const LocalAudit({
    required this.localId,
    required this.userId,
    required this.roomId,
    required this.status,
    required this.startedAt,
    this.serverId,
    this.completedAt,
    this.counts,
  });

  final String localId;
  final String? serverId;
  final String userId;
  final String roomId;
  final AuditStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final AuditCounts? counts;

  bool get isOpen => status == AuditStatus.inProgress;
}

class ServerAudit {
  const ServerAudit({
    required this.id,
    required this.roomId,
    required this.status,
    required this.startedAt,
    this.startedByUserId,
    this.completedAt,
    this.signedOffAt,
    this.counts,
  });

  final String id;
  final String roomId;
  final AuditStatus status;
  final String? startedByUserId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? signedOffAt;
  final AuditCounts? counts;
}
