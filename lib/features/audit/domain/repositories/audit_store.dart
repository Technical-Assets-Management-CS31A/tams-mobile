import '../entities/audit.dart';
import '../entities/audit_room.dart';
import '../entities/audit_scan.dart';
import '../entities/roster.dart';

abstract interface class AuditStore {
  String get userId;

  Future<void> cacheRooms(List<AuditRoom> rooms);

  /// Saves [rooms] as this user's whole room list, dropping saved rooms
  /// the server no longer returns.
  Future<void> replaceRooms(List<AuditRoom> rooms);

  Future<List<AuditRoom>> cachedRooms({String query = ''});

  Future<void> saveRoster(Roster roster);

  Future<Roster?> roster(String roomId);

  Future<Map<String, RosterInfo>> rosterInfos();

  Future<void> insertAudit(LocalAudit audit);

  Future<LocalAudit?> audit(String localId);

  Future<List<LocalAudit>> openAudits();

  Future<List<LocalAudit>> unfinishedAudits();

  Future<LocalAudit?> openAuditFor(String roomId);

  Future<void> setServerId(String localId, String serverId);

  Future<void> markEndedElsewhere(String localId);

  Future<void> completeAudit(
    String localId, {
    required AuditCounts counts,
    required DateTime completedAt,
  });

  /// Records the sign-off of a submitted audit.
  Future<void> markSignedOff(String localId);

  Future<void> deleteAudit(String localId);

  Future<bool> addScan(AuditScan scan);

  Future<List<AuditScan>> scans(String localAuditId);

  Future<List<AuditScan>> unsyncedScans(String localAuditId, {int? limit});

  Future<int> unsyncedCount({String? localAuditId});

  Future<void> markSynced(List<SyncedScan> results, DateTime syncedAt);
}
