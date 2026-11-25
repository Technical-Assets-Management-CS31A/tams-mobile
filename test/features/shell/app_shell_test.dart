import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/features/alerts/presentation/controllers/alerts_controller.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/features/auth/domain/entities/user.dart';
import 'package:tams_mobile/features/auth/domain/entities/user_role.dart';
import 'package:tams_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tams_mobile/features/loans/presentation/controllers/loan_detail_provider.dart';
import 'package:tams_mobile/features/shell/presentation/widgets/shell_header.dart';
import 'package:tams_mobile/routing/app_router.dart';

import '../../helpers/fake_alerts_repository.dart';
import '../../helpers/fake_approvals_repository.dart';
import '../../helpers/fake_loans_repository.dart';

/// Signed in as a known user; records sign-outs instead of touching storage.
class _FakeAuth extends AuthController {
  _FakeAuth([this.role = UserRole.techStaff]);

  final UserRole role;
  int logouts = 0;

  @override
  Future<User?> build() async =>
      User(email: 'teacher@school.edu', token: 'test-token', role: role);

  @override
  Future<void> logout() async => logouts++;
}

Future<GoRouter> _pumpShell(
  WidgetTester tester, {
  FakeAlertsRepository? alerts,
  _FakeAuth? auth,
}) async {
  final router = GoRouter(
    initialLocation: homeLocation,
    routes: [shellRoute()],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      // No pending requests, so every tab shows its empty state.
      overrides: [
        approvalsRepositoryProvider.overrideWithValue(
          FakeApprovalsRepository(),
        ),
        alertsRepositoryProvider.overrideWithValue(
          alerts ?? FakeAlertsRepository(),
        ),
        loansRepositoryProvider.overrideWithValue(FakeLoansRepository()),
        authTokenProvider.overrideWith(SignedInToken.new),
        authControllerProvider.overrideWith(() => auth ?? _FakeAuth()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('opens on Approvals with its empty state', (tester) async {
    await _pumpShell(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('No pending approvals'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  testWidgets('instructors do not see the Audit tab', (tester) async {
    await _pumpShell(tester, auth: _FakeAuth(UserRole.instructor));

    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Audit'),
      ),
      findsNothing,
    );
  });

  testWidgets('the Alerts tab shows the unread count', (tester) async {
    await _pumpShell(
      tester,
      alerts: FakeAlertsRepository([
        alert('a'),
        alert('b'),
        alert('c', read: true),
      ]),
    );
    final badge = find.byKey(const Key('alerts-badge'));
    expect(badge, findsOneWidget);
    expect(
      find.descendant(of: badge, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Alerts'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ShellHeader),
        matching: find.text('2 unread'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('coming back to the app updates the badge without opening '
      'Alerts', (tester) async {
    final alerts = FakeAlertsRepository([alert('a')]);
    await _pumpShell(tester, alerts: alerts);
    final badge = find.byKey(const Key('alerts-badge'));
    expect(find.descendant(of: badge, matching: find.text('1')), findsOne);

    // A notice pushed in the background, never tapped.
    alerts.alerts = [alert('a'), alert('b')];
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('No pending approvals'), findsOneWidget, reason: 'tab');
    expect(find.descendant(of: badge, matching: find.text('2')), findsOne);
  });

  testWidgets('no badge when everything is read', (tester) async {
    await _pumpShell(tester);
    expect(find.byKey(const Key('alerts-badge')), findsNothing);
  });

  testWidgets('each tab shows its own title and empty state', (tester) async {
    final router = await _pumpShell(tester);

    const cases = [
      ('My Loans', '/loans', 'No active loans'),
      ('Alerts', '/alerts', "You're all caught up"),
      ('Audit', '/audit', 'No activity yet'),
      ('Approvals', '/approvals', 'No pending approvals'),
    ];
    for (final (label, path, emptyTitle) in cases) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.path,
        path,
        reason: label,
      );
      expect(
        find.descendant(
          of: find.byType(ShellHeader),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: label,
      );
      expect(find.text(emptyTitle), findsOneWidget, reason: label);
    }
  });

  group('sign out', () {
    Future<_FakeAuth> openSheet(WidgetTester tester) async {
      final auth = _FakeAuth();
      await _pumpShell(tester, auth: auth);
      // In the app the router's redirect has already loaded the user.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NavigationBar)),
      );
      await container.read(authControllerProvider.future);
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      return auth;
    }

    testWidgets('asks first instead of signing out on tap', (tester) async {
      final auth = await openSheet(tester);

      expect(find.text('Sign out?'), findsOneWidget);
      expect(find.textContaining('teacher@school.edu'), findsOneWidget);
      expect(auth.logouts, 0);
    });

    testWidgets('Cancel keeps the user signed in', (tester) async {
      final auth = await openSheet(tester);
      await tester.tap(find.byKey(const Key('sign-out-cancel')));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsNothing);
      expect(auth.logouts, 0);
    });

    testWidgets('dismissing the sheet keeps the user signed in', (
      tester,
    ) async {
      final auth = await openSheet(tester);
      await tester.tapAt(const Offset(20, 20)); // the scrim
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsNothing);
      expect(auth.logouts, 0);
    });

    testWidgets('confirming signs out', (tester) async {
      final auth = await openSheet(tester);
      await tester.tap(find.byKey(const Key('sign-out-confirm')));
      await tester.pumpAndSettle();

      expect(auth.logouts, 1);
    });
  });
}
