import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/network/dio_client.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/core/utils/clock.dart';
import 'package:tams_mobile/features/alerts/presentation/controllers/alerts_controller.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/features/loans/presentation/controllers/loan_detail_provider.dart';
import 'package:tams_mobile/features/notifications/data/live_connection.dart';
import 'package:tams_mobile/features/notifications/presentation/controllers/live_updates.dart';

import '../../helpers/fake_alerts_repository.dart';
import '../../helpers/fake_approvals_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_loans_repository.dart';

class _FakeConnection implements LiveConnection {
  _FakeConnection(this.url, this.events_, this.accessToken);

  final Uri url;
  final List<String> events_;
  final Future<String> Function() accessToken;

  final _events = StreamController<String>.broadcast();
  final _reconnected = StreamController<void>.broadcast();
  final _closed = StreamController<void>.broadcast();

  /// Thrown by [start] when set, like an unreachable hub.
  Object? startError;
  String? tokenUsed;
  bool started = false;
  bool stopped = false;

  @override
  Stream<String> get events => _events.stream;

  @override
  Stream<void> get reconnected => _reconnected.stream;

  @override
  Stream<void> get closed => _closed.stream;

  @override
  Future<void> start() async {
    tokenUsed = await accessToken();
    if (startError case final e?) throw e;
    started = true;
  }

  @override
  Future<void> stop() async => stopped = true;

  void send(String event) => _events.add(event);
  void reconnect() => _reconnected.add(null);
  void close() => _closed.add(null);
}

/// A JWT for user [sub] that expires at [exp]. Unsigned: only the app
/// reads it.
String _jwt(String sub, DateTime exp) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.'
      '${part({'sub': sub, 'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

class _Harness {
  _Harness(this.container, this.approvals, this.alerts, this.loans, this.http);

  final ProviderContainer container;
  final FakeApprovalsRepository approvals;
  final FakeAlertsRepository alerts;
  final FakeLoansRepository loans;
  final FakeHttpAdapter http;
  final connections = <_FakeConnection>[];

  /// Makes the next connections fail to start while set.
  Object? startError;

  _FakeConnection get last => connections.last;

  void signIn(String token) =>
      container.read(authTokenProvider.notifier).set(token);
  void signOut() => container.read(authTokenProvider.notifier).clear();
}

final _now = DateTime.utc(2026, 11, 26, 8);
final _fresh = _jwt('user-1', _now.add(const Duration(minutes: 15)));

Future<_Harness> _start(WidgetTester tester) async {
  final approvals = FakeApprovalsRepository();
  final alerts = FakeAlertsRepository();
  final loans = FakeLoansRepository();
  final http = FakeHttpAdapter(body: {'id': 'user-1'});
  late _Harness h;
  final container = ProviderContainer(
    overrides: [
      approvalsRepositoryProvider.overrideWithValue(approvals),
      alertsRepositoryProvider.overrideWithValue(alerts),
      loansRepositoryProvider.overrideWithValue(loans),
      clockProvider.overrideWithValue(() => _now),
      dioProvider.overrideWithValue(
        Dio(BaseOptions(baseUrl: 'https://tams.test/api/v1'))
          ..httpClientAdapter = http,
      ),
      liveConnectionFactoryProvider.overrideWithValue((
        url, {
        required events,
        required accessToken,
      }) {
        final c = _FakeConnection(url, events, accessToken)
          ..startError = h.startError;
        h.connections.add(c);
        return c;
      }),
    ],
  );
  addTearDown(container.dispose);
  h = _Harness(container, approvals, alerts, loans, http);
  // Keep the lists alive, as the screens do.
  container
    ..listen(approvalsControllerProvider, (_, _) {})
    ..listen(alertsControllerProvider, (_, _) {})
    ..listen(myLoansProvider, (_, _) {});
  // In a scope, so Riverpod schedules on frames rather than timers.
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const SizedBox()),
  );
  container.read(liveUpdatesProvider).start();
  await tester.pump();
  return h;
}

