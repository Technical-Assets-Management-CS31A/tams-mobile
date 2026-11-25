import 'audit.dart';

enum ScanResult {
  matched('MATCHED'),
  misplaced('MISPLACED'),
  unknown('UNKNOWN'),
  missing('MISSING'),
  pending('PENDING');

  const ScanResult(this.label);

  final String label;

  static ScanResult? tryParse(Object? value) {
    for (final r in values) {
      if (r.label == value) return r;
    }
    return null;
  }
}

class AuditScan {
  const AuditScan({
    required this.clientScanId,
    required this.localAuditId,
    required this.scannedValue,
    required this.scanKey,
    required this.scannedAt,
    required this.localResult,
    this.serverResult,
    this.assetId,
    this.assetCode,
    this.assetName,
    this.syncedAt,
  });

  final String clientScanId;
  final String localAuditId;
  final String scannedValue;
  final String scanKey;
  final DateTime scannedAt;
  final ScanResult localResult;
  final ScanResult? serverResult;
  final String? assetId;
  final String? assetCode;
  final String? assetName;
  final DateTime? syncedAt;

  ScanResult get result => serverResult ?? localResult;
  bool get isSynced => syncedAt != null;
}

class SyncedScan {
  const SyncedScan({
    required this.clientScanId,
    required this.result,
    this.assetId,
    this.assetCode,
    this.name,
    this.duplicate = false,
  });

  final String clientScanId;
  final ScanResult result;
  final String? assetId;
  final String? assetCode;
  final String? name;
  final bool duplicate;
}

class ScanBatchResult {
  const ScanBatchResult({
    required this.accepted,
    required this.duplicates,
    required this.results,
  });

  final int accepted;
  final int duplicates;
  final List<SyncedScan> results;
}

class AuditLine {
  const AuditLine({
    required this.result,
    required this.scannedValue,
    this.assetId,
    this.assetCode,
    this.name,
  });

  final ScanResult result;
  final String scannedValue;
  final String? assetId;
  final String? assetCode;
  final String? name;
}

class AuditDetail {
  const AuditDetail({required this.audit, required this.items});

  final ServerAudit audit;
  final List<AuditLine> items;

  List<AuditLine> withResult(ScanResult result) => [
    for (final i in items)
      if (i.result == result) i,
  ];
}
