import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/audit/data/datasources/audit_local_datasource.dart';
import 'package:tams_mobile/features/audit/data/local/audit_database.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_failure.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_scan.dart';
import 'package:tams_mobile/features/audit/domain/services/audit_sync_service.dart';

import '../../helpers/audit_fixtures.dart';
import '../../helpers/fake_audit_repository.dart';

void main() {
  late AuditDatabase database;
  late AuditLocalDataSource store;
  late FakeAuditRepository server;
  late AuditSyncService sync;

  setUp(() async {
    database = await memoryAuditDatabase();
    store = AuditLocalDataSource(database, userId: 'user-1');
    server = FakeAuditRepository();
    sync = AuditSyncService(
      repository: server,
      store: store,
      clock: () => DateTime.utc(2026, 11, 25, 3),
      retryDelay: Duration.zero,
    );
    await store.saveRoster(labRoster());
  });

  tearDown(() => database.close());

  Future<String> onlineAudit() async {
    final srv = server.seedAudit();
    await store.insertAudit(openAudit(serverId: srv.id));
    return srv.id;
  }

  Future<void> scanAll() async {
    await store.addScan(scan('s-1'));
    await store.addScan(
      scan(
        's-2',
        value: 'tams:asset:$strayAsset',
        assetId: strayAsset,
        result: ScanResult.pending,
      ),
    );
    await store.addScan(
      scan('s-3', value: 'PRJ-??', assetId: null, result: ScanResult.unknown),
    );
  }

  test('sends the queue and stores the server results', () async {
    final id = await onlineAudit();
    await scanAll();

    final report = await sync.sync();

    expect(report.ok, isTrue);
    expect(report.sent, 3);
    expect(server.sent.single, ['s-1', 's-2', 's-3']);
    expect(server.storedScans(id), 3);
    expect(await store.unsyncedCount(), 0);
    final byId = {
      for (final s in await store.scans('local-1')) s.clientScanId: s,
    };
    expect(byId['s-1']!.result, ScanResult.matched);
    expect(byId['s-2']!.result, ScanResult.misplaced);
    expect(byId['s-2']!.assetCode, 'PRJ-07');
    expect(byId['s-2']!.assetName, 'Projector 07');
    expect(byId['s-3']!.result, ScanResult.unknown);
  });

  test('nothing to send does not call the server', () async {
    await onlineAudit();

    final report = await sync.sync();

    expect(report.ok, isTrue);
    expect(server.sent, isEmpty);
  });

  test('a lost response is resent without duplicating scans', () async {
    final id = await onlineAudit();
    await scanAll();
    server.loseNextResponse = true;

    final first = await sync.sync();
    expect(first.offline, isTrue);
    expect(await store.unsyncedCount(), 3);
    expect(server.storedScans(id), 3);

    final second = await sync.sync();
    expect(second.ok, isTrue);
    expect(server.sent, hasLength(2));
    expect(server.sent.last, ['s-1', 's-2', 's-3']);
    expect(server.storedScans(id), 3);
    expect(await store.unsyncedCount(), 0);
    final byId = {
      for (final s in await store.scans('local-1')) s.clientScanId: s,
    };
    expect(byId['s-1']!.assetName, 'Desktop 01');
    expect(byId['s-2']!.result, ScanResult.misplaced);
  });

  test('only scans the server answered for are marked synced', () async {
    final id = await onlineAudit();
    await scanAll();
    server.answerOnly = 2;

    await sync.sync();
    expect(await store.unsyncedCount(), 1);
    expect((await store.unsyncedScans('local-1')).single.clientScanId, 's-3');

    server.answerOnly = null;
    await sync.sync();
    expect(server.sent.last, ['s-3']);
    expect(await store.unsyncedCount(), 0);
    expect(server.storedScans(id), 3);
  });

  test('sends large queues in batches of 500', () async {
    await onlineAudit();
    for (var i = 0; i < 1200; i++) {
      await store.addScan(
        scan(
          's-$i',
          value: 'junk-$i',
          assetId: null,
          result: ScanResult.unknown,
          at: DateTime.utc(2026, 11, 25, 2).add(Duration(seconds: i)),
        ),
      );
    }

    final report = await sync.sync();

    expect(report.sent, 1200);
    expect(server.sent.map((b) => b.length), [500, 500, 200]);
    expect(server.sent.first.first, 's-0');
    expect(await store.unsyncedCount(), 0);
  });

  test('SYNC_IN_PROGRESS is retried after a short delay', () async {
    await onlineAudit();
    await scanAll();
    server.sendFailures.addAll([
      const AuditFailure('busy', code: AuditFailure.syncInProgress),
      const AuditFailure('busy', code: AuditFailure.syncInProgress),
    ]);

    final report = await sync.sync();

    expect(report.ok, isTrue);
    expect(server.sent, hasLength(3));
    expect(await store.unsyncedCount(), 0);
  });

  test('SYNC_IN_PROGRESS that never clears keeps the queue', () async {
    await onlineAudit();
    await scanAll();
    server.sendFailures.addAll([
      for (var i = 0; i < 10; i++)
        const AuditFailure('busy', code: AuditFailure.syncInProgress),
    ]);

    final report = await sync.sync();

    expect(report.error?.code, AuditFailure.syncInProgress);
    expect(server.sent, hasLength(4));
    expect(await store.unsyncedCount(), 3);
  });

  test('AUDIT_NOT_IN_PROGRESS stops syncing that audit', () async {
    final id = await onlineAudit();
    await scanAll();
    server.serverAudits[id] = server.seedAudit(
      id: id,
      status: AuditStatus.completed,
    );

    final report = await sync.sync();

    expect(report.endedElsewhere, ['local-1']);
    expect((await store.audit('local-1'))!.status, AuditStatus.endedElsewhere);
    expect(await store.unsyncedCount(), 0);

    await sync.sync();
    expect(server.sent, hasLength(1));
  });

  test('no connection keeps the queue for the next try', () async {
    await onlineAudit();
    await scanAll();
    server.offline = true;

    final report = await sync.sync();

    expect(report.offline, isTrue);
    expect(await store.unsyncedCount(), 3);

    server.offline = false;
    expect((await sync.sync()).sent, 3);
  });

  group('an audit started offline', () {
    setUp(() async {
      await store.insertAudit(openAudit());
      await scanAll();
    });

    test('is created on the server on reconnect, once', () async {
      final report = await sync.sync();

      expect(report.ok, isTrue);
      expect(server.startCalls, 1);
      final serverId = (await store.audit('local-1'))!.serverId;
      expect(serverId, isNotNull);
      expect(server.storedScans(serverId!), 3);

      await store.addScan(scan('s-4', value: assetB, assetId: assetB));
      await sync.sync();
      expect(server.startCalls, 1);
      expect(server.storedScans(serverId), 4);
    });

    test('reuses an audit I already started for that room', () async {
      final mine = server.seedAudit();

      await sync.sync();

      expect(server.startCalls, 0);
      expect((await store.audit('local-1'))!.serverId, mine.id);
      expect(server.storedScans(mine.id), 3);
    });

    test("does not reuse someone else's audit", () async {
      final theirs = server.seedAudit(startedBy: 'user-2');

      await sync.sync();

      expect(server.startCalls, 1);
      expect((await store.audit('local-1'))!.serverId, isNot(theirs.id));
    });

    test('keeps the server id when the send then fails', () async {
      server.sendFailures.add(unreachable);

      final report = await sync.sync();

      expect(report.offline, isTrue);
      expect((await store.audit('local-1'))!.serverId, isNotNull);
      await sync.sync();
      expect(server.startCalls, 1);
    });

    test('stays local while offline', () async {
      server.offline = true;

      expect((await sync.sync()).offline, isTrue);
      expect((await store.audit('local-1'))!.serverId, isNull);
    });
  });

  test('runs one sync at a time', () async {
    await onlineAudit();
    await scanAll();

    final results = await Future.wait([sync.sync(), sync.sync(), sync.sync()]);

    expect(results.every((r) => r.ok), isTrue);
    expect(server.sent, hasLength(1));
    expect(await store.unsyncedCount(), 0);
  });

  test("another user's queue is never sent", () async {
    final theirs = AuditLocalDataSource(database, userId: 'user-2');
    await theirs.insertAudit(
      openAudit(localId: 'local-2', userId: 'user-2', serverId: 'srv-x'),
    );
    await theirs.addScan(scan('s-9', localAuditId: 'local-2'));

    await sync.sync();

    expect(server.sent, isEmpty);
    expect(await theirs.unsyncedCount(), 1);
  });
}
