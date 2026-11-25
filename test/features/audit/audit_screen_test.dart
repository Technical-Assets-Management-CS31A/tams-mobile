import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tams_mobile/features/audit/data/datasources/audit_local_datasource.dart';
import 'package:tams_mobile/features/audit/data/local/audit_database.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_room.dart';
import 'package:tams_mobile/features/audit/presentation/screens/audit_screen.dart';
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
  });

  tearDown(() => database.close());

  Future<GoRouter> pumpRooms(
    WidgetTester tester, {
    bool online = true,
    bool settle = true,
  }) async {
    if (!online) server.offline = true;
    final router = GoRouter(
      initialLocation: '/audit',
      routes: [
        GoRoute(
          path: '/audit',
          builder: (_, _) => const Scaffold(body: AuditScreen()),
          routes: [
            GoRoute(
              path: 'scan/:id',
              builder: (_, state) =>
                  Text('scanner ${state.pathParameters['id']}'),
            ),
            GoRoute(
              path: 'rooms/:id',
              builder: (_, state) => Text('room ${state.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...auditOverrides(
            server: server,
            database: database,
            connection: Stream.value(online),
          ),
          authControllerProvider.overrideWith(SignedInAuditor.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return router;
  }

  VoidCallback? pressed(WidgetTester tester, Key key) =>
      tester.widget<ButtonStyleButton>(find.byKey(key)).onPressed;

  testWidgets('lists rooms and caches them for offline use', (tester) async {
    await pumpRooms(tester);

    expect(find.text('Computer Lab 1'), findsOneWidget);
    expect(find.text('Storage 1'), findsOneWidget);
    expect(find.text('Roster not downloaded'), findsNWidgets(2));
    expect((await store.cachedRooms()).map((r) => r.code), ['CL1', 'ST1']);
  });

  testWidgets('forgets saved rooms the server no longer lists', (tester) async {
    const old = AuditRoom(id: 'room-old3', code: 'OLD-3', name: 'Old room');
    await store.cacheRooms([old, lab1]);

    await pumpRooms(tester);

    expect((await store.cachedRooms()).map((r) => r.code), ['CL1', 'ST1']);
  });

  testWidgets('a search keeps saved rooms it does not match', (tester) async {
    await pumpRooms(tester);
    const old = AuditRoom(id: 'room-old3', code: 'OLD-3', name: 'Old room');
    await store.cacheRooms([old]);

    await tester.enterText(find.byType(TextField), 'storage');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect((await store.cachedRooms()).map((r) => r.code), contains('OLD-3'));
  });

  testWidgets('downloading a roster shows its size and age', (tester) async {
    await pumpRooms(tester);

    await tester.tap(find.byKey(Key('download-${lab1.id}')));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 items · downloaded'), findsOneWidget);
    expect(find.text('Download again'), findsOneWidget);
    expect((await store.roster(lab1.id))!.items, hasLength(3));
  });

  testWidgets('offline shows saved rooms and disables downloads', (
    tester,
  ) async {
    await store.cacheRooms([lab1, storageRoom]);
    await store.saveRoster(labRoster());

    await pumpRooms(tester, online: false);

    expect(find.textContaining("You're offline"), findsOneWidget);
    expect(pressed(tester, Key('download-${lab1.id}')), isNull);
    expect(pressed(tester, Key('start-${lab1.id}')), isNotNull);
    expect(pressed(tester, Key('start-${storageRoom.id}')), isNull);
    expect(
      find.text('Download the roster while online to audit this room offline.'),
      findsOneWidget,
    );
  });

  testWidgets('starting offline opens the scanner for a local audit', (
    tester,
  ) async {
    await store.cacheRooms([lab1]);
    await store.saveRoster(labRoster());
    await pumpRooms(tester, online: false);

    await tester.tap(find.byKey(Key('start-${lab1.id}')));
    await tester.pumpAndSettle();

    final audit = (await store.openAuditFor(lab1.id))!;
    expect(audit.serverId, isNull);
    expect(find.text('scanner ${audit.localId}'), findsOneWidget);
  });

  testWidgets('a room with an open audit shows Resume', (tester) async {
    await store.insertAudit(openAudit());

    await pumpRooms(tester);

    expect(find.text('In progress'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(Key('start-${lab1.id}')),
        matching: find.text('Resume'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(Key('start-${storageRoom.id}')),
        matching: find.text('Start'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the queue counter offers Sync now', (tester) async {
    await store.cacheRooms([lab1]);
    await store.saveRoster(labRoster());
    await store.insertAudit(openAudit());
    await store.addScan(scan('s-1'));

    await pumpRooms(tester, online: false);

    expect(find.text('1 scan waiting to sync'), findsOneWidget);
    expect(pressed(tester, const Key('sync-now')), isNull);
  });

  testWidgets('searching filters the rooms', (tester) async {
    await pumpRooms(tester);

    await tester.enterText(find.byType(TextField), 'storage');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Storage 1'), findsOneWidget);
    expect(find.text('Computer Lab 1'), findsNothing);
  });

  testWidgets('a server that never answers times out with a retry', (
    tester,
  ) async {
    final hang = Completer<void>();
    server.roomsAnswer = hang.future;

    await pumpRooms(tester, settle: false);
    await tester.pump(const Duration(seconds: 19));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text("Couldn't load rooms"), findsOneWidget);
    expect(
      find.text('The server took longer than 20 seconds to answer.'),
      findsOneWidget,
    );

    server.roomsAnswer = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Computer Lab 1'), findsOneWidget);
  });

  testWidgets('a timeout falls back to saved rooms with a notice', (
    tester,
  ) async {
    await store.cacheRooms([lab1]);
    server.roomsAnswer = Completer<void>().future;

    await pumpRooms(tester, settle: false);
    await tester.pump(const Duration(seconds: 21));

    expect(find.text('Computer Lab 1'), findsOneWidget);
    expect(
      find.text(
        'The server took longer than 20 seconds to answer. '
        'Showing saved rooms.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unreachable server says so even with a network', (
    tester,
  ) async {
    server.offline = true;

    await pumpRooms(tester);

    expect(find.text("Couldn't load rooms"), findsOneWidget);
    expect(find.text(unreachable.message), findsOneWidget);
  });
}
