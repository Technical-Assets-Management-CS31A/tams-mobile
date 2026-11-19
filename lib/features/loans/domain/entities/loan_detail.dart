/// One row of a loan's transaction ledger (PRD 7.3), e.g. CHECKED_OUT.
class LedgerEntry {
  const LedgerEntry({required this.event, required this.occurredAt});

  final String event;
  final DateTime occurredAt;
}

/// A loan as `GET /loans/{id}` returns it (PRD 7.6 `LoanDto` plus the
/// ledger): what an alert is about.
class LoanDetail {
  const LoanDetail({
    required this.id,
    required this.loanNo,
    required this.status,
    required this.assetName,
    required this.assetCode,
    required this.checkedOutAt,
    this.custodyState,
    this.studentName,
    this.studentNo,
    this.sectionCode,
    this.eventTitle,
    this.borrowerName,
    this.roomCode,
    this.roomName,
    this.transitDeadlineAt,
    this.verifiedAt,
    this.dueAt,
    this.overdueAt,
    this.missingAt,
    this.returnedAt,
    this.photoUrl,
    this.lateArrivalWarningNo,
    this.ledger = const [],
  });

  final String id;
  final String loanNo;

  /// ACTIVE, OVERDUE, RETURNED, MISSING or CANCELLED.
  final String status;

  /// AWAITING_ARRIVAL, VERIFIED, ANOMALY or NOT_REQUIRED.
  final String? custodyState;
  final String assetName;
  final String assetCode;
  final String? studentName;
  final String? studentNo;
  final String? sectionCode;

  /// Set for event loans, which have a coordinator instead of a student.
  final String? eventTitle;
  final String? borrowerName;
  final String? roomCode;
  final String? roomName;
  final DateTime checkedOutAt;
  final DateTime? transitDeadlineAt;
  final DateTime? verifiedAt;
  final DateTime? dueAt;
  final DateTime? overdueAt;
  final DateTime? missingAt;
  final DateTime? returnedAt;

  /// The checkout photo. Needs the auth header to load.
  final String? photoUrl;
  final int? lateArrivalWarningNo;

  /// Oldest first.
  final List<LedgerEntry> ledger;

  bool get isOpen => status == 'ACTIVE' || status == 'OVERDUE';

  /// "Computer Lab 1 (CL1)", or just the code when there's no name.
  String? get room {
    final code = roomCode;
    final name = roomName;
    if (code == null) return name;
    return name == null || name == code ? code : '$name ($code)';
  }
}
