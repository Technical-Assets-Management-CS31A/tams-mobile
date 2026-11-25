import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AuditDatabase {
  AuditDatabase._(this.db);

  final Database db;

  static const version = 1;
  static const fileName = 'tams_audit.db';

  static const _schema = [
    '''
    CREATE TABLE rooms (
      user_id TEXT NOT NULL,
      id TEXT NOT NULL,
      code TEXT NOT NULL,
      name TEXT NOT NULL,
      building TEXT NOT NULL DEFAULT '',
      floor INTEGER,
      is_storage INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT '',
      PRIMARY KEY (user_id, id)
    )
    ''',
    '''
    CREATE TABLE rosters (
      user_id TEXT NOT NULL,
      room_id TEXT NOT NULL,
      room_code TEXT NOT NULL,
      room_name TEXT NOT NULL,
      downloaded_at TEXT NOT NULL,
      PRIMARY KEY (user_id, room_id)
    )
    ''',
    '''
    CREATE TABLE roster_items (
      user_id TEXT NOT NULL,
      room_id TEXT NOT NULL,
      asset_id TEXT NOT NULL,
      asset_code TEXT NOT NULL,
      name TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT '',
      type TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT '',
      downloaded_at TEXT NOT NULL,
      PRIMARY KEY (user_id, room_id, asset_id)
    )
    ''',
    '''
    CREATE TABLE audits (
      local_id TEXT PRIMARY KEY,
      server_id TEXT,
      user_id TEXT NOT NULL,
      room_id TEXT NOT NULL,
      status TEXT NOT NULL,
      started_at TEXT NOT NULL,
      completed_at TEXT,
      expected_count INTEGER,
      matched_count INTEGER,
      missing_count INTEGER,
      misplaced_count INTEGER,
      unknown_count INTEGER
    )
    ''',
    '''
    CREATE UNIQUE INDEX audits_one_open_per_room
      ON audits (user_id, room_id) WHERE status = 'IN_PROGRESS'
    ''',
    '''
    CREATE TABLE scans (
      client_scan_id TEXT PRIMARY KEY,
      local_audit_id TEXT NOT NULL
        REFERENCES audits (local_id) ON DELETE CASCADE,
      user_id TEXT NOT NULL,
      scanned_value TEXT NOT NULL,
      scan_key TEXT NOT NULL,
      scanned_at TEXT NOT NULL,
      local_result TEXT NOT NULL,
      server_result TEXT,
      asset_id TEXT,
      asset_code TEXT,
      asset_name TEXT,
      synced_at TEXT
    )
    ''',
    '''
    CREATE UNIQUE INDEX scans_once_per_audit
      ON scans (local_audit_id, scan_key)
    ''',
    '''
    CREATE INDEX scans_unsynced
      ON scans (user_id, local_audit_id, synced_at)
    ''',
  ];

  static const migrations = <int, List<String>>{};

  static Future<AuditDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final location = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: upgrade,
      ),
    );
    return AuditDatabase._(db);
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();
    for (final sql in _schema) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
    await upgrade(db, 1, version);
  }

  static Future<void> upgrade(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      for (final sql in migrations[v] ?? const <String>[]) {
        await db.execute(sql);
      }
    }
  }

  Future<void> close() => db.close();
}
