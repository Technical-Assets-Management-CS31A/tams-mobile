/// A room an approved item can go to (PRD 6.4 `roomOptions`).
class Room {
  const Room({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  /// "Computer Lab 1 (CL1)", or just the code when the name is the same.
  String get label => name == code || name.isEmpty ? code : '$name ($code)';

  @override
  bool operator ==(Object other) =>
      other is Room &&
      other.id == id &&
      other.code == code &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, code, name);
}

/// One item in a borrow request.
class ApprovalItem {
  const ApprovalItem({required this.name, required this.assetCode});

  final String name;
  final String assetCode;
}

/// A student's borrow request waiting for the card owner's decision
/// (FR-2.2, US-04). One entry of `GET /approvals/pending`.
class PendingApproval {
  const PendingApproval({
    required this.id,
    required this.studentName,
    required this.studentNumber,
    required this.items,
    required this.requestedAt,
    required this.expiresAt,
    this.sectionCode,
    this.photoUrl,
    this.roomOptions = const [],
    this.defaultRoomId,
    this.classLengthOptions = standardClassLengths,
    this.defaultClassLength = const Duration(minutes: 90),
  }) : assert(items.length > 0);

  /// The kiosk session id, used to approve or decline.
  final String id;
  final String studentName;
  final String studentNumber;
  final String? sectionCode;

  /// The photo taken at the counter. Needs the auth header to load.
  final String? photoUrl;

  /// Everything being borrowed; never empty.
  final List<ApprovalItem> items;

  final DateTime requestedAt;

  /// After this the kiosk gives up and the borrow is denied (120 s, PRD 10.2).
  final DateTime expiresAt;

  /// Rooms the instructor can send the items to.
  final List<Room> roomOptions;

  /// The instructor's default room, pre-selected in the room picker.
  final String? defaultRoomId;

  final List<Duration> classLengthOptions;
  final Duration defaultClassLength;

  String get itemName => items.first.name;
  String get assetTag => items.first.assetCode;

  /// The default room, if it is one of [roomOptions].
  Room? get defaultRoom {
    for (final r in roomOptions) {
      if (r.id == defaultRoomId) return r;
    }
    return null;
  }

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  /// Time until [expiresAt]; zero once expired.
  Duration timeLeft(DateTime now) {
    final left = expiresAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// How much of the approval window is left, from 1 (just requested) to
  /// 0 (expired).
  double fractionLeft(DateTime now) {
    final window = expiresAt.difference(requestedAt);
    if (window <= Duration.zero) return isExpired(now) ? 0 : 1;
    return (timeLeft(now).inMilliseconds / window.inMilliseconds).clamp(0, 1);
  }

  /// This request with its timestamps moved by [offset], to put server
  /// times on the device's clock.
  PendingApproval shifted(Duration offset) => offset == Duration.zero
      ? this
      : _copy(
          requestedAt: requestedAt.add(offset),
          expiresAt: expiresAt.add(offset),
        );

  /// This request, expired as of [at] (the server said it timed out).
  PendingApproval expiredAt(DateTime at) =>
      isExpired(at) ? this : _copy(expiresAt: at);

  // Copies every field. A new field must be added here too;
  // pending_approval_test.dart checks that none are dropped.
  PendingApproval _copy({DateTime? requestedAt, DateTime? expiresAt}) =>
      PendingApproval(
        id: id,
        studentName: studentName,
        studentNumber: studentNumber,
        sectionCode: sectionCode,
        photoUrl: photoUrl,
        items: items,
        requestedAt: requestedAt ?? this.requestedAt,
        expiresAt: expiresAt ?? this.expiresAt,
        roomOptions: roomOptions,
        defaultRoomId: defaultRoomId,
        classLengthOptions: classLengthOptions,
        defaultClassLength: defaultClassLength,
      );
}

/// Why staff froze my approval rights (PRD 4.1, F6): a loan I approved
/// went overdue or missing, or brought its student a 4th late arrival.
enum FreezeReason {
  lateArrivalLimit('4th late arrival'),
  overdue('Overdue'),
  missing('Missing'),
  other('Frozen');

