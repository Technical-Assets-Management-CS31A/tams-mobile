import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: show real data once the API is wired up.
    return const EmptyState(
      icon: Icons.notifications_none_outlined,
      title: "You're all caught up",
      message: 'Overdue reminders and request updates will appear here.',
    );
  }
}
