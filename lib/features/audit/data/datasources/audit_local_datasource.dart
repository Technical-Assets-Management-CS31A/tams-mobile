import 'package:sqflite/sqflite.dart';

import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/roster.dart';
import '../../domain/repositories/audit_store.dart';
import '../local/audit_database.dart';

class AuditLocalDataSource implements AuditStore {
  AuditLocalDataSource(AuditDatabase database, {required this.userId})
    : _db = database.db;

  final Database _db;

  @override
  final String userId;

  @override
  Future<void> cacheRooms(List<AuditRoom> rooms) async {
    final batch = _db.batch();
    _insertRooms(batch, rooms);
    await batch.commit(noResult: true);
  }

  @override
  Future<void> replaceRooms(List<AuditRoom> rooms) =>
      _db.transaction((tx) async {
        final batch = tx.batch();
        batch.delete('rooms', where: 'user_id = ?', whereArgs: [userId]);
        _insertRooms(batch, rooms);
        await batch.commit(noResult: true);
      });

  void _insertRooms(Batch batch, List<AuditRoom> rooms) {
    for (final r in rooms) {
      batch.insert('rooms', {
        'user_id': userId,
        'id': r.id,
        'code': r.code,
        'name': r.name,
        'building': r.building,
        'floor': r.floor,
        'is_storage': r.isStorage ? 1 : 0,
        'status': r.status,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  Future<List<AuditRoom>> cachedRooms({String query = ''}) async {
    final q = query.trim();
    // Match the typed text literally: `%` and `_` are LIKE wildcards.
    final pattern =
        '%${q.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
    final rows = await _db.query(
      'rooms',
      where: q.isEmpty ? 'user_id = ?' : r"user_id = ? AND (code LIKE ? ESCAPE '\' OR name LIKE ? ESCAPE '\')",
      whereArgs: [
        userId,
        if (q.isNotEmpty) ...[pattern, pattern],
      ],
      orderBy: 'code COLLATE NOCASE',
    );
    return [for (final r in rows) _room(r)];
  }

  @override
  Future<void> saveRoster(Roster roster) => _db.transaction((tx) async {
    final roomId = roster.room.id;
    final at = _date(roster.downloadedAt);
    await tx.delete(
      'roster_items',
      where: 'user_id = ? AND room_id = ?',
      whereArgs: [userId, roomId],
    );
    final batch = tx.batch();
    for (final i in roster.items) {
      batch.insert('roster_items', {
        'user_id': userId,
        'room_id': roomId,
        'asset_id': i.assetId,
        'asset_code': i.assetCode,
        'name': i.name,
        'category': i.category,
        'type': i.type,
        'status': i.status,
        'downloaded_at': at,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    batch.insert('rosters', {
      'user_id': userId,
      'room_id': roomId,
      'room_code': roster.room.code,
      'room_name': roster.room.name,
      'downloaded_at': at,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await batch.commit(noResult: true);
  });

  @override
  Future<Roster?> roster(String roomId) async {
    final head = await _db.query(
      'rosters',
      where: 'user_id = ? AND room_id = ?',
      whereArgs: [userId, roomId],
    );
    if (head.isEmpty) return null;
    final items = await _db.query(
      'roster_items',
      where: 'user_id = ? AND room_id = ?',
      whereArgs: [userId, roomId],
      orderBy: 'asset_code COLLATE NOCASE',
    );
    final h = head.single;
    return Roster(
      room: AuditRoom(
        id: roomId,
        code: h['room_code']! as String,
        name: h['room_name']! as String,
      ),
      downloadedAt: _parse(h['downloaded_at'])!,
      items: [
        for (final i in items)
          RosterItem(
            assetId: i['asset_id']! as String,
            assetCode: i['asset_code']! as String,
            name: i['name']! as String,
            category: i['category']! as String,
            type: i['type']! as String,
            status: i['status']! as String,
          ),
      ],
    );
  }

  @override
  Future<Map<String, RosterInfo>> rosterInfos() async {
    final rows = await _db.rawQuery(
      '''
      SELECT r.room_id, r.downloaded_at, COUNT(i.asset_id) AS item_count
      FROM rosters r
      LEFT JOIN roster_items i
        ON i.user_id = r.user_id AND i.room_id = r.room_id
      WHERE r.user_id = ?
      GROUP BY r.room_id, r.downloaded_at
      ''',
      [userId],
    );
    return {
      for (final r in rows)
        r['room_id']! as String: RosterInfo(
          itemCount: r['item_count']! as int,
          downloadedAt: _parse(r['downloaded_at'])!,
        ),
    };
  }

  @override
  Future<void> insertAudit(LocalAudit audit) => _db.insert('audits', {
    'local_id': audit.localId,
    'server_id': audit.serverId,
    'user_id': userId,
    'room_id': audit.roomId,
    'status': audit.status.label,
    'started_at': _date(audit.startedAt),
  });

  @override
  Future<LocalAudit?> audit(String localId) async {
    final rows = await _db.query(
      'audits',
      where: 'user_id = ? AND local_id = ?',
      whereArgs: [userId, localId],
    );
    return rows.isEmpty ? null : _audit(rows.single);
  }

  @override
  Future<List<LocalAudit>> openAudits() async {
    final rows = await _db.query(
      'audits',
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, AuditStatus.inProgress.label],
      orderBy: 'started_at',
    );
    return [for (final r in rows) _audit(r)];
  }

  @override
  Future<List<LocalAudit>> unfinishedAudits() async {
    final rows = await _db.query(
      'audits',
      where: 'user_id = ? AND status IN (?, ?)',
      whereArgs: [
        userId,
        AuditStatus.inProgress.label,
        AuditStatus.endedElsewhere.label,
      ],
      orderBy: 'started_at',
    );
    return [for (final r in rows) _audit(r)];
  }

  @override
  Future<LocalAudit?> openAuditFor(String roomId) async {
    final rows = await _db.query(
      'audits',
      where: 'user_id = ? AND room_id = ? AND status = ?',
      whereArgs: [userId, roomId, AuditStatus.inProgress.label],
    );
    return rows.isEmpty ? null : _audit(rows.single);
  }

  @override
  Future<void> setServerId(String localId, String serverId) => _db.update(
    'audits',
    {'server_id': serverId},
    where: 'user_id = ? AND local_id = ?',
    whereArgs: [userId, localId],
  );

  @override
  Future<void> markEndedElsewhere(String localId) => _db.update(
    'audits',
    {'status': AuditStatus.endedElsewhere.label},
    where: 'user_id = ? AND local_id = ?',
    whereArgs: [userId, localId],
  );

  @override
  Future<void> completeAudit(
    String localId, {
    required AuditCounts counts,
    required DateTime completedAt,
  }) => _db.transaction((tx) async {
    await tx.update(
      'audits',
      {
        'status': AuditStatus.completed.label,
        'completed_at': _date(completedAt),
        'expected_count': counts.expected,
        'matched_count': counts.matched,
        'missing_count': counts.missing,
        'misplaced_count': counts.misplaced,
        'unknown_count': counts.unknown,
      },
      where: 'user_id = ? AND local_id = ?',
      whereArgs: [userId, localId],
    );
    await tx.delete(
      'scans',
      where: 'user_id = ? AND local_audit_id = ?',
      whereArgs: [userId, localId],
    );
  });

  @override
  Future<void> markSignedOff(String localId) => _db.update(
    'audits',
    {'status': AuditStatus.signedOff.label},
    where: 'user_id = ? AND local_id = ? AND status = ?',
    whereArgs: [userId, localId, AuditStatus.completed.label],
  );

  @override
  Future<void> deleteAudit(String localId) => _db.delete(
    'audits',
    where: 'user_id = ? AND local_id = ?',
    whereArgs: [userId, localId],
  );

  @override
  Future<bool> addScan(AuditScan scan) async {
    final id = await _db.insert('scans', {
      'client_scan_id': scan.clientScanId,
      'local_audit_id': scan.localAuditId,
      'user_id': userId,
      'scanned_value': scan.scannedValue,
      'scan_key': scan.scanKey,
      'scanned_at': _date(scan.scannedAt),
      'local_result': scan.localResult.label,
      'server_result': scan.serverResult?.label,
      'asset_id': scan.assetId,
      'asset_code': scan.assetCode,
      'asset_name': scan.assetName,
      'synced_at': scan.syncedAt == null ? null : _date(scan.syncedAt!),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return id != 0;
  }

  @override
  Future<List<AuditScan>> scans(String localAuditId) async {
    final rows = await _db.query(
      'scans',
      where: 'user_id = ? AND local_audit_id = ?',
      whereArgs: [userId, localAuditId],
      orderBy: 'scanned_at DESC, rowid DESC',
    );
    return [for (final r in rows) _scan(r)];
  }

  @override
  Future<List<AuditScan>> unsyncedScans(
    String localAuditId, {
    int? limit,
  }) async {
    final rows = await _db.query(
      'scans',
      where: 'user_id = ? AND local_audit_id = ? AND synced_at IS NULL',
      whereArgs: [userId, localAuditId],
      orderBy: 'scanned_at, rowid',
      limit: limit,
    );
    return [for (final r in rows) _scan(r)];
  }

  @override
  Future<int> unsyncedCount({String? localAuditId}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(*) AS n FROM scans s
      JOIN audits a ON a.local_id = s.local_audit_id AND a.user_id = s.user_id
      WHERE s.user_id = ? AND s.synced_at IS NULL AND a.status = ?
      ${localAuditId == null ? '' : 'AND s.local_audit_id = ?'}
      ''',
      [userId, AuditStatus.inProgress.label, ?localAuditId],
    );
    return rows.single['n']! as int;
  }

  @override
  Future<void> markSynced(List<SyncedScan> results, DateTime syncedAt) async {
    final batch = _db.batch();
    final at = _date(syncedAt);
    for (final r in results) {
      batch.rawUpdate(
        '''
        UPDATE scans SET
          server_result = ?,
          asset_id = COALESCE(?, asset_id),
          asset_code = COALESCE(?, asset_code),
          asset_name = COALESCE(?, asset_name),
          synced_at = ?
        WHERE user_id = ? AND client_scan_id = ?
        ''',
        [
          r.result.label,
          r.assetId,
          r.assetCode,
          r.name,
          at,
          userId,
          r.clientScanId,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  static AuditRoom _room(Map<String, Object?> r) => AuditRoom(
    id: r['id']! as String,
    code: r['code']! as String,
    name: r['name']! as String,
    building: r['building']! as String,
    floor: r['floor'] as int?,
    isStorage: r['is_storage'] == 1,
    status: r['status']! as String,
  );

  static LocalAudit _audit(Map<String, Object?> r) {
    final expected = r['expected_count'] as int?;
    return LocalAudit(
      localId: r['local_id']! as String,
      serverId: r['server_id'] as String?,
      userId: r['user_id']! as String,
      roomId: r['room_id']! as String,
      status: AuditStatus.tryParse(r['status']) ?? AuditStatus.inProgress,
      startedAt: _parse(r['started_at'])!,
      completedAt: _parse(r['completed_at']),
      counts: expected == null
          ? null
          : AuditCounts(
              expected: expected,
              matched: r['matched_count'] as int? ?? 0,
              missing: r['missing_count'] as int? ?? 0,
              misplaced: r['misplaced_count'] as int? ?? 0,
              unknown: r['unknown_count'] as int? ?? 0,
            ),
    );
  }

  static AuditScan _scan(Map<String, Object?> r) => AuditScan(
    clientScanId: r['client_scan_id']! as String,
    localAuditId: r['local_audit_id']! as String,
    scannedValue: r['scanned_value']! as String,
    scanKey: r['scan_key']! as String,
    scannedAt: _parse(r['scanned_at'])!,
    localResult: ScanResult.tryParse(r['local_result']) ?? ScanResult.unknown,
    serverResult: ScanResult.tryParse(r['server_result']),
    assetId: r['asset_id'] as String?,
    assetCode: r['asset_code'] as String?,
    assetName: r['asset_name'] as String?,
    syncedAt: _parse(r['synced_at']),
  );

  static String _date(DateTime at) => at.toUtc().toIso8601String();

  static DateTime? _parse(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
