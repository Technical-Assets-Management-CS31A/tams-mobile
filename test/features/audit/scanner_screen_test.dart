import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/utils/clock.dart';
import 'package:tams_mobile/features/audit/data/datasources/audit_local_datasource.dart';
import 'package:tams_mobile/features/audit/data/local/audit_database.dart';
import 'package:tams_mobile/features/audit/presentation/screens/scanner_screen.dart';
import 'package:tams_mobile/features/audit/presentation/widgets/asset_qr_camera.dart';
import 'package:tams_mobile/features/auth/presentation/controllers/auth_controller.dart';

import '../../helpers/audit_fixtures.dart';
import '../../helpers/audit_overrides.dart';
import '../../helpers/fake_approvals_repository.dart';
import '../../helpers/fake_audit_repository.dart';

void main() {
  late AuditDatabase database;
  late AuditLocalDataSource store;
  late FakeAuditRepository server;
  late FakeClock clock;
  late ValueChanged<String> camera;
  late List<String> haptics;

  setUp(() async {
    database = await memoryAuditDatabase();
    store = AuditLocalDataSource(database, userId: 'user-1');
    server = FakeAuditRepository();
    clock = FakeClock(DateTime.utc(2026, 11, 25, 2));
    haptics = [];
    await store.saveRoster(labRoster());
    final srv = server.seedAudit();
    await store.insertAudit(openAudit(serverId: srv.id));
  });

  tearDown(() => database.close());

  Future<void> pumpScanner(WidgetTester tester, {bool online = true}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...auditOverrides(
            server: server,
            database: database,
            connection: Stream.value(online),
          ),
          authControllerProvider.overrideWith(SignedInAuditor.new),
          clockProvider.overrideWithValue(clock.call),
          scanCameraProvider.overrideWithValue((onCode) {
            camera = onCode;
            return const ColoredBox(color: Colors.black);
          }),
        ],
        child: const MaterialApp(home: ScannerScreen(localAuditId: 'local-1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scanCode(WidgetTester tester, String value) async {
    camera(value);
    await tester.pumpAndSettle();
  }

  String feedbackTitle(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('scan-feedback-title'))).data!;

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('a roster asset shows Found with its code and name', (
    tester,
  ) async {
    await pumpScanner(tester);
    expect(textOf(tester, 'scan-progress'), '0 of 3 found');

    await scanCode(tester, 'tams:asset:$assetA');

    expect(feedbackTitle(tester), 'Found');
    expect(find.text('PC-01 · Desktop 01'), findsOneWidget);
    expect(textOf(tester, 'scan-progress'), '1 of 3 found');
    expect(haptics, isNotEmpty);
    expect(
      (await store.scans('local-1')).single.scannedValue,
      'tams:asset:$assetA',
    );
  });

  testWidgets('an asset from another room is pending until it syncs', (
    tester,
  ) async {
    await pumpScanner(tester, online: false);

    await scanCode(tester, strayAsset);

    expect(feedbackTitle(tester), "Not on this room's roster");
    expect(textOf(tester, 'scan-counts'), '1 pending · 0 unknown');
  });

  testWidgets('other text is unknown', (tester) async {
    await pumpScanner(tester, online: false);

    await scanCode(tester, 'WIFI:S:lab;');

    expect(feedbackTitle(tester), 'Not a TAMS asset');
    expect(textOf(tester, 'scan-counts'), '0 pending · 1 unknown');
  });

  testWidgets(
    'scanning an asset again says Already scanned and saves nothing',
    (tester) async {
      await pumpScanner(tester);
      await scanCode(tester, 'tams:asset:$assetA');

      clock.advance(const Duration(seconds: 5));
      await scanCode(tester, assetA);

      expect(feedbackTitle(tester), 'Already scanned');
      expect(await store.scans('local-1'), hasLength(1));
    },
  );

  testWidgets('the camera repeating a code within 2 s is ignored', (
    tester,
  ) async {
    await pumpScanner(tester);
    await scanCode(tester, 'tams:asset:$assetA');

    clock.advance(const Duration(seconds: 1));
    await scanCode(tester, 'tams:asset:$assetA');
    expect(feedbackTitle(tester), 'Found');

    clock.advance(const Duration(seconds: 2));
    await scanCode(tester, 'tams:asset:$assetA');
    expect(feedbackTitle(tester), 'Already scanned');
  });

  testWidgets('a label held in view does not repeat Already scanned', (
    tester,
  ) async {
    await pumpScanner(tester);
    await scanCode(tester, 'tams:asset:$assetA');
    final buzzes = haptics.length;

    for (var i = 0; i < 20; i++) {
      clock.advance(const Duration(milliseconds: 250));
      await scanCode(tester, 'tams:asset:$assetA');
    }

    expect(feedbackTitle(tester), 'Found');
    expect(haptics, hasLength(buzzes));
  });

  testWidgets('two labels in view are each recorded once', (tester) async {
    await pumpScanner(tester);

    for (var i = 0; i < 10; i++) {
      await scanCode(tester, 'tams:asset:$assetA');
      await scanCode(tester, 'tams:asset:$assetB');
      clock.advance(const Duration(milliseconds: 250));
    }

    expect(await store.scans('local-1'), hasLength(2));
    expect(feedbackTitle(tester), 'Found');
    expect(textOf(tester, 'scan-progress'), '2 of 3 found');
  });

  testWidgets('offline scans wait in the queue', (tester) async {
    await pumpScanner(tester, online: false);

    await scanCode(tester, assetA);
    await scanCode(tester, assetB);

    expect(textOf(tester, 'scan-queue'), '2 scans waiting to sync');
    expect(find.text('Offline'), findsOneWidget);
    expect(server.sent, isEmpty);
    expect(await store.unsyncedCount(), 2);
  });

  testWidgets('online scans sync right away', (tester) async {
    await pumpScanner(tester);

    await scanCode(tester, assetA);

    expect(textOf(tester, 'scan-queue'), 'All scans synced');
    expect(find.text('Online'), findsOneWidget);
    expect(server.sent.expand((b) => b), hasLength(1));
  });

  testWidgets('the queue syncs when the connection returns', (tester) async {
    final connection = StreamController<bool>();
    addTearDown(connection.close);
    connection.add(false);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...auditOverrides(
            server: server,
            database: database,
            connection: connection.stream,
          ),
          authControllerProvider.overrideWith(SignedInAuditor.new),
          clockProvider.overrideWithValue(clock.call),
          scanCameraProvider.overrideWithValue((onCode) {
            camera = onCode;
            return const SizedBox.expand();
          }),
        ],
        child: const MaterialApp(home: ScannerScreen(localAuditId: 'local-1')),
      ),
    );
    await tester.pumpAndSettle();
    await scanCode(tester, assetA);
    expect(textOf(tester, 'scan-queue'), '1 scan waiting to sync');

    connection.add(true);
    await tester.pumpAndSettle();

    expect(textOf(tester, 'scan-queue'), 'All scans synced');
    expect(await store.unsyncedCount(), 0);
  });
}
