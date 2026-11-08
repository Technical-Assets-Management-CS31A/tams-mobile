import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/home_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';

/// Where to send the user for [location], or null to stay there.
/// Signed-out users can only see /login; signed-in users never see it.
String? authRedirect({required bool loggedIn, required String location}) {
  final atLogin = location == '/login';
  if (!loggedIn && !atLogin) return '/login';
  if (loggedIn && (atLogin || location == '/')) return '/home';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Tells go_router to re-run `redirect` whenever auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      loggedIn: ref.read(authControllerProvider).value != null,
      location: state.matchedLocation,
    ),
    routes: [
      // Never shown: authRedirect sends "/" to /home or /login. Registered
      // so links to "/" (e.g. go_router's error page button) resolve.
      GoRoute(path: '/', redirect: (_, _) => '/login'),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    ],
  );
});
