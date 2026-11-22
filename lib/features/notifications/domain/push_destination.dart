import 'dart:convert';

import '../../../routing/locations.dart';

/// The `type` of a push for a stored notification (tams-backend
/// `NoticePush`): a late arrival warning, anomaly, overdue or missing
/// notice. Its `noticeType` says which, and `payload` (a JSON string)
/// carries the `loanId`.
const noticePushType = 'notice';

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

  // Alerts: late arrivals, transit anomalies, overdue notices. A notice
  // about a loan opens that loan instead; see [locationForPush].
  noticePushType: '/alerts',
  'anomaly.raised': '/alerts',
  'anomaly.resolved': '/alerts',
  'warning.issued': '/alerts',
  'loan.overdue': '/alerts',
  'LATE_ARRIVAL_WARNING': '/alerts',
  'LOAN_OVERDUE': '/alerts',
};

/// Where tapping a push with this [data] payload should take the user, or
/// null when the type is missing or unknown (the app just opens normally).
/// A notice about a loan opens the loan, on top of Alerts.
String? locationForPush(Map<String, dynamic> data) {
  final type = pushType(data);
  if (type == null) return null;
  if (type == noticePushType) {
    if (noticeLoanId(data) case final loanId?) return alertLoanLocation(loanId);
  }
  return pushDestinations[type];
}

/// The trimmed `type` of a push, or null if it has none.
String? pushType(Map<String, dynamic> data) {
  final type = data['type'];
  return type is String ? type.trim() : null;
}

/// True for pushes that add to or change the Alerts list.
bool isAlertPush(Map<String, dynamic> data) =>
    pushDestinations[pushType(data)] == '/alerts';

/// True for pushes that can change a loan's live status in My Loans: new
/// loans, and every warning, anomaly and overdue notice.
bool isLoanPush(Map<String, dynamic> data) {
  final type = pushType(data);
  return type != null &&
      !type.startsWith('instructor.') &&
      (pushDestinations[type] == '/loans' || isAlertPush(data));
}

/// The stored notification a notice push is for, so it can be marked read.
String? noticeId(Map<String, dynamic> data) {
  final id = data['notificationId'];
  return pushType(data) == noticePushType && id is String && id.isNotEmpty
      ? id
      : null;
}

/// The loan in a notice push's `payload`, if any. FCM data values are
/// strings, so the payload arrives JSON-encoded.
String? noticeLoanId(Map<String, dynamic> data) {
  var payload = data['payload'];
  if (payload is String) {
    try {
      payload = jsonDecode(payload);
    } on FormatException {
      return null;
    }
  }
  final loanId = payload is Map ? payload['loanId'] : null;
  return loanId is String && loanId.isNotEmpty ? loanId : null;
}
