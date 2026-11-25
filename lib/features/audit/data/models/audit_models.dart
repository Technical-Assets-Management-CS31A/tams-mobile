import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/roster.dart';

RoomsPage parseRoomsPage(Object? body) {
  final map = _map(body, 'Rooms response');
  final items = map['items'];
  if (items is! List) {
    throw const FormatException('Rooms response has no "items".');
  }
  final rooms = <AuditRoom>[for (final i in items) ?_tryParse(i, parseRoom)];
  return RoomsPage(
    items: rooms,
    page: _int(map['page']) ?? 1,
    total: _int(map['total']) ?? rooms.length,
  );
}

AuditRoom parseRoom(Object? json) {
  final map = _map(json, 'Room');
  return AuditRoom(
    id: _required(map['id'], 'Room', 'id'),
    code: _required(map['code'], 'Room', 'code'),
    name: _string(map['name']) ?? '',
    building: _string(map['building']) ?? '',
    floor: _int(map['floor']),
    isStorage: map['isStorage'] == true,
    status: _string(map['status']) ?? '',
  );
}

Roster parseRoster(Object? body, {required DateTime fallbackDownloadedAt}) {
  final map = _map(body, 'Roster response');
  return Roster(
    room: parseRoom(map['room']),
    items: _rosterItems(map['items']),
    downloadedAt: _date(map['downloadedAt']) ?? fallbackDownloadedAt,
  );
}

(ServerAudit, Roster) parseStartedAudit(
  Object? body, {
  required DateTime downloadedAt,
}) {
  final map = _map(body, 'Start audit response');
  return (
    parseServerAudit(map['audit']),
    Roster(
      room: parseRoom(map['room']),
      items: _rosterItems(map['roster']),
      downloadedAt: downloadedAt,
    ),
  );
}

List<ServerAudit> parseAuditsPage(Object? body) {
  final items = _map(body, 'Audits response')['items'];
  if (items is! List) {
    throw const FormatException('Audits response has no "items".');
  }
  return [for (final i in items) ?_tryParse(i, parseServerAudit)];
}

ServerAudit parseServerAudit(Object? json) {
  final map = _map(json, 'Audit');
  final status = AuditStatus.tryParse(map['status']);
  final startedAt = _date(map['startedAt']);
  if (status == null || startedAt == null) {
    throw const FormatException('Audit has no status or startedAt.');
  }
  final expected = _int(map['expectedCount']);
  return ServerAudit(
    id: _required(map['id'], 'Audit', 'id'),
    roomId: _required(map['roomId'], 'Audit', 'roomId'),
    status: status,
    startedByUserId: _string(map['startedByUserId']),
    startedAt: startedAt,
    completedAt: _date(map['completedAt']),
    signedOffAt: _date(map['signedOffAt']),
    counts: expected == null
        ? null
        : AuditCounts(
            expected: expected,
            matched: _int(map['matchedCount']) ?? 0,
            missing: _int(map['missingCount']) ?? 0,
            misplaced: _int(map['misplacedCount']) ?? 0,
            unknown: _int(map['unknownCount']) ?? 0,
          ),
  );
}

ScanBatchResult parseScanBatch(Object? body) {
  final map = _map(body, 'Scan batch response');
  final results = map['results'];
  if (results is! List) {
    throw const FormatException('Scan batch response has no "results".');
  }
  return ScanBatchResult(
    accepted: _int(map['accepted']) ?? 0,
    duplicates: _int(map['duplicates']) ?? 0,
    results: [for (final r in results) ?_tryParse(r, _syncedScan)],
  );
}

AuditDetail parseAuditDetail(Object? body) {
  final map = _map(body, 'Audit detail');
  final items = map['items'];
  return AuditDetail(
    audit: parseServerAudit(map['audit']),
    items: items is List
        ? [for (final i in items) ?_tryParse(i, _line)]
        : const [],
  );
}

SyncedScan _syncedScan(Object? json) {
  final map = _map(json, 'Scan result');
  final result = ScanResult.tryParse(map['result']);
  if (result == null) throw const FormatException('Scan result has no result.');
  return SyncedScan(
    clientScanId: _required(map['clientScanId'], 'Scan result', 'clientScanId'),
    result: result,
    assetId: _string(map['assetId']),
    assetCode: _string(map['assetCode']),
    name: _string(map['name']),
    duplicate: map['duplicate'] == true,
  );
}

AuditLine _line(Object? json) {
  final map = _map(json, 'Audit item');
  final result = ScanResult.tryParse(map['result']);
  if (result == null) throw const FormatException('Audit item has no result.');
  return AuditLine(
    result: result,
    scannedValue: _string(map['scannedValue']) ?? '',
    assetId: _string(map['assetId']),
    assetCode: _string(map['assetCode']),
    name: _string(map['name']),
  );
}

List<RosterItem> _rosterItems(Object? items) {
  if (items is! List) throw const FormatException('Roster has no items.');
  return [for (final i in items) ?_tryParse(i, _rosterItem)];
}

RosterItem _rosterItem(Object? json) {
  final map = _map(json, 'Roster item');
  return RosterItem(
    assetId: _required(map['id'], 'Roster item', 'id').toLowerCase(),
    assetCode: _string(map['assetCode']) ?? '',
    name: _string(map['name']) ?? '',
    category: _string(map['category']) ?? '',
    type: _string(map['type']) ?? '',
    status: _string(map['status']) ?? '',
  );
}

T? _tryParse<T>(Object? json, T Function(Object?) parse) {
  try {
    return parse(json);
  } on FormatException {
    return null;
  }
}

Map<Object?, Object?> _map(Object? json, String what) =>
    json is Map ? json : throw FormatException('$what is not an object.');

String _required(Object? value, String what, String field) =>
    _string(value) ?? (throw FormatException('$what has no "$field".'));

String? _string(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