void main() {
  testWidgets('connects to /hubs/live on sign-in, with the token', (
    tester,
  ) async {
    final h = await _start(tester);
    expect(h.connections, isEmpty, reason: 'signed out');

    h.signIn(_fresh);
    await tester.pump();

    expect(h.last.url.toString(), 'https://tams.test/hubs/live');
    expect(h.last.events_, liveEvents);
    expect(h.last.started, isTrue);
    expect(h.last.tokenUsed, _fresh);
    expect(h.http.lastRequest, isNull, reason: 'a fresh token is used as is');
  });

  testWidgets('disconnects on sign-out', (tester) async {
    final h = await _start(tester);
    h.signIn(_fresh);
    await tester.pump();

    h.signOut();
    await tester.pump();
    expect(h.last.stopped, isTrue);
    expect(h.connections, hasLength(1));
  });

  testWidgets(
    'a renewed token keeps the connection; a new user gets a new one',
    (tester) async {
      final h = await _start(tester);
      h.signIn(_fresh);
      await tester.pump();

      h.signIn(_jwt('user-1', _now.add(const Duration(minutes: 30))));
      await tester.pump();
      expect(h.connections, hasLength(1));
      expect(h.last.stopped, isFalse);

      h.signIn(_jwt('user-2', _now.add(const Duration(minutes: 30))));
      await tester.pump();
      expect(h.connections, hasLength(2));
      expect(h.connections.first.stopped, isTrue);
    },
  );

  testWidgets('an expiring token is renewed through the API first', (
    tester,
  ) async {
    final h = await _start(tester);
    final expiring = _jwt('user-1', _now.add(const Duration(seconds: 10)));
    // Dio needs the real event loop to answer.
    await tester.runAsync(() async {
      h.signIn(expiring);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(h.http.lastRequest?.path, '/auth/me');
    expect(h.last.started, isTrue);
  });

  testWidgets('approval.requested reloads Pending Approvals only', (
    tester,
  ) async {
    final h = await _start(tester);
    h.signIn(_fresh);
    await tester.pump();
    final approvals = h.approvals.pendingCalls;
    final alerts = h.alerts.listedPages.length;
    final loans = h.loans.listCalls;

    h.last.send('approval.requested');
    await tester.pump();

    expect(h.approvals.pendingCalls, approvals + 1);
    expect(h.alerts.listedPages, hasLength(alerts));
    expect(h.loans.listCalls, loans);
  });

  testWidgets('a freeze reloads the pending list, which has the banner', (
    tester,
  ) async {
    final h = await _start(tester);
    h.signIn(_fresh);
    await tester.pump();
    final before = h.approvals.pendingCalls;

    h.last.send('instructor.frozen');
    await tester.pump();
    h.last.send('instructor.unfrozen');
    await tester.pump();

    expect(h.approvals.pendingCalls, before + 2);
  });

  testWidgets('warnings, anomalies and overdue reload Alerts and My Loans', (
    tester,
  ) async {
    final h = await _start(tester);
    h.signIn(_fresh);
    await tester.pump();

    for (final event in [
      'warning.issued',
      'anomaly.raised',
      'anomaly.resolved',
      'loan.overdue',
    ]) {
      final alerts = h.alerts.listedPages.length;
      final loans = h.loans.listCalls;
      h.last.send(event);
      await tester.pump();
      expect(h.alerts.listedPages, hasLength(alerts + 1), reason: event);
      expect(h.loans.listCalls, loans + 1, reason: event);
    }
  });

  testWidgets('reconnecting reloads everything, since events were missed', (
    tester,
  ) async {
    final h = await _start(tester);
    h.signIn(_fresh);
    await tester.pump();
    final approvals = h.approvals.pendingCalls;
    final alerts = h.alerts.listedPages.length;
    final loans = h.loans.listCalls;

    h.last.reconnect();
    await tester.pump();

    expect(h.approvals.pendingCalls, approvals + 1);
    expect(h.alerts.listedPages, hasLength(alerts + 1));
    expect(h.loans.listCalls, loans + 1);
  });

  testWidgets('after the hub gives up, retries later and reloads', (
    tester,
  ) async {
    final h = await _start(tester);
    h.signIn(_fresh);
    await tester.pump();
    final before = h.approvals.pendingCalls;

    h.last.close();
    await tester.pump(LiveUpdates.retryEvery);
    await tester.pump();

    expect(h.connections, hasLength(2));
    expect(h.last.started, isTrue);
    expect(h.approvals.pendingCalls, before + 1);
  });

  testWidgets('a failed start is retried later, or at once on resume', (
    tester,
  ) async {
    final h = await _start(tester);
    h.startError = Exception('Hub unreachable');
    h.signIn(_fresh);
    await tester.pump();
    expect(h.last.started, isFalse);

    await tester.pump(LiveUpdates.retryEvery);
    await tester.pump();
    expect(h.connections, hasLength(2), reason: 'retried after the wait');

    h.startError = null;
    h.container.read(liveUpdatesProvider).resume();
    await tester.pump();
    expect(h.connections, hasLength(3), reason: 'resume skips the wait');
    expect(h.last.started, isTrue);

    // Connected: resuming again changes nothing.
    h.container.read(liveUpdatesProvider).resume();
    await tester.pump();
    expect(h.connections, hasLength(3));
  });

  testWidgets('a retry waiting when the user signs out never connects', (
    tester,
  ) async {
    final h = await _start(tester);
    h.signIn(_fresh);
    await tester.pump();

    h.last.close();
    await tester.pump();
    h.signOut();
    await tester.pump(LiveUpdates.retryEvery * 2);

    expect(h.connections, hasLength(1));
  });
}
