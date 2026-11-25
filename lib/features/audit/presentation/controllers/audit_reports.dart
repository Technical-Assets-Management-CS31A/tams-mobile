import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/audit.dart';
import '../../domain/repositories/audit_repository.dart';
import 'audit_providers.dart';

class AuditReports {
  AuditReports(this._repository, {this._tempDir = getTemporaryDirectory});

  final AuditRepository _repository;
  final Future<Directory> Function() _tempDir;

  Future<String> download(String auditId, String roomCode) async {
    final dir = await _tempDir();
    final room = roomCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final id = auditId.length > 8 ? auditId.substring(0, 8) : auditId;
    final path = p.join(dir.path, 'audit-$room-$id.pdf');
    await _repository.downloadReport(auditId, path);
    return path;
  }

  Future<void> open(String auditId, String roomCode) async {
    final path = await download(auditId, roomCode);
    final result = await OpenFilex.open(path, type: 'application/pdf');
    if (result.type == ResultType.done) return;
    throw Failure(
      result.type == ResultType.noAppToOpen
          ? 'No app on this phone opens PDFs. Share the report instead.'
          : "Couldn't open the report.",
    );
  }

  Future<void> share(String auditId, String roomCode, {Rect? origin}) async {
    final path = await download(auditId, roomCode);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/pdf')],
        subject: 'TAMS audit report for $roomCode',
        sharePositionOrigin: origin,
      ),
    );
  }
}

final auditReportsProvider = Provider<AuditReports>(
  (ref) => AuditReports(ref.watch(auditRepositoryProvider)),
);

final roomAuditsProvider = FutureProvider.autoDispose
    .family<List<ServerAudit>, String>((ref, roomId) async {
      final audits = await ref
          .watch(auditRepositoryProvider)
          .audits(roomId: roomId);
      return [
        for (final a in audits)
          if (a.status != AuditStatus.inProgress) a,
      ];
    });
