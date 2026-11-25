import '../entities/audit.dart';
import '../entities/audit_room.dart';
import '../entities/audit_scan.dart';
import '../entities/roster.dart';

abstract interface class AuditRepository {
  Future<RoomsPage> rooms({String query = '', int page = 1});

  Future<Roster> roster(String roomId);

  Future<(ServerAudit, Roster)> start(String roomId);

  Future<List<ServerAudit>> audits({
    required String roomId,
    AuditStatus? status,
  });

  Future<ScanBatchResult> sendScans(String auditId, List<AuditScan> scans);

  Future<AuditDetail> complete(String auditId);

  Future<AuditDetail> detail(String auditId);

  Future<ServerAudit> signOff(String auditId);

  Future<void> downloadReport(String auditId, String savePath);
}
