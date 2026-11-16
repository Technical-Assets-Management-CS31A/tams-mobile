import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/pending_approval.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/approval_card.dart';
import '../widgets/approve_sheet.dart';

class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(approvalsControllerProvider);

    if (requests.isEmpty) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No pending approvals',
        message: 'Borrow requests waiting for your review will show up here.',
      );
    }

    final now = DateTime.now();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final request = requests[i];
        return ApprovalCard(
          key: ValueKey(request.id),
          request: request,
          now: now,
          onApprove: () => _approve(context, ref, request),
          onReject: () => _reject(context, ref, request, i),
        );
      },
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    PendingApproval request,
  ) async {
    final decision = await showApproveSheet(
      context,
      request: request,
      rooms: ref.read(roomsProvider),
    );
    if (decision == null || !context.mounted) return;

    ref
        .read(approvalsControllerProvider.notifier)
        .approve(request.id, decision);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Approved ${request.itemName} for ${request.studentName} · '
            '${decision.room}, ${formatClassLength(decision.classLength)}',
          ),
        ),
      );
  }

  void _reject(
    BuildContext context,
    WidgetRef ref,
    PendingApproval request,
    int index,
  ) {
    final controller = ref.read(approvalsControllerProvider.notifier);
    controller.reject(request.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Rejected request from ${request.studentName}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => controller.restore(request, index),
          ),
        ),
      );
  }
}
