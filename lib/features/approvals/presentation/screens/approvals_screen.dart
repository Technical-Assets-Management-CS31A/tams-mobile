import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state.dart';

class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: show real data once the API is wired up.
    return const EmptyState(
      icon: Icons.fact_check_outlined,
      title: 'No pending approvals',
      message: 'Borrow requests waiting for your review will show up here.',
    );
  }
}
