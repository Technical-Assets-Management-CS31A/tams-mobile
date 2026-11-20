/// What an alert is about, from its notification `type` (tams-backend
/// `LoanRules.Notify` and `NotifyStaffAsync`).
enum AlertKind {
  /// FR-6.1, US-07: the item wasn't tapped at the room in time.
  lateArrival,

  /// FR-4.3: an anomaly. Wrong-room and unborrowed taps both arrive as
  /// `ANOMALY_RAISED` (tams-backend `DeviceEndpoints.RaiseAsync`; the title
  /// says which); `TRANSIT_TIMEOUT` is the staff copy of a late arrival.
  anomaly,

  /// FR-6.3: due time passed and the item is still out.
  overdue,

  /// FR-6.7: staff declared the item missing.
  missing,

  /// Anything else (e.g. staff notices such as STATION_OFFLINE).
  other;

  static AlertKind fromType(String type) => switch (type) {
    'LATE_ARRIVAL_WARNING' => lateArrival,
    'ANOMALY_RAISED' || 'TRANSIT_TIMEOUT' => anomaly,
    'LOAN_OVERDUE' => overdue,
    'LOAN_MISSING' => missing,
    _ => other,
  };

  String get label => switch (this) {
    lateArrival => 'Late arrival',
    anomaly => 'Anomaly',
    overdue => 'Overdue',
    missing => 'Missing',
    other => 'Notice',
  };
}

/// One row of `GET /notifications` (PRD 7.3 `notifications`): a warning,
/// anomaly or overdue notice about a loan I approved (FR-2.6, US-05).
class Alert {
  const Alert({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.loanId,
    this.loanNo,
    this.studentName,
    this.sectionCode,
    this.assetCode,
    this.warningNo,
    this.penaltyTriggered = false,
  });

  final String id;

  /// The raw notification type, e.g. `LATE_ARRIVAL_WARNING`.
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  /// The loan it is about; tapping the alert opens it. Null for notices
  /// that aren't about a loan.
  final String? loanId;
  final String? loanNo;
  final String? studentName;
  final String? sectionCode;
  final String? assetCode;

  /// Late Arrival Warning number this term (1 to 4+), for late arrivals.
  final int? warningNo;

  /// The warning went over the limit: a Non-Compliance Mark was issued and
  /// my approvals are frozen (US-07).
  final bool penaltyTriggered;

  AlertKind get kind => AlertKind.fromType(type);
  bool get isUnread => readAt == null;

  /// "Maria Santos · BSCS-3A", or null when it isn't about a student.
  String? get who {
    final name = studentName;
    if (name == null) return null;
    final section = sectionCode;
    return section == null ? name : '$name · $section';
  }

  Alert markedRead(DateTime at) => isUnread
      ? Alert(
          id: id,
          type: type,
          title: title,
          body: body,
          createdAt: createdAt,
          readAt: at,
          loanId: loanId,
          loanNo: loanNo,
          studentName: studentName,
          sectionCode: sectionCode,
          assetCode: assetCode,
          warningNo: warningNo,
          penaltyTriggered: penaltyTriggered,
        )
      : this;
}

/// One page of `GET /notifications`.
class AlertsPage {
  const AlertsPage({
    required this.items,
    required this.page,
    required this.total,
    required this.unreadCount,
  });

  final List<Alert> items;
  final int page;

  /// All my notifications, across pages.
  final int total;
  final int unreadCount;
}

/// What the Alerts screen shows: every page loaded so far, newest first.
class AlertsFeed {
  const AlertsFeed({
    required this.items,
    required this.unreadCount,
    required this.total,
    required this.page,
    this.reachedEnd = false,
  });

  factory AlertsFeed.first(AlertsPage page) => AlertsFeed(
    items: _newestFirst(page.items),
    unreadCount: page.unreadCount,
    total: page.total,
    page: page.page,
    reachedEnd: page.items.isEmpty,
  );

  static const empty = AlertsFeed(items: [], unreadCount: 0, total: 0, page: 1);

  final List<Alert> items;
  final int unreadCount;
  final int total;

  /// The last page loaded.
  final int page;

  /// The server sent an empty page: there is nothing after [page].
  final bool reachedEnd;

  /// [items] can stay short of [total] for good (a malformed row is
  /// skipped, or one was deleted meanwhile), so an empty page also ends it.
  bool get hasMore => !reachedEnd && items.length < total;

  /// With [next] added after the alerts already here. A row can show up
  /// on two pages when new ones arrive in between; it is kept once.
  AlertsFeed adding(AlertsPage next) {
    final ids = {for (final a in items) a.id};
    return AlertsFeed(
      items: _newestFirst([
        ...items,
        for (final a in next.items)
          if (!ids.contains(a.id)) a,
      ]),
      unreadCount: next.unreadCount,
      total: next.total,
      page: next.page,
      reachedEnd: next.items.isEmpty,
    );
  }

  /// With alert [id] marked read as of [at].
  AlertsFeed markingRead(String id, DateTime at) {
    if (!items.any((a) => a.id == id && a.isUnread)) return this;
    return AlertsFeed(
      items: [for (final a in items) a.id == id ? a.markedRead(at) : a],
      unreadCount: unreadCount > 0 ? unreadCount - 1 : 0,
      total: total,
      page: page,
      reachedEnd: reachedEnd,
    );
  }

  static List<Alert> _newestFirst(List<Alert> alerts) =>
      [...alerts]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
