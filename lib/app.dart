import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/notifications/presentation/controllers/live_updates.dart';
import 'features/notifications/presentation/controllers/push_notifications.dart';
import 'routing/app_router.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  void initState() {
    super.initState();
    // Both follow the session: they connect on sign-in and stop on
    // sign-out.
    ref.read(pushNotificationsProvider).start();
    ref.read(liveUpdatesProvider).start();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'TAMS',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // Foreground pushes show here, whichever screen is open.
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKeyProvider),
    );
  }
}
