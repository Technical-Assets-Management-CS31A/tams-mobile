import 'dart:io';

import 'package:tams_mobile/features/audit/domain/asset_qr.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_failure.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_room.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_scan.dart';
import 'package:tams_mobile/features/audit/domain/entities/roster.dart';
import 'package:tams_mobile/features/audit/domain/repositories/audit_repository.dart';

import 'audit_fixtures.dart';

const unreachable = AuditFailure(
  "Can't reach the server. Check your internet connection.",
  offline: true,
);

class FakeAuditRepository implements AuditRepository {
  FakeAuditRepository({this.userId = 'user-1', Roster? lab1Roster})
    : rosters = {lab1.id: lab1Roster ?? labRoster()};

  final String userId;
  final Map<String, Roster> rosters;
  final roomList = <AuditRoom>[lab1, storageRoom];
  final elsewhere = <String, RosterItem>{
    strayAsset: const RosterItem(
      assetId: strayAsset,
      assetCode: 'PRJ-07',
      name: 'Projector 07',
    ),
  };

  final serverAudits = <String, ServerAudit>{};
  final stored = <String, Map<String, SyncedScan>>{};
  final sent = <List<String>>[];
  final sendFailures = <Object>[];
  int startCalls = 0;
  int completeCalls = 0;
  bool offline = false;

  /// When set, room lists wait for it, e.g. a server that never answers.
  Future<void>? roomsAnswer;

  /// When set, completing an audit waits for it, e.g. a slow submit.
  Future<void>? completeAnswer;
  bool loseNextResponse = false;
  bool loseNextCompleteResponse = false;
  int? answerOnly;
  final signedOff = <String>[];
  final reports = <String>[];
  var _ids = 0;

  void _reach() {
    if (offline) throw unreachable;
  }

  ServerAudit seedAudit({
    String? id,
    String roomId = 'room-lab1',
    String? startedBy,
    AuditStatus status = AuditStatus.inProgress,
  }) {
    final audit = ServerAudit(
      id: id ?? 'srv-${++_ids}',
      roomId: roomId,
      status: status,
      startedByUserId: startedBy ?? userId,
      startedAt: DateTime.utc(2026, 11, 25, 2, _ids),
      completedAt: status == AuditStatus.inProgress
          ? null
          : DateTime.utc(2026, 11, 25, 4),
      counts: status == AuditStatus.inProgress
          ? null
          : const AuditCounts(
              expected: 3,
              matched: 2,
              missing: 1,
              misplaced: 0,
              unknown: 0,
            ),
    );
    serverAudits[audit.id] = audit;
    stored[audit.id] = {};
    return audit;
  }

  @override
  Future<RoomsPage> rooms({String query = '', int page = 1}) async {
    if (roomsAnswer case final answer?) await answer;
    _reach();
    final q = query.trim().toLowerCase();
    final matching = [
      for (final r in roomList)
        if (q.isEmpty ||
            r.code.toLowerCase().contains(q) ||
            r.name.toLowerCase().contains(q))
          r,
    ];
    return RoomsPage(
      items: page == 1 ? matching : const [],
      page: page,
      total: matching.length,
    );
  }

  @override
  Future<Roster> roster(String roomId) async {
    _reach();
    return rosters[roomId] ??
        Roster(
          room: roomList.firstWhere((r) => r.id == roomId),
          items: const [],
          downloadedAt: DateTime.utc(2026, 11, 25, 1),
        );
  }

  @override
  Future<(ServerAudit, Roster)> start(String roomId) async {
    _reach();
    startCalls++;
    return (seedAudit(roomId: roomId), await roster(roomId));
  }

  @override
  Future<List<ServerAudit>> audits({
    required String roomId,
    AuditStatus? status,
  }) async {
    _reach();
    return [
      for (final a in serverAudits.values.toList().reversed)
        if (a.roomId == roomId && (status == null || a.status == status)) a,
    ];
  }

