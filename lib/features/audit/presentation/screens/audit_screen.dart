import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: show real data once the API is wired up.
    return const EmptyState(
      icon: Icons.history,
      title: 'No activity yet',
      message: 'Asset check-outs, returns and approvals will be recorded here.',
    );
  }
}
