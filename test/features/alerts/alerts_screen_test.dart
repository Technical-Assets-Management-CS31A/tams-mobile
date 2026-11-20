import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/features/alerts/domain/entities/alert.dart';
import 'package:tams_mobile/features/alerts/presentation/controllers/alerts_controller.dart';
import 'package:tams_mobile/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:tams_mobile/features/alerts/presentation/widgets/alert_tile.dart';

import '../../helpers/fake_alerts_repository.dart';

/// Counts one row more than it serves, as when the repository skips a
/// malformed row: the list never reaches `total`.
class _OvercountingAlertsRepository extends FakeAlertsRepository {
  _OvercountingAlertsRepository(super.alerts, super.pageSize);

  @override
  Future<AlertsPage> list({int page = 1}) async {
    final served = await super.list(page: page);
    return AlertsPage(
      items: served.items,
      page: served.page,
      total: served.total + 1,
      unreadCount: served.unreadCount,
    );
  }
}

class _Harness {
  _Harness(this.repo, this.router);

  final FakeAlertsRepository repo;
  final GoRouter router;

  String get location => router.routerDelegate.currentConfiguration.uri.path;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<Alert>? alerts,
  FakeAlertsRepository? repo,
}) async {
  final fake =
      repo ??
      FakeAlertsRepository(
        alerts ??
            [
              alert('old', ago: const Duration(hours: 2), read: true),
              alert(
                'new',
                type: 'LOAN_OVERDUE',
                title: 'Loan overdue',
                body: 'Juan Cruz (IT-2B): CBL-0230 HDMI Cable was due 3:00 PM.',
                studentName: 'Juan Cruz',
                sectionCode: 'IT-2B',
                loanId: 'loan-2',
                ago: const Duration(minutes: 3),
              ),
            ],
      );
  final router = GoRouter(
    initialLocation: '/alerts',
    routes: [
      GoRoute(
        path: '/alerts',
        builder: (_, _) => const Scaffold(body: AlertsScreen()),
        routes: [
          GoRoute(
            path: 'loans/:loanId',
            builder: (_, s) => Text('Loan ${s.pathParameters['loanId']}'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alertsRepositoryProvider.overrideWithValue(fake),
        authTokenProvider.overrideWith(SignedInToken.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(fake, router);
}

void main() {
  testWidgets('lists alerts newest first with the student and section', (
    tester,
  ) async {
    await _pump(tester);

    final titles = tester
        .widgetList<AlertTile>(find.byType(AlertTile))
        .map((t) => t.alert.id);
    expect(titles, ['new', 'old']);

    expect(find.text('Loan overdue'), findsOneWidget);
    expect(find.text('Juan Cruz · IT-2B'), findsOneWidget);
    expect(find.text('Maria Santos · BSCS-3A'), findsOneWidget);
    expect(find.textContaining('3 min ago'), findsOneWidget);
    expect(find.textContaining('Overdue'), findsOneWidget);
    expect(find.textContaining('Late arrival'), findsOneWidget);
  });

  testWidgets('only unread alerts have a dot', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('unread-dot')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('new')),
        matching: find.byKey(const Key('unread-dot')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the warning number and a frozen penalty (US-07)', (
    tester,
  ) async {
    await _pump(
      tester,
      alerts: [alert('w4', warningNo: 4, penaltyTriggered: true)],
    );
    expect(find.textContaining('Warning #4'), findsOneWidget);
    expect(
      find.text('Non-Compliance Mark issued · approvals frozen'),
      findsOneWidget,
    );
  });

  testWidgets('tapping an alert marks it read and opens its loan', (
    tester,
  ) async {
    final h = await _pump(tester);

    await tester.tap(find.text('Loan overdue'));
    await tester.pumpAndSettle();

    expect(h.repo.markedRead, ['new']);
    // The route for /alerts/loans/:loanId, given loan-2.
    expect(find.text('Loan loan-2'), findsOneWidget);

    h.router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unread-dot')), findsNothing);
  });

  testWidgets('an alert without a loan is marked read and stays put', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      alerts: [
        alert(
          's',
          type: 'STATION_OFFLINE',
          title: 'Station offline',
          loanId: null,
        ),
      ],
    );
    await tester.tap(find.text('Station offline'));
    await tester.pumpAndSettle();
    expect(h.repo.markedRead, ['s']);
    expect(h.location, '/alerts');
  });

  testWidgets('shows the empty state when there are no alerts', (tester) async {
    await _pump(tester, alerts: []);
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('shows the error and retries', (tester) async {
    final repo = FakeAlertsRepository([alert('a')])
      ..listError = const Failure("Can't reach the server.");
    await _pump(tester, repo: repo);

    expect(find.text("Couldn't load alerts"), findsOneWidget);
    expect(find.text("Can't reach the server."), findsOneWidget);

    repo.listError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertTile), findsOneWidget);
  });

  testWidgets('pull to refresh fetches new alerts', (tester) async {
    final h = await _pump(tester, alerts: [alert('a')]);
    h.repo.alerts = [...h.repo.alerts, alert('b', ago: Duration.zero)];

    await tester.fling(
      find.byType(AlertTile).first,
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertTile), findsNWidgets(2));
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    final repo = FakeAlertsRepository([
      for (var i = 0; i < 15; i++)
        alert(
          'a$i',
          title: 'Alert $i',
          ago: Duration(minutes: i + 1),
        ),
    ], 10);
    await _pump(tester, repo: repo);
    expect(repo.listedPages, [1], reason: 'page 1 fills the screen');

    await tester.scrollUntilVisible(find.text('Alert 14'), 300);
    await tester.pumpAndSettle();

    expect(repo.listedPages, [1, 2]);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('stops asking after the last page when a row was skipped', (
    tester,
  ) async {
    final repo = _OvercountingAlertsRepository([
      for (var i = 0; i < 15; i++)
        alert(
          'a$i',
          title: 'Alert $i',
          ago: Duration(minutes: i + 1),
        ),
    ], 10);
    await _pump(tester, repo: repo);

    await tester.scrollUntilVisible(find.text('Alert 14'), 300);
    // Would time out if every empty page set off another request.
    await tester.pumpAndSettle();

    expect(repo.listedPages, [1, 2, 3]);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('signed out, nothing is fetched', (tester) async {
    final repo = FakeAlertsRepository([alert('a')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [alertsRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: Scaffold(body: AlertsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.listedPages, isEmpty);
    expect(find.text("You're all caught up"), findsOneWidget);
  });
}
