import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tams_mobile/routing/app_router.dart';

Future<GoRouter> _pumpShell(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: homeLocation,
    routes: [shellRoute()],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
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
        find.descendant(of: find.byType(AppBar), matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
      expect(find.text(emptyTitle), findsOneWidget, reason: label);
    }
  });
}
