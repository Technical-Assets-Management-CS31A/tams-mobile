import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/audit/data/datasources/audit_remote_datasource.dart';
import 'package:tams_mobile/features/audit/data/repositories/audit_repository_impl.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_failure.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_scan.dart';

import '../../helpers/audit_fixtures.dart';
import '../../helpers/route_http_adapter.dart';

Map<String, Object?> serverAudit({
  String id = 'srv-1',
  String status = 'IN_PROGRESS',
  String startedBy = 'user-1',
}) => {
  'id': id,
  'roomId': lab1.id,
  'source': 'MOBILE',
  'status': status,
  'startedByUserId': startedBy,
  'startedAt': '2026-11-25T02:00:00+00:00',
  'completedAt': null,
  'signedOffByUserId': null,
  'signedOffAt': null,
  'expectedCount': 3,
  'matchedCount': 0,
  'missingCount': 0,
  'misplacedCount': 0,
  'unknownCount': 0,
  'importFileId': null,
  'reportPdfUrl': '/api/audits/$id/report?format=pdf',
};

const rosterJson = [
  {
    'id': assetA,
    'assetCode': 'PC-01',
    'name': 'Desktop 01',
    'category': 'Desktops',
    'type': 'FIXED',
    'status': 'IN_STORAGE',
    'serialNo': null,
    'qrPayload': 'tams:asset:$assetA',
  },
  {
    'id': assetC,
    'assetCode': 'LPT-01',
    'name': 'Laptop 01',
    'category': 'Laptops',
    'type': 'BORROWABLE',
    'status': 'IN_TRANSIT',
    'serialNo': 'SN-1',
    'qrPayload': 'tams:asset:$assetC',
  },
];

void main() {
  late RouteHttpAdapter http;
  late AuditRepositoryImpl repo;
  final now = DateTime.utc(2026, 11, 25, 5);

  setUp(() {
    http = RouteHttpAdapter((r) => ok());
    repo = AuditRepositoryImpl(
      AuditRemoteDataSource(routeDio(http), now: () => now),
    );
  });

  test('rooms asks for a page and parses each room', () async {
    http.reply = (r) => ok({
      'items': [
        {
          'id': lab1.id,
          'code': 'CL1',
          'name': 'Computer Lab 1',
          'building': 'Main',
          'floor': 2,
          'isStorage': false,
          'status': 'ACTIVE',
        },
        {'name': 'no id'},
      ],
      'total': 1,
      'page': 2,
      'pageSize': 50,
    });

    final page = await repo.rooms(query: ' lab ', page: 2);

    expect(http.requests.single.path, '/rooms');
    expect(http.requests.single.queryParameters, {
      'q': 'lab',
      'page': 2,
      'pageSize': 50,
    });
    expect(page.items.single.label, 'CL1 · Computer Lab 1');
    expect(page.items.single.place, 'Main · Floor 2');
    expect(page.page, 2);
  });

  test('roster parses the items and when it was downloaded', () async {
    http.reply = (r) => ok({
      'room': {'id': lab1.id, 'code': 'CL1', 'name': 'Computer Lab 1'},
      'items': rosterJson,
      'downloadedAt': '2026-11-25T01:00:00Z',
    });

    final roster = await repo.roster(lab1.id);

    expect(http.requests.single.path, '/rooms/${lab1.id}/roster');
    expect(roster.items.map((i) => i.assetCode), ['PC-01', 'LPT-01']);
    expect(roster.item(assetC)!.isOnLoan, isTrue);
    expect(roster.downloadedAt.toUtc(), DateTime.utc(2026, 11, 25, 1));
  });

  test('start returns the audit and its roster', () async {
    http.reply = (r) => (
      status: 201,
      body: {
        'audit': serverAudit(),
        'room': {'id': lab1.id, 'code': 'CL1', 'name': 'Computer Lab 1'},
        'roster': rosterJson,
      },
    );

    final (audit, roster) = await repo.start(lab1.id);

    expect(http.requests.single.data, {'roomId': lab1.id});
    expect(audit.id, 'srv-1');
    expect(audit.status, AuditStatus.inProgress);
    expect(audit.startedByUserId, 'user-1');
    expect(roster.items, hasLength(2));
    expect(roster.downloadedAt, now);
  });

  test('audits filters by room and status', () async {
    http.reply = (r) => ok({
      'items': [serverAudit()],
      'page': 1,
      'pageSize': 20,
      'total': 1,
    });

    final audits = await repo.audits(
      roomId: lab1.id,
      status: AuditStatus.inProgress,
    );

    expect(http.requests.single.queryParameters, {
      'roomId': lab1.id,
      'status': 'IN_PROGRESS',
      'pageSize': 20,
    });
    expect(audits.single.counts!.expected, 3);
  });

  test('sendScans posts the queue and parses the results', () async {
    http.reply = (r) => ok({
      'auditId': 'srv-1',
      'accepted': 1,
      'duplicates': 1,
      'results': [
        {
          'clientScanId': 's-1',
          'result': 'MATCHED',
          'assetId': assetA,
          'duplicate': false,
          'assetCode': 'PC-01',
          'name': 'Desktop 01',
        },
        {
          'clientScanId': 's-2',
          'result': 'MISPLACED',
          'assetId': strayAsset,
          'duplicate': true,
        },
      ],
    });

    final batch = await repo.sendScans('srv-1', [
      scan('s-1', at: DateTime.utc(2026, 11, 25, 2, 5)),
    ]);

    final sent = http.requests.single;
    expect(sent.path, '/audits/srv-1/scans:batch');
    expect(sent.data, {
      'scans': [
        {
          'clientScanId': 's-1',
          'scannedValue': 'tams:asset:$assetA',
          'scannedAt': '2026-11-25T02:05:00.000Z',
        },
      ],
    });
    expect(batch.accepted, 1);
    expect(batch.results.last.result, ScanResult.misplaced);
    expect(batch.results.last.duplicate, isTrue);
  });

  test('complete returns the server counts and items', () async {
    http.reply = (r) => ok({
      'audit': serverAudit(status: 'COMPLETED'),
      'items': [
        {
          'id': 'i-1',
          'result': 'MISSING',
          'assetId': assetB,
          'assetCode': 'PC-02',
          'name': 'Desktop 02',
          'scannedValue': 'tams:asset:$assetB',
          'scannedAt': '2026-11-25T03:00:00Z',
          'syncedAt': '2026-11-25T03:00:00Z',
        },
      ],
    });

    final detail = await repo.complete('srv-1');

    expect(http.requests.single.path, '/audits/srv-1/complete');
    expect(detail.audit.status, AuditStatus.completed);
    expect(detail.withResult(ScanResult.missing).single.assetCode, 'PC-02');
  });

  test('a 409 keeps its code', () async {
    http.reply = (r) => problem(409, AuditFailure.syncInProgress);

    await expectLater(
      repo.sendScans('srv-1', [scan('s-1')]),
      throwsA(
        isA<AuditFailure>()
            .having((f) => f.code, 'code', AuditFailure.syncInProgress)
            .having((f) => f.offline, 'offline', isFalse),
      ),
    );
  });

  test('no connection is an offline failure', () async {
    http.reply = offline;

    await expectLater(
      repo.rooms(),
      throwsA(isA<AuditFailure>().having((f) => f.offline, 'offline', true)),
    );
  });

  test('an unexpected body is a failure', () async {
    http.reply = (r) => ok({'data': []});

    await expectLater(
      repo.rooms(),
      throwsA(
        isA<AuditFailure>().having(
          (f) => f.message,
          'message',
          'Unexpected response from the server.',
        ),
      ),
    );
  });
}
