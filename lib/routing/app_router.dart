import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/alerts/presentation/screens/alerts_screen.dart';
import '../features/approvals/presentation/screens/approvals_screen.dart';
import '../features/audit/presentation/screens/audit_screen.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/loans/presentation/screens/my_loans_screen.dart';
import '../features/shell/presentation/screens/app_shell.dart';
import '../features/splash/presentation/controllers/app_ready_provider.dart';
import '../features/splash/presentation/screens/splash_screen.dart';

/// Where signed-in users land: the first tab of the shell.
const homeLocation = '/approvals';

/// Where to send the user for [location], or null to stay there.
/// Everyone sees /splash until the app is [ready]. After that, signed-out
/// users can only see /login and signed-in users never see it.
String? authRedirect({
  required bool ready,
  required bool loggedIn,
  required String location,
}) {
  if (!ready) return location == '/splash' ? null : '/splash';
  final atLogin = location == '/login';
  if (!loggedIn && !atLogin) return '/login';
  if (loggedIn && (atLogin || location == '/' || location == '/splash')) {
    return homeLocation;
  }
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

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      ready: ref.read(appReadyProvider).hasValue,
      loggedIn: ref.read(authControllerProvider).value != null,
      location: state.matchedLocation,
    ),
    routes: [
      // Never shown: authRedirect sends "/" to the tabs or /login. Registered
      // so links to "/" (e.g. go_router's error page button) resolve.
      GoRoute(path: '/', redirect: (_, _) => '/login'),
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fade(state, const LoginScreen()),
      ),
      shellRoute(),
    ],
  );
});

/// The signed-in tabs. Each branch keeps its own stack, so switching tabs
/// doesn't lose where you were. Branch order must match [shellTabs].
StatefulShellRoute shellRoute() => StatefulShellRoute.indexedStack(
  pageBuilder: (_, state, navigationShell) =>
      _fade(state, AppShell(navigationShell: navigationShell)),
  branches: [
    _tab('/approvals', const ApprovalsScreen()),
    _tab('/loans', const MyLoansScreen()),
    _tab('/alerts', const AlertsScreen()),
    _tab('/audit', const AuditScreen()),
  ],
);

StatefulShellBranch _tab(String path, Widget screen) => StatefulShellBranch(
  routes: [
    // No transition: the bottom bar stays put and only the body swaps.
    GoRoute(
      path: path,
      pageBuilder: (_, _) => NoTransitionPage(child: screen),
    ),
  ],
);
