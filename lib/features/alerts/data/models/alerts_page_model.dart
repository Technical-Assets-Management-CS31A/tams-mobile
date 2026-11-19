import '../../domain/entities/alert.dart';

/// Parses the body of `GET /notifications` (tams-backend
/// `NotificationEndpoints.List`):
///
/// ```json
/// {"items": [{"id", "type": "LATE_ARRIVAL_WARNING", "title", "body",
///   "loanId", "studentId", "createdAt", "readAt",
///   "payload": {"loanNo", "studentName", "sectionCode", "assetCode",
///               "warningNo", "penaltyTriggered", "details": {...}}}],
///  "page": 1, "pageSize": 25, "total": 3, "unreadCount": 2}
/// ```
///
/// Throws [FormatException] if the body doesn't have that shape. A single
/// malformed row is skipped rather than hiding every other alert.
AlertsPage parseAlertsPage(Object? body) {
  if (body is! Map) {
    throw const FormatException('Notifications response is not an object.');
  }
  final items = body['items'];
  if (items is! List) {
    throw const FormatException('Notifications response has no "items".');
  }
  final alerts = <Alert>[for (final i in items) ?_tryParseAlert(i)];
  return AlertsPage(
    items: alerts,
    page: _int(body['page']) ?? 1,
    total: _int(body['total']) ?? alerts.length,
    unreadCount:
        _int(body['unreadCount']) ?? alerts.where((a) => a.isUnread).length,
  );
}

Alert? _tryParseAlert(Object? json) {
  try {
    return parseAlert(json);
  } on FormatException {
    return null;
  }
}

/// One item of the list.
Alert parseAlert(Object? json) {
  if (json is! Map) throw const FormatException('Alert is not an object.');
  final payload = json['payload'] is Map ? json['payload'] as Map : const {};
  final details = payload['details'] is Map
      ? payload['details'] as Map
      : const {};

  final created = _date(json['createdAt']);
  if (created == null) throw const FormatException('Alert has no createdAt.');

  return Alert(
    id: _required(json['id'], 'id'),
    type: _required(json['type'], 'type'),
    title: _string(json['title']) ?? '',
    body: _string(json['body']) ?? '',
    createdAt: created,
    readAt: _date(json['readAt']),
    loanId: _string(json['loanId']),
    loanNo: _string(payload['loanNo']) ?? _string(details['loanNo']),
    studentName:
        _string(payload['studentName']) ?? _string(details['studentName']),
    sectionCode:
        _string(payload['sectionCode']) ?? _string(details['sectionCode']),
    assetCode: _string(payload['assetCode']) ?? _string(details['assetCode']),
    warningNo: _int(payload['warningNo']),
    penaltyTriggered: payload['penaltyTriggered'] == true,
  );
}

String _required(Object? value, String field) =>
    _string(value) ?? (throw FormatException('Alert has no "$field".'));

String? _string(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
