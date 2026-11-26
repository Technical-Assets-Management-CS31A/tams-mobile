import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/brand_app_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../routing/locations.dart';
import '../../domain/entities/loan_detail.dart';
import '../controllers/loan_history_controller.dart';
import '../widgets/loan_card.dart';

/// Loan History (FR-2.5): every loan I approved, open or closed, newest
/// checkout first, with a status filter. Opened from My Loans.
class LoanHistoryScreen extends ConsumerWidget {
  const LoanHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loanHistoryProvider);
    final controller = ref.read(loanHistoryProvider.notifier);
    final now = ref.watch(clockProvider)();
    final selected = state.value?.filter ?? controller.filter;

    return BrandPage(
      title: 'Loan history',
      subtitle: 'Every loan you approved',
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                for (final f in LoanHistoryFilter.values) ...[
                  ChoiceChip(
                    key: ValueKey('history-filter-${f.name}'),
                    label: Text(f.label),
                    selected: f == selected,
                    onSelected: (_) => controller.select(f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: switch (state) {
              AsyncValue(:final value?) => RefreshIndicator(
                onRefresh: controller.refresh,
                child: value.items.isEmpty
                    ? _FillScrollable(
                        child: EmptyState(
                          icon: Icons.history,
                          title: 'No loans',
                          message: value.filter == LoanHistoryFilter.all
                              ? 'Loans you approve will be listed here.'
                              : 'No ${value.filter.label.toLowerCase()} '
                                    'loans you approved.',
                        ),
                      )
                    : _list(context, value, now, controller),
              ),
              AsyncValue(:final error?) => RefreshIndicator(
                onRefresh: controller.refresh,
                child: _FillScrollable(
                  child: EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: "Couldn't load your loan history",
                    message: error is Failure
                        ? error.message
                        : 'Something went wrong. Please try again.',
                    action: FilledButton.tonal(
                      onPressed: controller.refresh,
                      child: const Text('Try again'),
                    ),
                  ),
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }

  Widget _list(
    BuildContext context,
    LoanHistory history,
    DateTime now,
    LoanHistoryController controller,
  ) {
    final loans = history.items;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: loans.length + (history.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == loans.length && history.moreFailed) {
          return Center(
            child: TextButton.icon(
              key: const ValueKey('history-load-more-retry'),
              onPressed: controller.loadMore,
              icon: const Icon(Icons.refresh),
              label: const Text("Couldn't load more. Try again"),
            ),
          );
        }
        if (i == loans.length) {
          // Scrolled to the end: fetch the next page.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => controller.loadMore(),
          );
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
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
