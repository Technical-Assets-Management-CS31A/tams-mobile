import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../routing/locations.dart';
import '../../domain/entities/loan_detail.dart';
import '../controllers/loan_detail_provider.dart';
import '../widgets/loan_card.dart';

/// My Loans (PRD 6.6, FR-2.5): the open loans I approved, each with its
/// live status (At Counter, In Transit, Verified in Room, Overdue) and a
/// countdown to when it is due back, grace included. Overdue and other
/// urgent loans come first, then the soonest due.
class MyLoansScreen extends ConsumerStatefulWidget {
  const MyLoansScreen({super.key});

  /// How often the list is fetched again while it is on screen, so
  /// check-ins at the room show up without pulling to refresh. Pushes and
  /// resuming the app reload it sooner.
  static const pollEvery = Duration(minutes: 1);

  @override
  ConsumerState<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends ConsumerState<MyLoansScreen> {
  /// Ticks the countdowns every second, only while there is one to show.
  Timer? _ticker;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(MyLoansScreen.pollEvery, (_) {
      if (mounted) ref.invalidate(myLoansProvider);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  void _tick(bool on) {
    if (on && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!on && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  Future<void> _reload() => ref.refresh(myLoansProvider.future);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myLoansProvider);
    final now = ref.watch(clockProvider)();
    _tick(state.value?.items.isNotEmpty ?? false);

    return switch (state) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: _reload,
        child: value.items.isEmpty
            ? const _FillScrollable(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No active loans',
                  message:
                      'Items you approve for your students will be listed '
                      'here with a countdown to when they are due back.',
                ),
              )
            : _list(value, now),
      ),
      AsyncValue(:final error?) => RefreshIndicator(
        onRefresh: _reload,
        child: _FillScrollable(
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: "Couldn't load your loans",
            message: error is Failure
                ? error.message
                : 'Something went wrong. Please try again.',
            action: FilledButton.tonal(
              onPressed: () => ref.invalidate(myLoansProvider),
              child: const Text('Try again'),
            ),
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _list(LoansPage page, DateTime now) {
    final loans = sortForMyLoans(page.items, now);
    final hidden = page.total - loans.length;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: loans.length + (hidden > 0 ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == loans.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$hidden more not shown',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        final loan = loans[i];
        return LoanCard(
          key: ValueKey(loan.id),
          loan: loan,
          now: now,
          onTap: () => context.push(myLoanLocation(loan.id)),
        );
      },
    );
  }
}

/// Overdue, missing and anomalous loans first, then the soonest due.
List<LoanDetail> sortForMyLoans(List<LoanDetail> loans, DateTime now) {
  int rank(LoanDetail l) => l.liveStatus(now).isUrgent ? 0 : 1;
  final far = DateTime.utc(9999);
  return [...loans]..sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return (a.dueAt ?? far).compareTo(b.dueAt ?? far);
  });
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
