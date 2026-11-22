/// One row of a loan's transaction ledger (PRD 7.3), e.g. CHECKED_OUT.
class LedgerEntry {
  const LedgerEntry({required this.event, required this.occurredAt});

  final String event;
  final DateTime occurredAt;
}

/// Where a loan I approved stands right now (PRD FR-2.5, FR-4.2): the
/// columns of the status board, plus how a closed loan ended.
enum LoanLiveStatus {
  atCounter('At Counter'),
  inTransit('In Transit'),
  verifiedInRoom('Verified in Room'),
  anomaly('Anomaly'),
  overdue('Overdue'),
  missing('Missing'),
  returned('Returned'),
  cancelled('Cancelled');

  const LoanLiveStatus(this.label);

  final String label;

  bool get isUrgent => this == overdue || this == missing || this == anomaly;
}

/// A loan as `GET /loans` and `GET /loans/{id}` return it (PRD 7.6
/// `LoanDto`, plus the ledger for the detail): what an alert is about and
/// a row of My Loans.
class LoanDetail {
  const LoanDetail({
    required this.id,
    required this.loanNo,
    required this.status,
    required this.assetName,
    required this.assetCode,
    required this.checkedOutAt,
    this.custodyState,
    this.assetStatus,
    this.studentName,
    this.studentNo,
    this.sectionCode,
    this.eventTitle,
    this.borrowerName,
    this.roomCode,
    this.roomName,
    this.transitDeadlineAt,
    this.verifiedAt,
    this.classEndsAt,
    this.graceMinutes,
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

  /// The item's own status: IN_TRANSIT, IN_ROOM_VERIFIED, LOCATION_ANOMALY,
  /// AT_COUNTER, OVERDUE, MISSING...
  final String? assetStatus;
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

  /// When the class (or event) ends; [dueAt] is this plus [graceMinutes].
  final DateTime? classEndsAt;

  /// Return grace after class, 15 to 30 minutes (PRD 4.1).
  final int? graceMinutes;

  /// Checkout + class length + grace: past it the loan is overdue (FR-6.3).
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

  /// The status as of [now]. An open loan past [dueAt] is overdue at once,
  /// before the backend's sweep gets to it.
  LoanLiveStatus liveStatus(DateTime now) {
    switch (status) {
      case 'RETURNED':
        return LoanLiveStatus.returned;
      case 'CANCELLED':
        return LoanLiveStatus.cancelled;
      case 'MISSING':
        return LoanLiveStatus.missing;
      case 'OVERDUE':
        return LoanLiveStatus.overdue;
    }
    if (dueAt case final due? when !now.isBefore(due)) {
      return LoanLiveStatus.overdue;
    }
    if (custodyState == 'ANOMALY' || assetStatus == 'LOCATION_ANOMALY') {
      return LoanLiveStatus.anomaly;
    }
    // Tapped at the kiosk again, e.g. while being returned.
    if (assetStatus == 'AT_COUNTER') return LoanLiveStatus.atCounter;
    if (custodyState == 'AWAITING_ARRIVAL' || assetStatus == 'IN_TRANSIT') {
      return LoanLiveStatus.inTransit;
    }
    if (custodyState == 'VERIFIED' ||
        custodyState == 'NOT_REQUIRED' ||
        assetStatus == 'IN_ROOM_VERIFIED') {
      return LoanLiveStatus.verifiedInRoom;
    }
    // Nothing says it has left the counter yet.
    return LoanLiveStatus.atCounter;
  }

  /// Time left until [dueAt] (negative once overdue), or null if unknown.
  Duration? dueIn(DateTime now) => dueAt?.difference(now);

  /// "Maria Santos" for a student loan, the event title for an event loan.
  String? get borrower => studentName ?? eventTitle ?? borrowerName;

  /// "Computer Lab 1 (CL1)", or just the code when there's no name.
  String? get room {
    final code = roomCode;
    final name = roomName;
    if (code == null) return name;
    return name == null || name == code ? code : '$name ($code)';
  }
}

/// A page of `GET /loans`.
class LoansPage {
  const LoansPage({required this.items, required this.total});

  static const empty = LoansPage(items: [], total: 0);

  final List<LoanDetail> items;

  /// Matching loans across all pages; more than [items] when cut off.
  final int total;
}
