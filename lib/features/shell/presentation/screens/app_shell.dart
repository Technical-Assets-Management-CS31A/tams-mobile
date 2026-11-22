import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../alerts/presentation/controllers/alerts_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../loans/presentation/controllers/loan_detail_provider.dart';
import '../widgets/shell_header.dart';
import '../widgets/sign_out_sheet.dart';

/// One bottom-navigation tab. Order matches the shell route's branches.
class ShellTab {
  const ShellTab(this.label, this.subtitle, this.icon, this.selectedIcon);

  final String label;

  /// Shown under the title in the header.
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
}

const alertsTab = ShellTab(
  'Alerts',
  'Late, overdue and missing equipment',
  Icons.notifications_none_outlined,
  Icons.notifications,
);

const shellTabs = [
  ShellTab(
    'Approvals',
    'Borrow requests waiting on you',
    Icons.fact_check_outlined,
    Icons.fact_check,
  ),
  ShellTab(
    'My Loans',
    "Equipment you've borrowed",
    Icons.inventory_2_outlined,
    Icons.inventory_2,
  ),
  alertsTab,
  ShellTab(
    'Audit',
    'Check-outs, returns and approvals',
    Icons.history,
    Icons.history,
  ),
];

/// Signed-in frame: header, the current tab, and the bottom navigation bar.
/// Each tab keeps its own navigation stack and scroll position.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Notices pushed while the app was in the background but never tapped
    // aren't counted yet. Reloading here, not in AlertsScreen, keeps the
    // badge current even when the Alerts tab was never opened.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        ref.read(alertsControllerProvider.notifier).refresh();
        // Statuses and countdowns moved on while the app was away.
        ref.invalidate(myLoansProvider);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final index = navigationShell.currentIndex;
    // Loads Alerts on sign-in, so the badge shows before the tab is opened.
    final unread = ref.watch(
      alertsControllerProvider.select((s) => s.value?.unreadCount ?? 0),
    );

    final tab = shellTabs[index];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status bar icons on the white header.
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: Column(
          children: [
            ShellHeader(
              title: tab.label,
              subtitle: tab.subtitle,
              badge: tab == alertsTab && unread > 0
                  ? '${unread > 99 ? '99+' : unread} unread'
                  : null,
              onSignOut: _confirmSignOut,
            ),
            Expanded(
              // The header already sits below the status bar.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: navigationShell,
              ),
            ),
          ],
        ),
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
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final email = ref.read(authControllerProvider).value?.email;
    final confirmed = await showSignOutSheet(context, email: email);
    if (!confirmed || !mounted) return;
    // Router redirect sends us back to /login once state is null.
    await ref.read(authControllerProvider.notifier).logout();
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
