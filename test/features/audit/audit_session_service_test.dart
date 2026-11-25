import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/audit/data/datasources/audit_local_datasource.dart';
import 'package:tams_mobile/features/audit/data/local/audit_database.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_failure.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_scan.dart';
import 'package:tams_mobile/features/audit/domain/entities/roster.dart';
import 'package:tams_mobile/features/audit/domain/services/audit_session_service.dart';
import 'package:tams_mobile/features/audit/domain/services/audit_sync_service.dart';

import '../../helpers/audit_fixtures.dart';
import '../../helpers/fake_audit_repository.dart';

void main() {
  late AuditDatabase database;
  late AuditLocalDataSource store;
  late FakeAuditRepository server;
  late AuditSessionService sessions;
  final phoneTime = DateTime.utc(2026, 11, 25, 1, 30);
  var ids = 0;

  setUp(() async {
    database = await memoryAuditDatabase();
    store = AuditLocalDataSource(database, userId: 'user-1');
    server = FakeAuditRepository();
    sessions = AuditSessionService(
      repository: server,
      store: store,
      clock: () => phoneTime,
      newId: () => 'local-${++ids}',
    );
  });

  tearDown(() => database.close());

  group('start', () {
    test('online creates the server audit and saves its roster', () async {
      final audit = await sessions.start(lab1, online: true);

      expect(server.startCalls, 1);
      expect(audit.serverId, isNotNull);
      expect(audit.startedAt, phoneTime);
      expect((await store.audit(audit.localId))!.serverId, audit.serverId);
      expect((await store.roster(lab1.id))!.items, hasLength(3));
    });

    test('offline creates a local audit from the downloaded roster', () async {
      await sessions.downloadRoster(lab1);

      final audit = await sessions.start(lab1, online: false);

      expect(server.startCalls, 0);
      expect(audit.serverId, isNull);
      expect(audit.isOpen, isTrue);
    });

    test('offline without a roster explains what to do', () async {
      await expectLater(
        sessions.start(lab1, online: false),
        throwsA(
          isA<AuditFailure>().having(
            (f) => f.code,
            'code',
            AuditFailure.noRoster,
          ),
        ),
      );
    });

    test('falls back to offline when the server is unreachable', () async {
      await sessions.downloadRoster(lab1);
      server.offline = true;

      final audit = await sessions.start(lab1, online: true);

      expect(audit.serverId, isNull);
    });

    test(
      'resumes the open audit of a room instead of starting another',
      () async {
        final first = await sessions.start(lab1, online: true);

        final again = await sessions.start(lab1, online: true);

        expect(again.localId, first.localId);
        expect(server.startCalls, 1);
        expect(await store.openAudits(), hasLength(1));
      },
    );

    test('online continues an audit I left open on the server', () async {
      final mine = server.seedAudit();

      final audit = await sessions.start(lab1, online: true);

      expect(server.startCalls, 0);
      expect(audit.serverId, mine.id);
      expect(audit.startedAt, mine.startedAt);
      expect((await store.roster(lab1.id))!.items, hasLength(3));
    });

    test("online does not continue someone else's audit", () async {
      final theirs = server.seedAudit(startedBy: 'user-2');

      final audit = await sessions.start(lab1, online: true);

      expect(server.startCalls, 1);
      expect(audit.serverId, isNot(theirs.id));
    });

    test('a server error is not hidden', () async {
      final s = AuditSessionService(
        repository: _FailingStart(),
        store: store,
        clock: () => phoneTime,
        newId: () => 'local-x',
      );

      await expectLater(
        s.start(lab1, online: true),
        throwsA(isA<AuditFailure>()),
      );
      expect(await store.openAudits(), isEmpty);
    });
  });

  group('complete', () {
    late LocalAudit audit;

    setUp(() async {
      audit = await sessions.start(lab1, online: true);
      await store.addScan(scan('s-1', localAuditId: audit.localId));
    });

    test('is refused while scans are waiting to sync', () async {
      await expectLater(sessions.complete(audit), throwsA(isA<AuditFailure>()));
      expect(server.completeCalls, 0);
    });

    test('stores the server counts and clears the scans', () async {
      await _syncAll(server, store);

      final detail = await sessions.complete(audit);

      expect(detail.withResult(ScanResult.missing), hasLength(2));
      final done = (await store.audit(audit.localId))!;
      expect(done.status, AuditStatus.completed);
      expect(done.counts!.matched, 1);
      expect(done.counts!.missing, 2);
      expect(await store.scans(audit.localId), isEmpty);
    });

    test('a lost response to complete still completes it locally', () async {
      await _syncAll(server, store);
      server.loseNextCompleteResponse = true;
      await expectLater(sessions.complete(audit), throwsA(isA<AuditFailure>()));

      final detail = await sessions.complete(audit);

      expect(detail.audit.status, AuditStatus.completed);
      expect((await store.audit(audit.localId))!.status, AuditStatus.completed);
    });
  });

  test('discarding an audit removes it and its scans', () async {
    final audit = await sessions.start(lab1, online: true);
    await store.addScan(scan('s-1', localAuditId: audit.localId));

    await sessions.discard(audit);

    expect(await store.audit(audit.localId), isNull);
    expect(await store.unsyncedCount(), 0);
  });
}

Future<void> _syncAll(FakeAuditRepository server, AuditLocalDataSource store) =>
    AuditSyncService(
      repository: server,
      store: store,
      clock: DateTime.now,
    ).sync();

class _FailingStart extends FakeAuditRepository {
  @override
  Future<(ServerAudit, Roster)> start(String roomId) async =>
      throw const AuditFailure('Room not found.', code: 'ROOM_NOT_FOUND');
}