  const FreezeReason(this.label);

  final String label;

  /// From the backend's `penalty_reason` label, e.g. `LATE_ARRIVAL_LIMIT`.
  static FreezeReason parse(Object? label) => switch (label) {
    'LATE_ARRIVAL_LIMIT' => lateArrivalLimit,
    'OVERDUE' => overdue,
    'MISSING' => missing,
    _ => other,
  };
}

/// One active freeze on my approval rights, with the loan that caused it
/// (US-06). Staff lift it from the web admin.
class ApprovalFreeze {
  const ApprovalFreeze({
    required this.id,
    required this.reason,
    this.frozenAt,
    this.loanId,
    this.loanNo,
    this.assetCode,
    this.assetName,
    this.studentName,
  });

  final String id;
  final FreezeReason reason;
  final DateTime? frozenAt;
  final String? loanId;
  final String? loanNo;
  final String? assetCode;
  final String? assetName;

  /// Null for an event loan, which has a coordinator instead.
  final String? studentName;

  /// "Epson Projector (PRJ-0012)", falling back to the code or loan number.
  String? get item {
    final name = assetName;
    final code = assetCode;
    if (name == null || name.isEmpty) return code ?? loanNo;
    return code == null || code.isEmpty ? name : '$name ($code)';
  }
}

/// What `GET /approvals/pending` returns: the requests, and the freezes on
/// my approval rights (FR-2.3, US-06).
class PendingApprovals {
  const PendingApprovals({
    required this.items,
    this.frozen = false,
    this.freezes = const [],
  });

  static const empty = PendingApprovals(items: []);

  final List<PendingApproval> items;

  /// Newest first. Can be empty while [frozen] if the server sent no
  /// details.
  final List<ApprovalFreeze> freezes;

  /// True while staff have frozen my approval rights.
  final bool frozen;

  /// The same freezes with [items] instead.
  PendingApprovals _withItems(List<PendingApproval> items) =>
      PendingApprovals(items: items, frozen: frozen, freezes: freezes);

  PendingApprovals without(String id) => _withItems([
    for (final r in items)
      if (r.id != id) r,
  ]);

  /// With request [id] replaced by `update(request)`.
  PendingApprovals updating(
    String id,
    PendingApproval Function(PendingApproval) update,
  ) => _withItems([for (final r in items) r.id == id ? update(r) : r]);

  /// This list plus the requests from [shown] that had expired by [now] and
  /// are missing here. The server leaves expired requests out, but they
  /// stay on screen until the instructor dismisses them. They go first:
  /// anything expired was requested before anything still pending.
  PendingApprovals keepingExpired(PendingApprovals shown, DateTime now) {
    final ids = {for (final r in items) r.id};
    final expired = [
      for (final r in shown.items)
        if (r.isExpired(now) && !ids.contains(r.id)) r,
    ];
    return expired.isEmpty ? this : _withItems([...expired, ...items]);
  }

  /// Every request's timestamps moved by [offset]; see
  /// [PendingApproval.shifted].
  PendingApprovals shifted(Duration offset) => offset == Duration.zero
      ? this
      : _withItems([for (final r in items) r.shifted(offset)]);
}

/// What the instructor chose when approving a request.
class ApprovalDecision {
  const ApprovalDecision({required this.room, required this.classLength});

  final Room room;
  final Duration classLength;

  @override
  bool operator ==(Object other) =>
      other is ApprovalDecision &&
      other.room == room &&
      other.classLength == classLength;

  @override
  int get hashCode => Object.hash(room, classLength);
}

/// Class lengths an item can be lent for: 1.5 to 3 hours in 30 minute steps
/// (`LoanRules.ClassLengths`). Used when the server sends none.
const standardClassLengths = [
  Duration(minutes: 90),
  Duration(minutes: 120),
  Duration(minutes: 150),
  Duration(minutes: 180),
];

/// "1.5 h", "2 h", ...
String formatClassLength(Duration length) {
  final hours = length.inMinutes / 60;
  final text = hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  return '$text h';
}
