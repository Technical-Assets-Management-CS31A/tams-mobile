/// A student's borrow request waiting for an approver.
class PendingApproval {
  const PendingApproval({
    required this.id,
    required this.studentName,
    required this.studentNumber,
    required this.itemName,
    required this.assetTag,
    required this.requestedAt,
    this.photoUrl,
  });

  final String id;
  final String studentName;
  final String studentNumber;

  /// Student's profile photo. Null when they haven't uploaded one.
  final String? photoUrl;

  final String itemName;
  final String assetTag;
  final DateTime requestedAt;
}

/// What the approver chose when approving a request.
class ApprovalDecision {
  const ApprovalDecision({required this.room, required this.classLength});

  final String room;
  final Duration classLength;

  @override
  bool operator ==(Object other) =>
      other is ApprovalDecision &&
      other.room == room &&
      other.classLength == classLength;

  @override
  int get hashCode => Object.hash(room, classLength);
}

/// Class lengths an item can be lent for: 1.5 to 3 hours in 30 minute steps.
const classLengthOptions = [
  Duration(minutes: 90),
  Duration(hours: 2),
  Duration(minutes: 150),
  Duration(hours: 3),
];

/// "1.5 h", "2 h", ...
String formatClassLength(Duration length) {
  final hours = length.inMinutes / 60;
  final text = hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  return '$text h';
}
