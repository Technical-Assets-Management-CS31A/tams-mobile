import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/presentation/screens/alerts_screen.dart';
import '../features/approvals/presentation/screens/approvals_screen.dart';
import '../features/audit/presentation/screens/audit_screen.dart';
import '../features/audit/presentation/screens/audit_summary_screen.dart';
import '../features/audit/presentation/screens/room_audits_screen.dart';
import '../features/audit/presentation/screens/scanner_screen.dart';
import '../features/auth/domain/entities/user_role.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/loans/presentation/screens/loan_detail_screen.dart';
import '../features/loans/presentation/screens/my_loans_screen.dart';
import '../features/shell/presentation/screens/app_shell.dart';
import '../features/splash/presentation/controllers/app_ready_provider.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import 'locations.dart';

/// Where signed-in users land: the first tab of the shell.
const homeLocation = '/approvals';

const auditLocation = '/audit';

String homeFor(UserRole role) =>
    role == UserRole.custodian ? auditLocation : homeLocation;

bool isAuditLocation(String location) =>
    location == auditLocation || location.startsWith('$auditLocation/');

/// Where to send the user for [location], or null to stay there.
/// Everyone sees /splash until the app is [ready]. After that, signed-out
/// users can only see /login and signed-in users never see it.
String? authRedirect({
  required bool ready,
  required bool loggedIn,
  required String location,
  UserRole role = UserRole.unknown,
}) {
  if (!ready) return location == '/splash' ? null : '/splash';
  final atLogin = location == '/login';
  if (!loggedIn && !atLogin) return '/login';
  if (!loggedIn) return null;
  if (atLogin || location == '/' || location == '/splash') {
    return homeFor(role);
  }
  if (!role.canAudit && isAuditLocation(location)) return homeFor(role);
  return null;
}

/// Fades between screens. Login and the tabs replace each other rather than
/// stacking, so a forward slide would look wrong.
Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionsBuilder: (_, animation, _, child) =>
      FadeTransition(opacity: animation, child: child),
);

final routerProvider = Provider<GoRouter>((ref) {
  // Tells go_router to re-run `redirect` whenever auth or ready changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.listen(appReadyProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final rootNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final user = ref.read(authControllerProvider).value;
      return authRedirect(
        ready: ref.read(appReadyProvider).hasValue,
        loggedIn: user != null,
        location: state.matchedLocation,
        role: user?.role ?? UserRole.unknown,
      );
    },
    routes: [
      // Never shown: authRedirect sends "/" to the tabs or /login. Registered
      // so links to "/" (e.g. go_router's error page button) resolve.
      GoRoute(path: '/', redirect: (_, _) => '/login'),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fade(state, const LoginScreen()),
      ),
      shellRoute(rootNavigatorKey: rootNavigatorKey),
    ],
  );
});

/// The signed-in tabs. Each branch keeps its own stack, so switching tabs
/// doesn't lose where you were. Branch order must match [shellTabs].
///
/// Screens opened from a tab, such as a loan from Alerts (see
/// [alertLoanLocation]), cover the whole shell with their own app bar when
/// [rootNavigatorKey] is the router's navigator key. Without it they open
/// inside the tab.
StatefulShellRoute shellRoute({GlobalKey<NavigatorState>? rootNavigatorKey}) =>
    StatefulShellRoute.indexedStack(
      pageBuilder: (_, state, navigationShell) =>
          _fade(state, AppShell(navigationShell: navigationShell)),
      branches: [
        _tab('/approvals', const ApprovalsScreen()),
        _tab(
          '/loans',
          const MyLoansScreen(),
          routes: [
            GoRoute(
              path: ':loanId',
              parentNavigatorKey: rootNavigatorKey,
              builder: (_, state) =>
                  LoanDetailScreen(loanId: state.pathParameters['loanId']!),
            ),
          ],
        ),
        _tab(
          '/alerts',
          const AlertsScreen(),
          routes: [
            GoRoute(
              path: 'loans/:loanId',
              parentNavigatorKey: rootNavigatorKey,
              builder: (_, state) =>
                  LoanDetailScreen(loanId: state.pathParameters['loanId']!),
            ),
          ],
        ),
        _tab(
          auditLocation,
          const AuditScreen(),
          routes: [
            GoRoute(
              path: 'rooms/:roomId',
              parentNavigatorKey: rootNavigatorKey,
              builder: (_, state) =>
                  RoomAuditsScreen(roomId: state.pathParameters['roomId']!),
            ),
            GoRoute(
              path: 'scan/:localId',
              parentNavigatorKey: rootNavigatorKey,
              builder: (_, state) =>
                  ScannerScreen(localAuditId: state.pathParameters['localId']!),
            ),
            GoRoute(
              path: 'summary/:localId',
              parentNavigatorKey: rootNavigatorKey,
              builder: (_, state) => AuditSummaryScreen(
                localAuditId: state.pathParameters['localId']!,
              ),
            ),
          ],
        ),
      ],
    );

StatefulShellBranch _tab(
  String path,
  Widget screen, {
  List<RouteBase> routes = const [],
}) => StatefulShellBranch(
  routes: [
    // No transition: the bottom bar stays put and only the body swaps.
    GoRoute(
      path: path,
      pageBuilder: (_, _) => NoTransitionPage(child: screen),
      routes: routes,
    ),
  ],
);
