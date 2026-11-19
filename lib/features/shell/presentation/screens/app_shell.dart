import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../alerts/presentation/controllers/alerts_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// One bottom-navigation tab. Order matches the shell route's branches.
class ShellTab {
  const ShellTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const alertsTab = ShellTab(
  'Alerts',
  Icons.notifications_none_outlined,
  Icons.notifications,
);

const shellTabs = [
  ShellTab('Approvals', Icons.fact_check_outlined, Icons.fact_check),
  ShellTab('My Loans', Icons.inventory_2_outlined, Icons.inventory_2),
  alertsTab,
  ShellTab('Audit', Icons.history, Icons.history),
];

/// Signed-in frame: app bar, the current tab, and the bottom navigation bar.
/// Each tab keeps its own navigation stack and scroll position.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    // Loads Alerts on sign-in, so the badge shows before the tab is opened.
    final unread = ref.watch(
      alertsControllerProvider.select((s) => s.value?.unreadCount ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(shellTabs[index].label),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            // Router redirect sends us back to /login once state is null.
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        // Tapping the current tab again returns it to its first screen.
        onDestinationSelected: (i) =>
            navigationShell.goBranch(i, initialLocation: i == index),
        destinations: [
          for (final tab in shellTabs)
            NavigationDestination(
              icon: _badged(tab, tab.icon, unread),
              selectedIcon: _badged(tab, tab.selectedIcon, unread),
              label: tab.label,
            ),
        ],
      ),
    );
  }

  /// The Alerts icon carries the unread count.
  static Widget _badged(ShellTab tab, IconData icon, int unread) =>
      tab != alertsTab || unread == 0
      ? Icon(icon)
      : Badge(
          key: const Key('alerts-badge'),
          label: Text(unread > 99 ? '99+' : '$unread'),
          child: Icon(icon),
        );
}
