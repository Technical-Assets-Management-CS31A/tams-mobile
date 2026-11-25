import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/clock.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/datasources/audit_local_datasource.dart';
import '../../data/datasources/audit_remote_datasource.dart';
import '../../data/local/audit_database.dart';
import '../../data/repositories/audit_repository_impl.dart';
import '../../domain/entities/audit.dart';
import '../../domain/entities/roster.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../domain/repositories/audit_store.dart';
import '../../domain/services/audit_session_service.dart';
import '../../domain/services/audit_sync_service.dart';

final auditDatabaseProvider = FutureProvider<AuditDatabase>((ref) async {
  final database = await AuditDatabase.open();
  ref.onDispose(database.close);
  return database;
});

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepositoryImpl(
    AuditRemoteDataSource(
      ref.watch(dioProvider),
      now: ref.watch(clockProvider),
    ),
  ),
);

final auditUserIdProvider = Provider<String?>(
  (ref) => ref.watch(
    authControllerProvider.select((s) {
      final user = s.value;
      if (user == null || !user.role.canAudit) return null;
      return user.id ?? user.email;
    }),
  ),
);

final canSignOffProvider = Provider<bool>(
  (ref) => ref.watch(
    authControllerProvider.select(
      (s) => (s.value?.role ?? UserRole.unknown).canSignOff,
    ),
  ),
);

final auditStoreProvider = FutureProvider<AuditStore>((ref) async {
  final userId = ref.watch(auditUserIdProvider);
  if (userId == null) throw const Failure('Sign in to audit rooms.');
  final database = await ref.watch(auditDatabaseProvider.future);
  return AuditLocalDataSource(database, userId: userId);
});

final newIdProvider = Provider<String Function()>((ref) => const Uuid().v4);

final auditSyncRetryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

final auditSessionServiceProvider = FutureProvider<AuditSessionService>(
  (ref) async => AuditSessionService(
    repository: ref.watch(auditRepositoryProvider),
    store: await ref.watch(auditStoreProvider.future),
    clock: ref.watch(clockProvider),
    newId: ref.watch(newIdProvider),
  ),
);

final auditSyncServiceProvider = FutureProvider<AuditSyncService>(
  (ref) async => AuditSyncService(
    repository: ref.watch(auditRepositoryProvider),
    store: await ref.watch(auditStoreProvider.future),
    clock: ref.watch(clockProvider),
    retryDelay: ref.watch(auditSyncRetryDelayProvider),
  ),
);

/// The longest the room list may load before the screen shows a time-out.
/// Dio's own limits apply per phase and restart on a token refresh, so a
/// load could otherwise spin for well over 30 seconds.
final auditRoomsTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 20),
);

class AuditRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final auditRevisionProvider = NotifierProvider<AuditRevision, int>(
  AuditRevision.new,
);

class AuditOverview {
  const AuditOverview({
    required this.rosters,
    required this.audits,
    required this.unsynced,
  });

  static const empty = AuditOverview(rosters: {}, audits: {}, unsynced: 0);

  final Map<String, RosterInfo> rosters;
  final Map<String, LocalAudit> audits;
  final int unsynced;
}

final auditOverviewProvider = FutureProvider<AuditOverview>((ref) async {
  ref.watch(auditRevisionProvider);
  final store = await ref.watch(auditStoreProvider.future);
  final unfinished = await store.unfinishedAudits();
  return AuditOverview(
    rosters: await store.rosterInfos(),
    audits: {
      for (final a in unfinished)
        if (!a.isOpen) a.roomId: a,
      for (final a in unfinished)
        if (a.isOpen) a.roomId: a,
    },
    unsynced: await store.unsyncedCount(),
  );
});
