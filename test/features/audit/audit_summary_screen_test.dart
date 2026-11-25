import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/audit/data/datasources/audit_local_datasource.dart';
import 'package:tams_mobile/features/audit/data/local/audit_database.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_scan.dart';
import 'package:tams_mobile/features/audit/domain/services/audit_sync_service.dart';
import 'package:tams_mobile/features/audit/presentation/controllers/audit_providers.dart';
import 'package:tams_mobile/features/audit/presentation/screens/audit_summary_screen.dart';
import 'package:tams_mobile/features/auth/domain/entities/user_role.dart';
import 'package:tams_mobile/features/auth/presentation/controllers/auth_controller.dart';

import '../../helpers/audit_fixtures.dart';
import '../../helpers/audit_overrides.dart';
import '../../helpers/fake_audit_repository.dart';

void main() {
  late AuditDatabase database;
  late AuditLocalDataSource store;
  late FakeAuditRepository server;

  setUp(() async {
    database = await memoryAuditDatabase();
    store = AuditLocalDataSource(database, userId: 'user-1');
    server = FakeAuditRepository();
    await store.saveRoster(labRoster());
    final srv = server.seedAudit();
    await store.insertAudit(openAudit(serverId: srv.id));
    await store.addScan(scan('s-1'));
  });

  tearDown(() => database.close());

  Future<void> syncFirst() => AuditSyncService(
    repository: server,
    store: store,
    clock: DateTime.now,
  ).sync();

  Future<void> pumpSummary(
    WidgetTester tester, {
    bool online = true,
    UserRole role = UserRole.custodian,
  }) async {
    if (!online) server.offline = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...auditOverrides(
            server: server,
            database: database,
            connection: Stream.value(online),
          ),
          authControllerProvider.overrideWith(() => SignedInAuditor(role)),
        ],
        child: const MaterialApp(
          home: AuditSummaryScreen(localAuditId: 'local-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FilledButton submitButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(
      of: find.text('Submit audit'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ),
  );

  testWidgets('lists missing items and tags the ones on loan', (tester) async {
    await pumpSummary(tester, online: false);

    expect(find.text('1 of 3 found'), findsOneWidget);
    expect(find.text('Missing (2)'), findsOneWidget);
    final onLoan = find.descendant(
      of: find.byKey(const ValueKey('missing-$assetC')),
      matching: find.text('On loan'),
    );
    expect(onLoan, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('missing-$assetB')),
        matching: find.text('On loan'),
      ),
      findsNothing,
    );
  });

  testWidgets('Submit is disabled while scans are waiting to sync', (
    tester,
  ) async {
    await pumpSummary(tester, online: false);

    expect(submitButton(tester).onPressed, isNull);
    expect(find.byKey(const Key('submit-blocked')), findsOneWidget);
    expect(find.text('Connect to the internet to submit.'), findsOneWidget);
  });

  testWidgets('Submit explains unsynced scans when online', (tester) async {
    server.sendFailures.add(unreachable);
    await pumpSummary(tester);

    expect(submitButton(tester).onPressed, isNull);
    expect(
      find.text('1 scan waiting to sync. Sync them to submit.'),
      findsOneWidget,
    );
  });

  testWidgets('submitting confirms the missing count and shows the result', (
    tester,
  ) async {
    await syncFirst();
    await pumpSummary(tester, role: UserRole.techStaff);
    expect(submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Submit audit'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 items not scanned will be recorded as missing.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('submit-confirm')));
    await tester.pumpAndSettle();

    expect(server.completeCalls, 1);
    expect(find.byKey(const Key('audit-submitted')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('count-missing'))).data,
      '2',
    );
    expect(find.text('Sign off'), findsOneWidget);
    final local = (await store.audit('local-1'))!;
    expect(local.status, AuditStatus.completed);
    expect(await store.scans('local-1'), isEmpty);
  });

  testWidgets('leaving while the submit runs still refreshes the rooms', (
    tester,
  ) async {
    await syncFirst();
    final answer = Completer<void>();
    server.completeAnswer = answer.future;
    final overrides = [
      ...auditOverrides(
        server: server,
        database: database,
        connection: Stream.value(true),
      ),
      authControllerProvider.overrideWith(
        () => SignedInAuditor(UserRole.techStaff),
      ),
    ];
    Widget app(Widget home) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: home),
    );
    await tester.pumpWidget(
      app(const AuditSummaryScreen(localAuditId: 'local-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit audit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-confirm')));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AuditSummaryScreen)),
    );
    final before = container.read(auditRevisionProvider);

    await tester.pumpWidget(app(const SizedBox()));
    answer.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(server.completeCalls, 1);
    expect(container.read(auditRevisionProvider), greaterThan(before));
  });

  Future<void> signOff(WidgetTester tester) async {
    await tester.tap(find.text('Sign off'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-off-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('signing off after submitting is kept on this phone', (
    tester,
  ) async {
    await syncFirst();
    await pumpSummary(tester, role: UserRole.techStaff);
    await tester.tap(find.text('Submit audit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-confirm')));
    await tester.pumpAndSettle();

    await signOff(tester);

    expect(server.signedOff, hasLength(1));
    expect(find.text('Submitted and signed off'), findsOneWidget);
    expect(find.text('Sign off'), findsNothing);
    expect((await store.audit('local-1'))!.status, AuditStatus.signedOff);
  });

  testWidgets('signing off a reopened submitted audit updates it', (
    tester,
  ) async {
    await syncFirst();
    final local = (await store.audit('local-1'))!;
    await server.complete(local.serverId!);
    await store.completeAudit(
      'local-1',
      counts: const AuditCounts(
        expected: 3,
        matched: 1,
        missing: 2,
        misplaced: 0,
        unknown: 0,
      ),
      completedAt: DateTime.utc(2026, 11, 25, 4),
    );
    await pumpSummary(tester, role: UserRole.techStaff);
    expect(find.text('Submitted'), findsOneWidget);

    await signOff(tester);

    expect(server.signedOff, [local.serverId]);
    expect(find.text('Submitted and signed off'), findsOneWidget);
    expect(find.text('Sign off'), findsNothing);
    expect((await store.audit('local-1'))!.status, AuditStatus.signedOff);
  });

  testWidgets('custodians cannot sign off', (tester) async {
    await syncFirst();
    await pumpSummary(tester);
    await tester.tap(find.text('Submit audit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Open report'), findsOneWidget);
    expect(find.text('Sign off'), findsNothing);
  });

  testWidgets('cancelling the confirmation keeps the audit open', (
    tester,
  ) async {
    await syncFirst();
    await pumpSummary(tester);

    await tester.tap(find.text('Submit audit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(server.completeCalls, 0);
    expect((await store.audit('local-1'))!.isOpen, isTrue);
    expect((await store.scans('local-1')).single.result, ScanResult.matched);
  });
}
