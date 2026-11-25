import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity.dart';
import '../../../../core/utils/clock.dart';
import '../../domain/services/audit_sync_service.dart';
import 'audit_providers.dart';

class AuditSyncState {
  const AuditSyncState({this.running = false, this.last, this.lastAt});

  final bool running;
  final SyncReport? last;
  final DateTime? lastAt;
}

class AuditSyncController extends Notifier<AuditSyncState> {
  @override
  AuditSyncState build() {
    ref.listen(isOnlineProvider, (previous, online) {
      if (online && previous == false) unawaited(syncNow());
    });
    ref.listen(auditUserIdProvider, (_, userId) {
      if (userId != null) Future.microtask(syncNow);
    }, fireImmediately: true);
    return const AuditSyncState();
  }

  Future<SyncReport?> syncNow() async {
    if (ref.read(auditUserIdProvider) == null) return null;
    final previous = state;
    state = AuditSyncState(
      running: true,
      last: previous.last,
      lastAt: previous.lastAt,
    );
    try {
      final service = await ref.read(auditSyncServiceProvider.future);
      final report = await service.sync();
      if (!ref.mounted) return report;
      state = AuditSyncState(last: report, lastAt: ref.read(clockProvider)());
      ref.read(auditRevisionProvider.notifier).bump();
      return report;
    } catch (e) {
      debugPrint('Audit sync failed: $e');
      if (ref.mounted) {
        state = AuditSyncState(last: previous.last, lastAt: previous.lastAt);
      }
      return null;
    }
  }
}

final auditSyncControllerProvider =
    NotifierProvider<AuditSyncController, AuditSyncState>(
      AuditSyncController.new,
    );
