import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state.dart';

class MyLoansScreen extends StatelessWidget {
  const MyLoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: show real data once the API is wired up.
    return const EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'No active loans',
      message: 'Assets you borrow will be listed here with their due dates.',
    );
  }
}
