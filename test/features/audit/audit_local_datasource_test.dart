import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tams_mobile/features/audit/data/datasources/audit_local_datasource.dart';
import 'package:tams_mobile/features/audit/data/local/audit_database.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_room.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_scan.dart';

import '../../helpers/audit_fixtures.dart';

void main() {
  late AuditDatabase database;
  late AuditLocalDataSource mine;
  late AuditLocalDataSource theirs;

  setUp(() async {
    database = await memoryAuditDatabase();
    mine = AuditLocalDataSource(database, userId: 'user-1');
    theirs = AuditLocalDataSource(database, userId: 'user-2');
  });

  tearDown(() => database.close());

  test('creates schema version 1', () async {
    expect(await database.db.getVersion(), AuditDatabase.version);
  });

  group('rooms', () {
    test('caches rooms and searches them by code or name', () async {
      await mine.cacheRooms([storageRoom, lab1]);

      expect((await mine.cachedRooms()).map((r) => r.code), ['CL1', 'ST1']);
      expect((await mine.cachedRooms(query: 'lab')).single.id, lab1.id);
      expect((await mine.cachedRooms(query: 'st1')).single.isStorage, isTrue);
      final cached = (await mine.cachedRooms()).first;
      expect(cached.building, 'Main');
      expect(cached.floor, 2);
    });

    test('caching a room again updates it', () async {
      await mine.cacheRooms([lab1]);
      await mine.cacheRooms([
        const AuditRoom(id: 'room-lab1', code: 'CL1', name: 'Computer Lab One'),
      ]);

      expect((await mine.cachedRooms()).single.name, 'Computer Lab One');
    });

    test('search treats % and _ as plain text', () async {
      await mine.cacheRooms([
        const AuditRoom(id: 'r-1', code: 'LAB_1', name: 'Lab'),
        const AuditRoom(id: 'r-2', code: 'LAB-1', name: 'Lab'),
        const AuditRoom(id: 'r-3', code: 'LABX1', name: '100% full'),
      ]);

      expect((await mine.cachedRooms(query: 'LAB_1')).single.id, 'r-1');
      expect((await mine.cachedRooms(query: '%')).single.id, 'r-3');
      expect(await mine.cachedRooms(query: r'\'), isEmpty);
    });
  });

  group('rosters', () {
    test('saves a roster and reads it back', () async {
      await mine.saveRoster(labRoster());

      final saved = await mine.roster(lab1.id);
      expect(saved!.items.map((i) => i.assetCode), [
        'LPT-01',
        'PC-01',
        'PC-02',
      ]);
      expect(saved.room.code, 'CL1');
      expect(saved.downloadedAt.toUtc(), DateTime.utc(2026, 11, 25, 1));
      expect(saved.item(assetC)!.isOnLoan, isTrue);
      expect(saved.item(assetA)!.isOnLoan, isFalse);
    });

    test('downloading again replaces the items', () async {
      await mine.saveRoster(labRoster());
      await mine.saveRoster(
        labRoster(
          items: [labRoster().items.first],
          downloadedAt: DateTime.utc(2026, 11, 25, 3),
        ),
      );

      final infos = await mine.rosterInfos();
      expect(infos[lab1.id]!.itemCount, 1);
      expect(
        infos[lab1.id]!.downloadedAt.toUtc(),
        DateTime.utc(2026, 11, 25, 3),
      );
    });

    test('an empty roster still counts as downloaded', () async {
      await mine.saveRoster(labRoster(room: storageRoom, items: const []));

      expect((await mine.rosterInfos())[storageRoom.id]!.itemCount, 0);
      expect((await mine.roster(storageRoom.id))!.items, isEmpty);
    });

    test('a room never downloaded has no roster', () async {
      expect(await mine.roster(lab1.id), isNull);
      expect(await mine.rosterInfos(), isEmpty);
    });
  });

  group('audits', () {
    test('one open audit per room', () async {
      await mine.insertAudit(openAudit());

      await expectLater(
        mine.insertAudit(openAudit(localId: 'local-2')),
        throwsA(isA<DatabaseException>()),
      );
      expect((await mine.openAuditFor(lab1.id))!.localId, 'local-1');
    });

    test('saves the server id once it is known', () async {
      await mine.insertAudit(openAudit());
      await mine.setServerId('local-1', 'srv-1');

      expect((await mine.audit('local-1'))!.serverId, 'srv-1');
    });

    test('completing stores the counts and clears the scans', () async {
      await mine.insertAudit(openAudit(serverId: 'srv-1'));
      await mine.addScan(scan('s-1'));

      await mine.completeAudit(
        'local-1',
        counts: const AuditCounts(
          expected: 3,
          matched: 1,
          missing: 2,
          misplaced: 0,
          unknown: 0,
        ),
        completedAt: DateTime.utc(2026, 11, 25, 4),
      );

      final done = (await mine.audit('local-1'))!;
      expect(done.status, AuditStatus.completed);
      expect(done.isOpen, isFalse);
      expect(done.counts!.missing, 2);
      expect(done.completedAt!.toUtc(), DateTime.utc(2026, 11, 25, 4));
      expect(await mine.scans('local-1'), isEmpty);
      expect(await mine.openAuditFor(lab1.id), isNull);
    });

    test('only a submitted audit can be signed off', () async {
      await mine.insertAudit(openAudit());

      await mine.markSignedOff('local-1');
      expect((await mine.audit('local-1'))!.status, AuditStatus.inProgress);

      await mine.completeAudit(
        'local-1',
        counts: const AuditCounts(
          expected: 1,
          matched: 1,
          missing: 0,
          misplaced: 0,
          unknown: 0,
        ),
        completedAt: DateTime.utc(2026, 11, 25, 4),
      );
      await mine.markSignedOff('local-1');

      final done = (await mine.audit('local-1'))!;
      expect(done.status, AuditStatus.signedOff);
      expect(done.counts!.matched, 1);
    });

    test('an audit ended elsewhere is no longer open', () async {
      await mine.insertAudit(openAudit());
      await mine.markEndedElsewhere('local-1');

      expect(await mine.openAudits(), isEmpty);
      expect(
        (await mine.unfinishedAudits()).single.status,
        AuditStatus.endedElsewhere,
      );
    });

    test('deleting an audit deletes its scans', () async {
      await mine.insertAudit(openAudit());
      await mine.addScan(scan('s-1'));

      await mine.deleteAudit('local-1');

      expect(await mine.audit('local-1'), isNull);
      expect(await mine.scans('local-1'), isEmpty);
    });
  });

  group('scans', () {
    setUp(() => mine.insertAudit(openAudit()));

    test('the same asset is saved once per audit', () async {
      expect(await mine.addScan(scan('s-1')), isTrue);
      expect(await mine.addScan(scan('s-2')), isFalse);

      expect((await mine.scans('local-1')).single.clientScanId, 's-1');
    });

    test('lists newest first and the unsynced queue oldest first', () async {
      await mine.addScan(scan('s-1', at: DateTime.utc(2026, 11, 25, 2, 1)));
      await mine.addScan(
        scan(
          's-2',
          assetId: assetB,
          value: assetB,
          at: DateTime.utc(2026, 11, 25, 2, 2),
        ),
      );

      expect((await mine.scans('local-1')).map((s) => s.clientScanId), [
        's-2',
        's-1',
      ]);
      expect((await mine.unsyncedScans('local-1')).map((s) => s.clientScanId), [
        's-1',
        's-2',
      ]);
      expect(await mine.unsyncedScans('local-1', limit: 1), hasLength(1));
      expect(await mine.unsyncedCount(), 2);
    });

    test('marking synced stores the server result', () async {
      await mine.addScan(
        scan(
          's-1',
          value: 'tams:asset:$strayAsset',
          assetId: strayAsset,
          result: ScanResult.pending,
        ),
      );

      await mine.markSynced([
        const SyncedScan(
          clientScanId: 's-1',
          result: ScanResult.misplaced,
          assetId: strayAsset,
          assetCode: 'PRJ-07',
          name: 'Projector 07',
        ),
      ], DateTime.utc(2026, 11, 25, 3));

      final synced = (await mine.scans('local-1')).single;
      expect(synced.isSynced, isTrue);
      expect(synced.localResult, ScanResult.pending);
      expect(synced.result, ScanResult.misplaced);
      expect(synced.assetCode, 'PRJ-07');
      expect(synced.assetName, 'Projector 07');
      expect(await mine.unsyncedCount(), 0);
    });

    test('a resent scan without a name keeps the one it had', () async {
      await mine.addScan(scan('s-1'));
      await mine.markSynced([
        const SyncedScan(
          clientScanId: 's-1',
          result: ScanResult.matched,
          assetCode: 'PC-01',
          name: 'Desktop 01',
        ),
      ], DateTime.utc(2026, 11, 25, 3));

      await mine.markSynced([
        const SyncedScan(
          clientScanId: 's-1',
          result: ScanResult.matched,
          duplicate: true,
        ),
      ], DateTime.utc(2026, 11, 25, 4));

      expect((await mine.scans('local-1')).single.assetName, 'Desktop 01');
    });

    test('scans of an audit ended elsewhere are not waiting to sync', () async {
      await mine.addScan(scan('s-1'));
      await mine.markEndedElsewhere('local-1');

      expect(await mine.unsyncedCount(), 0);
      expect(await mine.unsyncedScans('local-1'), hasLength(1));
    });
  });

  group('another user on the same phone', () {
    test('sees none of my data', () async {
      await mine.cacheRooms([lab1]);
      await mine.saveRoster(labRoster());
      await mine.insertAudit(openAudit());
      await mine.addScan(scan('s-1'));

      expect(await theirs.cachedRooms(), isEmpty);
      expect(await theirs.roster(lab1.id), isNull);
      expect(await theirs.rosterInfos(), isEmpty);
      expect(await theirs.audit('local-1'), isNull);
      expect(await theirs.openAudits(), isEmpty);
      expect(await theirs.scans('local-1'), isEmpty);
      expect(await theirs.unsyncedCount(), 0);
    });

    test('can open their own audit of the same room', () async {
      await mine.insertAudit(openAudit());
      await theirs.insertAudit(openAudit(localId: 'local-2', userId: 'user-2'));

      expect((await theirs.openAuditFor(lab1.id))!.localId, 'local-2');
    });

    test('cannot change my audit or scans', () async {
      await mine.insertAudit(openAudit());
      await mine.addScan(scan('s-1'));

      await theirs.setServerId('local-1', 'srv-x');
      await theirs.markSynced([
        const SyncedScan(clientScanId: 's-1', result: ScanResult.unknown),
      ], DateTime.utc(2026, 11, 25, 3));
      await theirs.deleteAudit('local-1');

      expect((await mine.audit('local-1'))!.serverId, isNull);
      expect((await mine.scans('local-1')).single.isSynced, isFalse);
    });
  });
}
