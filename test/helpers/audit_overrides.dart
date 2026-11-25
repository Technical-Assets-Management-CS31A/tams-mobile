import 'package:flutter_riverpod/misc.dart';
import 'package:tams_mobile/core/network/connectivity.dart';
import 'package:tams_mobile/features/audit/data/local/audit_database.dart';
import 'package:tams_mobile/features/audit/presentation/controllers/audit_providers.dart';

import 'audit_fixtures.dart';
import 'fake_audit_repository.dart';

List<Override> auditOverrides({
  FakeAuditRepository? server,
  AuditDatabase? database,
  Stream<bool>? connection,
}) => [
  auditRepositoryProvider.overrideWithValue(server ?? FakeAuditRepository()),
  auditDatabaseProvider.overrideWith(
    (ref) async => database ?? await memoryAuditDatabase(),
  ),
  connectivityProvider.overrideWith((ref) => connection ?? Stream.value(true)),
  auditSyncRetryDelayProvider.overrideWithValue(Duration.zero),
];
