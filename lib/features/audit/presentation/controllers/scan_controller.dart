import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/connectivity.dart';
import '../../../../core/utils/clock.dart';
import '../../domain/asset_qr.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/audit_room.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/roster.dart';
import 'audit_providers.dart';
import 'audit_sync_controller.dart';

enum ScanFeedbackKind { matched, misplaced, pending, unknown, alreadyScanned }

class ScanFeedback {
  const ScanFeedback({
    required this.kind,
    required this.title,
    required this.detail,
    required this.serial,
  });

  final ScanFeedbackKind kind;
  final String title;
  final String detail;
  final int serial;
}

class ScanSession {
  const ScanSession({
    required this.audit,
    required this.roster,
    required this.scans,
    required this.unsynced,
    this.feedback,
  });

  final LocalAudit audit;
  final Roster roster;
  final List<AuditScan> scans;
  final int unsynced;
  final ScanFeedback? feedback;

  int get expected => roster.items.length;

  Set<String> get foundIds => {
    for (final s in scans)
      if (s.result == ScanResult.matched && s.assetId != null) s.assetId!,
  };

  int get found => foundIds.length;

  int count(ScanResult result) => scans.where((s) => s.result == result).length;

  List<RosterItem> get missing {
    final found = foundIds;
    return [
      for (final i in roster.items)
        if (!found.contains(i.assetId)) i,
    ];
  }

  ScanSession adding(AuditScan scan, ScanFeedback feedback) => ScanSession(
    audit: audit,
    roster: roster,
    scans: [scan, ...scans],
    unsynced: unsynced + 1,
    feedback: feedback,
  );

  ScanSession showing(ScanFeedback feedback) => ScanSession(
    audit: audit,
    roster: roster,
    scans: scans,
    unsynced: unsynced,
    feedback: feedback,
  );
}

class ScanController extends AsyncNotifier<ScanSession> {
  ScanController(this.localId);

  final String localId;

  static const repeatWindow = Duration(seconds: 2);

  String? _lastValue;
  DateTime? _lastAt;
  int _serial = 0;
  Future<void> _queue = Future.value();

  @override
  Future<ScanSession> build() async {
    ref.watch(auditRevisionProvider);
    final store = await ref.watch(auditStoreProvider.future);
    final audit = await store.audit(localId);
    if (audit == null) {
      throw const Failure('This audit is no longer on this phone.');
    }
    final roster =
        await store.roster(audit.roomId) ??
        Roster(
          room: AuditRoom(id: audit.roomId, code: '', name: ''),
          items: const [],
          downloadedAt: audit.startedAt,
        );
    return ScanSession(
      audit: audit,
      roster: roster,
      scans: await store.scans(localId),
      unsynced: await store.unsyncedCount(localAuditId: localId),
      feedback: state.value?.feedback,
    );
  }

  void onCode(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    final now = ref.read(clockProvider)();
    final last = _lastAt;
    if (value == _lastValue &&
        last != null &&
        now.difference(last) < repeatWindow) {
      return;
    }
    _lastValue = value;
    _lastAt = now;
    _queue = _queue.then((_) => _record(value, now)).catchError((_) {});
  }

  Future<void> _record(String value, DateTime at) async {
    final session = state.value;
    if (session == null || !session.audit.isOpen) return;

    final key = scanKeyOf(value);
    final earlier = session.scans.where((s) => s.scanKey == key).firstOrNull;
    if (earlier != null) {
      state = AsyncData(session.showing(_already(earlier)));
      return;
    }

    final assetId = parseAssetQr(value);
    final item = assetId == null ? null : session.roster.item(assetId);
    final scan = AuditScan(
      clientScanId: ref.read(newIdProvider)(),
      localAuditId: localId,
      scannedValue: value,
      scanKey: key,
      scannedAt: at,
      localResult: localResultOf(value, session.roster),
      assetId: assetId,
      assetCode: item?.assetCode,
      assetName: item?.name,
    );
    final store = await ref.read(auditStoreProvider.future);
    final saved = await store.addScan(scan);
    if (!ref.mounted) return;
    final current = state.value ?? session;
    if (!saved) {
      state = AsyncData(current.showing(_already(scan)));
      return;
    }
    state = AsyncData(current.adding(scan, _feedbackFor(scan)));
    if (ref.read(isOnlineProvider)) {
      unawaited(ref.read(auditSyncControllerProvider.notifier).syncNow());
    }
  }

  ScanFeedback _already(AuditScan scan) => ScanFeedback(
    kind: ScanFeedbackKind.alreadyScanned,
    title: 'Already scanned',
    detail: describeScan(scan),
    serial: ++_serial,
  );

  ScanFeedback _feedbackFor(AuditScan scan) => switch (scan.localResult) {
    ScanResult.matched => ScanFeedback(
      kind: ScanFeedbackKind.matched,
      title: 'Found',
      detail: describeScan(scan),
      serial: ++_serial,
    ),
    ScanResult.pending => ScanFeedback(
      kind: ScanFeedbackKind.pending,
      title: "Not on this room's roster",
      detail: 'Checked against the server when it syncs.',
      serial: ++_serial,
    ),
    ScanResult.misplaced => ScanFeedback(
      kind: ScanFeedbackKind.misplaced,
      title: 'Belongs to another room',
      detail: describeScan(scan),
      serial: ++_serial,
    ),
    _ => ScanFeedback(
      kind: ScanFeedbackKind.unknown,
      title: 'Not a TAMS asset',
      detail: describeScan(scan),
      serial: ++_serial,
    ),
  };
}

String describeScan(AuditScan scan) {
  final code = scan.assetCode;
  final name = scan.assetName;
  if (code != null && name != null) return '$code · $name';
  return code ?? name ?? scan.scannedValue;
}

final scanControllerProvider =
    AsyncNotifierProvider.family<ScanController, ScanSession, String>(
      ScanController.new,
    );
