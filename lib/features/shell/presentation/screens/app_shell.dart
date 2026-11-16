import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

/// One bottom-navigation tab. Order matches the shell route's branches.
class ShellTab {
  const ShellTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const shellTabs = [
  ShellTab('Approvals', Icons.fact_check_outlined, Icons.fact_check),
  ShellTab('My Loans', Icons.inventory_2_outlined, Icons.inventory_2),
  ShellTab('Alerts', Icons.notifications_none_outlined, Icons.notifications),
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
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
