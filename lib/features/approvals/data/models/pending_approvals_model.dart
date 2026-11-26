import '../../domain/entities/pending_approval.dart';

/// Parses the body of `GET /approvals/pending` (tams-backend
/// `ApprovalEndpoints.Pending`):
///
/// ```json
/// {"frozen": true, "freezes": [{"id", "reason": "OVERDUE", "frozenAt",
///   "loanId", "loanNo", "assetCode", "assetName", "studentName"}],
///  "items": [{
///   "sessionId": "...", "student": {"studentNo", "fullName", "sectionCode"},
///   "asset": {...}, "items": [{"assetCode", "name", "condition"}],
///   "photoUrl": "/api/approvals/{id}/photo",
///   "roomOptions": [{"id", "code", "name"}], "defaultRoomId": "...",
///   "classLengthOptions": [90, 120, 150, 180], "defaultClassLengthMinutes": 90,
///   "requestedAt": "...", "expiresAt": "..."}]}
/// ```
///
/// Relative photo URLs are resolved against [baseUrl]. Throws
/// [FormatException] if the body doesn't have that shape.
PendingApprovals parsePendingApprovals(
  Object? body, {
  required String baseUrl,
}) {
  if (body is! Map) {
    throw const FormatException('Pending approvals response is not an object.');
  }
  final items = body['items'];
  if (items is! List) {
    throw const FormatException('Pending approvals response has no "items".');
  }
  final rawFreezes = body['freezes'];
  final freezes = [
    if (rawFreezes is List)
      for (final f in rawFreezes)
        if (f is Map && f['id'] is String) _freeze(f),
  ];
  return PendingApprovals(
    frozen: body['frozen'] == true || freezes.isNotEmpty,
    items: [for (final i in items) _parseRequest(i, baseUrl)],
    freezes: freezes,
  );
}

/// A freeze with missing details still counts; the banner just says less.
ApprovalFreeze _freeze(Map json) {
  String? text(String key) {
    final v = json[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  final at = text('frozenAt');
  return ApprovalFreeze(
    id: json['id'] as String,
    reason: FreezeReason.parse(json['reason']),
    frozenAt: at == null ? null : DateTime.tryParse(at)?.toLocal(),
    loanId: text('loanId'),
    loanNo: text('loanNo'),
    assetCode: text('assetCode'),
    assetName: text('assetName'),
    studentName: text('studentName'),
  );
}

PendingApproval _parseRequest(Object? json, String baseUrl) {
  if (json is! Map) throw const FormatException('Approval is not an object.');

  final student = json['student'];
  final s = student is Map ? student : const {};

  // `items` lists every asset in the checkout; older payloads only had `asset`.
  final rawItems = json['items'];
  final items = <ApprovalItem>[
    if (rawItems is List)
      for (final i in rawItems)
        if (i is Map) _item(i),
  ];
  final asset = json['asset'];
  if (items.isEmpty && asset is Map) items.add(_item(asset));
  if (items.isEmpty) throw const FormatException('Approval has no items.');

  final lengths = json['classLengthOptions'];
  final classLengths = <Duration>[
    if (lengths is List)
      for (final m in lengths)
        if (m is num) Duration(minutes: m.toInt()),
  ];
  final defaultMinutes = json['defaultClassLengthMinutes'];
  final options = classLengths.isEmpty ? standardClassLengths : classLengths;
  final defaultLength = defaultMinutes is num
      ? Duration(minutes: defaultMinutes.toInt())
      : options.first;

  final rooms = json['roomOptions'];
  final photo = json['photoUrl'];

  return PendingApproval(
    id: _string(json['sessionId'], 'sessionId'),
    studentName: _string(s['fullName'], 'student.fullName'),
    studentNumber: s['studentNo'] is String ? s['studentNo'] as String : '',
    sectionCode: s['sectionCode'] is String ? s['sectionCode'] as String : null,
    photoUrl: photo is String && photo.isNotEmpty
        ? Uri.parse(baseUrl).resolve(photo).toString()
        : null,
    items: items,
    requestedAt: _date(json['requestedAt'], 'requestedAt'),
    expiresAt: _date(json['expiresAt'], 'expiresAt'),
    roomOptions: [
      if (rooms is List)
        for (final r in rooms)
          if (r is Map && r['id'] is String)
            Room(
              id: r['id'] as String,
              code: r['code'] is String ? r['code'] as String : '',
              name: r['name'] is String ? r['name'] as String : '',
            ),
    ],
    defaultRoomId: json['defaultRoomId'] is String
        ? json['defaultRoomId'] as String
        : null,
    classLengthOptions: options,
    // A default the picker can't show would leave nothing selected.
    defaultClassLength: options.contains(defaultLength)
        ? defaultLength
        : options.first,
  );
}

ApprovalItem _item(Map json) => ApprovalItem(
  name: _string(json['name'], 'item name'),
  assetCode: json['assetCode'] is String ? json['assetCode'] as String : '',
);

String _string(Object? value, String field) {
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Approval has no "$field".');
}

DateTime _date(Object? value, String field) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw FormatException('Approval has no valid "$field".');
  return parsed.toLocal();
}
