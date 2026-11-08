import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/home_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Tells go_router to re-run `redirect` whenever auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_,_) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider).value != null;
      final atLogin = state.matchedLocation == '/login';

      if (!loggedIn && !atLogin) return '/login';
      if (loggedIn && atLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    ],
  );
});