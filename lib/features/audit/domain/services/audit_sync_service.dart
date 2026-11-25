import '../../../../core/utils/clock.dart';
import '../entities/audit.dart';
import '../entities/audit_failure.dart';
import '../entities/audit_scan.dart';
import '../entities/roster.dart';
import '../repositories/audit_repository.dart';
import '../repositories/audit_store.dart';

class SyncReport {
  const SyncReport({
    this.sent = 0,
    this.offline = false,
    this.endedElsewhere = const [],
    this.error,
  });

  final int sent;
  final bool offline;
  final List<String> endedElsewhere;
  final AuditFailure? error;

  bool get ok => !offline && error == null && endedElsewhere.isEmpty;
}

class AuditSyncService {
  AuditSyncService({
    required this._repository,
    required this._store,
    required this._clock,
    this.batchSize = 500,
    this.retryDelay = const Duration(seconds: 2),
    this.maxRetries = 3,
  });

  final AuditRepository _repository;
  final AuditStore _store;
  final Clock _clock;
  final int batchSize;
  final Duration retryDelay;
  final int maxRetries;

  Future<SyncReport>? _running;
  bool _again = false;

  bool get isRunning => _running != null;

  Future<SyncReport> sync() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _loop().whenComplete(() => _running = null);
  }

  Future<SyncReport> _loop() async {
    SyncReport report;
    do {
      _again = false;
      report = await _once();
    } while (_again && !report.offline);
    return report;
  }

  Future<SyncReport> _once() async {
    var sent = 0;
    final ended = <String>[];
    AuditFailure? error;
    for (final audit in await _store.openAudits()) {
      try {
        sent += await _syncAudit(audit);
      } on AuditFailure catch (f) {
        if (f.offline) {
          return SyncReport(sent: sent, offline: true, endedElsewhere: ended);
        }
        if (f.code == AuditFailure.notInProgress) {
          await _store.markEndedElsewhere(audit.localId);
          ended.add(audit.localId);
        } else {
          error = f;
        }
      }
    }
    return SyncReport(sent: sent, endedElsewhere: ended, error: error);
  }

  Future<int> _syncAudit(LocalAudit audit) async {
    final serverId = audit.serverId ?? await _createOnServer(audit);
    var sent = 0;
    while (true) {
      final batch = await _store.unsyncedScans(audit.localId, limit: batchSize);
      if (batch.isEmpty) return sent;

      final result = await _send(serverId, batch);
      final ids = {for (final s in batch) s.clientScanId};
      final roster = await _store.roster(audit.roomId);
      final synced = [
        for (final r in result.results)
          if (ids.contains(r.clientScanId)) _named(r, roster),
      ];
      if (synced.isEmpty) return sent;

      await _store.markSynced(synced, _clock());
      sent += synced.length;
      if (synced.length < batch.length) return sent;
    }
  }

  Future<String> _createOnServer(LocalAudit audit) async {
    final open = await _repository.audits(
      roomId: audit.roomId,
      status: AuditStatus.inProgress,
    );
    final mine = open.where((a) => a.startedByUserId == _store.userId);
    final String serverId;
    if (mine.isNotEmpty) {
      serverId = mine.first.id;
    } else {
      final (server, roster) = await _repository.start(audit.roomId);
      await _store.saveRoster(roster);
      serverId = server.id;
    }
    await _store.setServerId(audit.localId, serverId);
    return serverId;
  }

  Future<ScanBatchResult> _send(String serverId, List<AuditScan> batch) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _repository.sendScans(serverId, batch);
      } on AuditFailure catch (f) {
        if (f.code != AuditFailure.syncInProgress || attempt > maxRetries) {
          rethrow;
        }
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  static SyncedScan _named(SyncedScan r, Roster? roster) {
    final assetId = r.assetId;
    if (r.assetCode != null || assetId == null) return r;
    final item = roster?.item(assetId);
    if (item == null) return r;
    return SyncedScan(
      clientScanId: r.clientScanId,
      result: r.result,
      assetId: assetId,
      assetCode: item.assetCode,
      name: item.name,
      duplicate: r.duplicate,
    );
  }
}
