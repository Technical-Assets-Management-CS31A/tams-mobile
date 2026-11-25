import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_failure.dart';
import '../../domain/entities/audit_room.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/roster.dart';
import '../../domain/repositories/audit_repository.dart';
import '../datasources/audit_remote_datasource.dart';

class AuditRepositoryImpl implements AuditRepository {
  const AuditRepositoryImpl(this._remote);

  final AuditRemoteDataSource _remote;

  @override
  Future<RoomsPage> rooms({String query = '', int page = 1}) =>
      _guard(() => _remote.rooms(query: query, page: page));

  @override
  Future<Roster> roster(String roomId) => _guard(() => _remote.roster(roomId));

  @override
  Future<(ServerAudit, Roster)> start(String roomId) =>
      _guard(() => _remote.start(roomId));

  @override
  Future<List<ServerAudit>> audits({
    required String roomId,
    AuditStatus? status,
  }) => _guard(() => _remote.audits(roomId: roomId, status: status));

  @override
  Future<ScanBatchResult> sendScans(String auditId, List<AuditScan> scans) =>
      _guard(() => _remote.sendScans(auditId, scans));

  @override
  Future<AuditDetail> complete(String auditId) =>
      _guard(() => _remote.complete(auditId));

  @override
  Future<AuditDetail> detail(String auditId) =>
      _guard(() => _remote.detail(auditId));

  @override
  Future<ServerAudit> signOff(String auditId) =>
      _guard(() => _remote.signOff(auditId));

  @override
  Future<void> downloadReport(String auditId, String savePath) =>
      _guard(() => _remote.downloadReport(auditId, savePath));

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw failureOf(e);
    } on FormatException {
      throw const AuditFailure('Unexpected response from the server.');
    }
  }

  static AuditFailure failureOf(DioException e) {
    final code = Failure.errorCode(e);
    final offline = switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      _ => false,
    };
    final message = switch (code) {
      AuditFailure.syncInProgress =>
        'Another sync of these scans is running. Try again in a moment.',
      AuditFailure.notInProgress =>
        'This audit was already completed on another device.',
      AuditFailure.notCompleted => 'Complete the audit first.',
      'ROOM_NOT_FOUND' => 'This room no longer exists.',
      'AUDIT_NOT_FOUND' => 'This audit no longer exists.',
      _ when e.response?.statusCode == 403 =>
        "Your account can't do that. Ask staff if you need audit access.",
      _ => Failure.fromDio(e).message,
    };
    return AuditFailure(message, code: code, offline: offline);
  }
}