  @override
  Future<ScanBatchResult> sendScans(
    String auditId,
    List<AuditScan> scans,
  ) async {
    _reach();
    sent.add([for (final s in scans) s.clientScanId]);
    if (sendFailures.isNotEmpty) throw sendFailures.removeAt(0);
    final audit = serverAudits[auditId]!;
    if (audit.status != AuditStatus.inProgress) {
      throw const AuditFailure(
        'This audit was already completed on another device.',
        code: AuditFailure.notInProgress,
      );
    }
    final kept = stored[auditId]!;
    final results = <SyncedScan>[];
    var accepted = 0;
    for (final s in scans) {
      final known = kept[s.clientScanId];
      if (known != null) {
        results.add(
          SyncedScan(
            clientScanId: s.clientScanId,
            result: known.result,
            assetId: known.assetId,
            duplicate: true,
          ),
        );
        continue;
      }
      final assetId = parseAssetQr(s.scannedValue);
      final home = assetId == null
          ? null
          : rosters[audit.roomId]!.item(assetId);
      final other = assetId == null ? null : elsewhere[assetId];
      final item = home ?? other;
      final result = SyncedScan(
        clientScanId: s.clientScanId,
        result: home != null
            ? ScanResult.matched
            : other != null
            ? ScanResult.misplaced
            : ScanResult.unknown,
        assetId: item?.assetId,
        assetCode: item?.assetCode,
        name: item?.name,
      );
      kept[s.clientScanId] = result;
      results.add(result);
      accepted++;
    }
    if (loseNextResponse) {
      loseNextResponse = false;
      throw unreachable;
    }
    final answered = answerOnly == null
        ? results
        : results.take(answerOnly!).toList();
    return ScanBatchResult(
      accepted: accepted,
      duplicates: scans.length - accepted,
      results: answered,
    );
  }

  int storedScans(String auditId) => stored[auditId]?.length ?? 0;

  @override
  Future<AuditDetail> complete(String auditId) async {
    if (completeAnswer case final answer?) await answer;
    _reach();
    completeCalls++;
    final audit = serverAudits[auditId]!;
    if (audit.status != AuditStatus.inProgress) {
      throw const AuditFailure(
        'This audit was already completed on another device.',
        code: AuditFailure.notInProgress,
      );
    }
    serverAudits[auditId] = _completed(audit);
    if (loseNextCompleteResponse) {
      loseNextCompleteResponse = false;
      throw unreachable;
    }
    return detail(auditId);
  }

  ServerAudit _completed(ServerAudit audit) {
    final kept = stored[audit.id]!.values;
    final matched = {
      for (final s in kept)
        if (s.result == ScanResult.matched) s.assetId,
    };
    final expected = rosters[audit.roomId]!.items.length;
    return ServerAudit(
      id: audit.id,
      roomId: audit.roomId,
      status: AuditStatus.completed,
      startedByUserId: audit.startedByUserId,
      startedAt: audit.startedAt,
      completedAt: DateTime.utc(2026, 11, 25, 4),
      counts: AuditCounts(
        expected: expected,
        matched: matched.length,
        missing: expected - matched.length,
        misplaced: kept.where((s) => s.result == ScanResult.misplaced).length,
        unknown: kept.where((s) => s.result == ScanResult.unknown).length,
      ),
    );
  }

  @override
  Future<AuditDetail> detail(String auditId) async {
    _reach();
    final audit = serverAudits[auditId]!;
    final kept = stored[auditId]!.values;
    final matched = {
      for (final s in kept)
        if (s.result == ScanResult.matched) s.assetId,
    };
    return AuditDetail(
      audit: audit,
      items: [
        for (final s in kept)
          AuditLine(
            result: s.result,
            scannedValue: s.assetId ?? '',
            assetId: s.assetId,
            assetCode: s.assetCode,
            name: s.name,
          ),
        if (audit.status != AuditStatus.inProgress)
          for (final i in rosters[audit.roomId]!.items)
            if (!matched.contains(i.assetId))
              AuditLine(
                result: ScanResult.missing,
                scannedValue: 'tams:asset:${i.assetId}',
                assetId: i.assetId,
                assetCode: i.assetCode,
                name: i.name,
              ),
      ],
    );
  }

  @override
  Future<ServerAudit> signOff(String auditId) async {
    _reach();
    signedOff.add(auditId);
    final a = serverAudits[auditId]!;
    return serverAudits[auditId] = ServerAudit(
      id: a.id,
      roomId: a.roomId,
      status: AuditStatus.signedOff,
      startedByUserId: a.startedByUserId,
      startedAt: a.startedAt,
      completedAt: a.completedAt,
      signedOffAt: DateTime.utc(2026, 11, 25, 5),
      counts: a.counts,
    );
  }

  @override
  Future<void> downloadReport(String auditId, String savePath) async {
    _reach();
    reports.add(auditId);
    await File(savePath).writeAsBytes([0x25, 0x50, 0x44, 0x46]);
  }
}
