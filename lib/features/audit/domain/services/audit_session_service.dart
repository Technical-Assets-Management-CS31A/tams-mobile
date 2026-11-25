import '../../../../core/utils/clock.dart';
import '../entities/audit.dart';
import '../entities/audit_failure.dart';
import '../entities/audit_room.dart';
import '../entities/audit_scan.dart';
import '../entities/roster.dart';
import '../repositories/audit_repository.dart';
import '../repositories/audit_store.dart';

class AuditSessionService {
  AuditSessionService({
    required this._repository,
    required this._store,
    required this._clock,
    required this._newId,
  });

  final AuditRepository _repository;
  final AuditStore _store;
  final Clock _clock;
  final String Function() _newId;

  Future<Roster> downloadRoster(AuditRoom room) async {
    final roster = await _repository.roster(room.id);
    await _store.saveRoster(roster);
    return roster;
  }

  Future<LocalAudit> start(AuditRoom room, {required bool online}) async {
    final open = await _store.openAuditFor(room.id);
    if (open != null) return open;

    if (online) {
      try {
        return await _startOnServer(room.id);
      } on AuditFailure catch (f) {
        if (!f.offline) rethrow;
      }
    }

    if (await _store.roster(room.id) == null) {
      throw const AuditFailure(
        "Download this room's roster first to audit it offline.",
        code: AuditFailure.noRoster,
      );
    }
    return _insert(room.id);
  }

  /// Continues an audit of the room I left open on the server, e.g. from
  /// another phone or before a reinstall, or starts a new one.
  Future<LocalAudit> _startOnServer(String roomId) async {
    final open = await _repository.audits(
      roomId: roomId,
      status: AuditStatus.inProgress,
    );
    final mine = open
        .where((a) => a.startedByUserId == _store.userId)
        .firstOrNull;
    if (mine != null) {
      await _store.saveRoster(await _repository.roster(roomId));
      return _insert(roomId, serverId: mine.id, startedAt: mine.startedAt);
    }
    final (server, roster) = await _repository.start(roomId);
    await _store.saveRoster(roster);
    return _insert(roomId, serverId: server.id);
  }

  Future<LocalAudit> _insert(
    String roomId, {
    String? serverId,
    DateTime? startedAt,
  }) async {
    final audit = LocalAudit(
      localId: _newId(),
      serverId: serverId,
      userId: _store.userId,
      roomId: roomId,
      status: AuditStatus.inProgress,
      startedAt: startedAt ?? _clock(),
    );
    await _store.insertAudit(audit);
    return audit;
  }

  Future<AuditDetail> complete(LocalAudit audit) async {
    final serverId = audit.serverId;
    if (serverId == null ||
        await _store.unsyncedCount(localAuditId: audit.localId) > 0) {
      throw const AuditFailure(
        'Some scans are still waiting to sync. Sync them before submitting.',
      );
    }

    AuditDetail detail;
    try {
      detail = await _repository.complete(serverId);
    } on AuditFailure catch (f) {
      if (f.code != AuditFailure.notInProgress) rethrow;
      detail = await _repository.detail(serverId);
      if (detail.audit.status == AuditStatus.inProgress) rethrow;
    }

    await _store.completeAudit(
      audit.localId,
      counts: detail.audit.counts ?? _countsOf(detail),
      completedAt: detail.audit.completedAt ?? _clock(),
    );
    return detail;
  }

  Future<void> discard(LocalAudit audit) => _store.deleteAudit(audit.localId);

  static AuditCounts _countsOf(AuditDetail d) {
    final matched = d.withResult(ScanResult.matched).length;
    final missing = d.withResult(ScanResult.missing).length;
    return AuditCounts(
      expected: matched + missing,
      matched: matched,
      missing: missing,
      misplaced: d.withResult(ScanResult.misplaced).length,
      unknown: d.withResult(ScanResult.unknown).length,
    );
  }
}
