import 'package:dio/dio.dart';

import '../../../../core/utils/clock.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/roster.dart';
import '../models/audit_models.dart';

class AuditRemoteDataSource {
  const AuditRemoteDataSource(this._dio, {this._now = DateTime.now});

  final Dio _dio;
  final Clock _now;

  static const roomsPageSize = 50;

  static String _audit(String id) => '/audits/${Uri.encodeComponent(id)}';

  Future<RoomsPage> rooms({String query = '', int page = 1}) async {
    final res = await _dio.get<Object?>(
      '/rooms',
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'pageSize': roomsPageSize,
      },
    );
    return parseRoomsPage(res.data);
  }

  Future<Roster> roster(String roomId) async {
    final res = await _dio.get<Object?>(
      '/rooms/${Uri.encodeComponent(roomId)}/roster',
    );
    return parseRoster(res.data, fallbackDownloadedAt: _now());
  }

  Future<(ServerAudit, Roster)> start(String roomId) async {
    final res = await _dio.post<Object?>('/audits', data: {'roomId': roomId});
    return parseStartedAudit(res.data, downloadedAt: _now());
  }

  Future<List<ServerAudit>> audits({
    required String roomId,
    AuditStatus? status,
  }) async {
    final res = await _dio.get<Object?>(
      '/audits',
      queryParameters: {
        'roomId': roomId,
        'status': ?status?.label,
        'pageSize': 20,
      },
    );
    return parseAuditsPage(res.data);
  }

  Future<ScanBatchResult> sendScans(
    String auditId,
    List<AuditScan> scans,
  ) async {
    final res = await _dio.post<Object?>(
      '${_audit(auditId)}/scans:batch',
      data: {
        'scans': [
          for (final s in scans)
            {
              'clientScanId': s.clientScanId,
              'scannedValue': s.scannedValue,
              'scannedAt': s.scannedAt.toUtc().toIso8601String(),
            },
        ],
      },
    );
    return parseScanBatch(res.data);
  }

  Future<AuditDetail> complete(String auditId) async {
    final res = await _dio.post<Object?>('${_audit(auditId)}/complete');
    return parseAuditDetail(res.data);
  }

  Future<AuditDetail> detail(String auditId) async {
    final res = await _dio.get<Object?>(_audit(auditId));
    return parseAuditDetail(res.data);
  }

  Future<ServerAudit> signOff(String auditId) async {
    final res = await _dio.post<Object?>('${_audit(auditId)}/sign-off');
    return parseServerAudit(res.data);
  }

  Future<void> downloadReport(String auditId, String savePath) => _dio.download(
    '${_audit(auditId)}/report',
    savePath,
    queryParameters: {'format': 'pdf'},
    options: Options(headers: {'Accept': 'application/pdf'}),
  );
}
