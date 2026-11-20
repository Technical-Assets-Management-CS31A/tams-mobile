import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../routing/locations.dart';
import '../../domain/entities/alert.dart';
import '../controllers/alerts_controller.dart';
import '../widgets/alert_tile.dart';

/// Alerts (PRD 6.6): late arrival warnings, transit anomalies and overdue
/// notices about loans I approved, newest first (FR-2.6, US-05, US-07).
/// Tapping one marks it read and opens its loan.
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  /// Keeps "5 min ago" current.
  Timer? _ticker;

  AlertsController get _controller =>
      ref.read(alertsControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    // AppShell reloads the list on resume, so the badge is current too.
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(alertsControllerProvider);
    final now = ref.watch(clockProvider)();

    return switch (state) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: _controller.refresh,
        child: value.items.isEmpty
            ? const _FillScrollable(
                child: EmptyState(
                  icon: Icons.notifications_none_outlined,
                  title: "You're all caught up",
                  message:
                      'Late arrival warnings, anomalies and overdue notices '
                      'for loans you approved will appear here.',
                ),
              )
            : _list(value, now),
      ),
      AsyncValue(:final error?) => RefreshIndicator(
        onRefresh: _controller.refresh,
        child: _FillScrollable(
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load alerts",
            message: error is Failure
                ? error.message
                : 'Something went wrong. Please try again.',
            action: FilledButton.tonal(
              onPressed: _controller.refresh,
              child: const Text('Try again'),
            ),
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _list(AlertsFeed feed, DateTime now) {
    final alerts = feed.items;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: alerts.length + (feed.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == alerts.length) {
          // Scrolled to the end: fetch the next page.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _controller.loadMore(),
          );
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final alert = alerts[i];
        return AlertTile(
          key: ValueKey(alert.id),
          alert: alert,
          now: now,
          onTap: () => _open(alert),
        );
      },
    );
  }

  void _open(Alert alert) {
    unawaited(_controller.markRead(alert.id));
    final loanId = alert.loanId;
    if (loanId != null) context.push(alertLoanLocation(loanId));
  }
}

/// Fills the screen with [child] and still lets it be pulled to refresh.
class _FillScrollable extends StatelessWidget {
  const _FillScrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: constraints.maxHeight, child: child),
    ),
  );
}
