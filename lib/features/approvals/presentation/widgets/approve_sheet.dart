import 'package:flutter/material.dart';

import '../../domain/entities/pending_approval.dart';
import 'student_avatar.dart';

/// Opens the approve sheet for [request]. Returns the approver's choice, or
/// null if they closed the sheet without approving.
Future<ApprovalDecision?> showApproveSheet(
  BuildContext context, {
  required PendingApproval request,
  required List<String> rooms,
}) => showModalBottomSheet<ApprovalDecision>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => ApproveSheet(request: request, rooms: rooms),
);

/// Lets the approver pick a room and class length before approving.
class ApproveSheet extends StatefulWidget {
  const ApproveSheet({super.key, required this.request, required this.rooms});

  final PendingApproval request;
  final List<String> rooms;

  @override
  State<ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<ApproveSheet> {
  String? _room;
  Duration _classLength = classLengthOptions.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final room = _room;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Approve request', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              StudentAvatar(
                name: request.studentName,
                photoUrl: request.photoUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.studentName,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      '${request.itemName} · ${request.assetTag}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _room,
            decoration: const InputDecoration(
              labelText: 'Room',
              prefixIcon: Icon(Icons.meeting_room_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final r in widget.rooms)
                DropdownMenuItem(value: r, child: Text(r)),
            ],
            onChanged: (r) => setState(() => _room = r),
          ),
          const SizedBox(height: 24),
          Text('Class length', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<Duration>(
            showSelectedIcon: false,
            segments: [
              for (final length in classLengthOptions)
                ButtonSegment(
                  value: length,
                  label: Text(formatClassLength(length)),
                ),
            ],
            selected: {_classLength},
            onSelectionChanged: (s) => setState(() => _classLength = s.first),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            key: const Key('approve-confirm'),
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
            // Disabled until a room is picked.
            onPressed: room == null
                ? null
                : () => Navigator.of(context).pop(
                    ApprovalDecision(room: room, classLength: _classLength),
                  ),
          ),
        ],
      ),
    );
  }
}
