/// Which tab a push opens, keyed by the `type` in its data payload.
///
/// Types are the real-time event names (PRD 6.4) and the notification types
/// (PRD 7.3); the backend sends the same event as a push when the app isn't
/// in the foreground. Tabs follow the screens in PRD 6.6.
const pushDestinations = <String, String>{
  // Pending Approvals: approve or decline a student's borrow request.
  'approval.requested': '/approvals',

  // My Loans: live loan status and the freeze banner.
  'loan.created': '/loans',
  'instructor.frozen': '/loans',
  'instructor.unfrozen': '/loans',

  // Alerts: late arrivals, transit anomalies, overdue notices.
  'anomaly.raised': '/alerts',
  'anomaly.resolved': '/alerts',
  'warning.issued': '/alerts',
  'loan.overdue': '/alerts',
  'LATE_ARRIVAL_WARNING': '/alerts',
  'LOAN_OVERDUE': '/alerts',
};

/// Where tapping a push with this [data] payload should take the user, or
/// null when the type is missing or unknown (the app just opens normally).
String? locationForPush(Map<String, dynamic> data) {
  final type = data['type'];
  return type is String ? pushDestinations[type.trim()] : null;
}
