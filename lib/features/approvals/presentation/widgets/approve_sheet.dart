import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/clock.dart';
import '../../domain/entities/pending_approval.dart';
import 'approval_card.dart' show Countdown;
import 'student_avatar.dart';

/// Opens the approve sheet for [request]. Returns the instructor's choice,
/// or null if they closed the sheet without approving.
Future<ApprovalDecision?> showApproveSheet(
  BuildContext context, {
  required PendingApproval request,
  required Clock clock,
  Map<String, String>? photoHeaders,
}) => showModalBottomSheet<ApprovalDecision>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) =>
      ApproveSheet(request: request, clock: clock, photoHeaders: photoHeaders),
);

/// Lets the instructor pick the destination room (pre-filled with their
/// default room) and class length before approving (FR-2.2, US-04).
///
/// Shows the time left; once it runs out, Approve is disabled.
class ApproveSheet extends StatefulWidget {
  const ApproveSheet({
    super.key,
    required this.request,
    required this.clock,
    this.photoHeaders,
  });

  final PendingApproval request;
  final Clock clock;
  final Map<String, String>? photoHeaders;

  @override
  State<ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<ApproveSheet> {
  late Room? _room = widget.request.defaultRoom;
  late Duration _classLength = widget.request.defaultClassLength;

  late DateTime _now = widget.clock();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = widget.clock());
      if (widget.request.isExpired(_now)) _ticker?.cancel();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    final room = _room;
    final rooms = request.roomOptions;
    final expired = request.isExpired(_now);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Approve request',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Countdown(left: request.timeLeft(_now)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              StudentAvatar(
                name: request.studentName,
                photoUrl: request.photoUrl,
                headers: widget.photoHeaders,
                radius: 32,
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
                    for (final item in request.items)
                      Text(
                        item.assetCode.isEmpty
                            ? item.name
                            : '${item.name} · ${item.assetCode}',
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
          if (rooms.isEmpty)
            Text(
              'No rooms are set up yet. Ask staff to add one.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: room?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Destination room',
                prefixIcon: Icon(Icons.meeting_room_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final r in rooms)
                  DropdownMenuItem(
                    value: r.id,
                    child: Text(r.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) =>
                  setState(() => _room = rooms.firstWhere((r) => r.id == id)),
            ),
          const SizedBox(height: 24),
          Text('Class length', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<Duration>(
            showSelectedIcon: false,
            segments: [
              for (final length in request.classLengthOptions)
                ButtonSegment(
                  value: length,
                  label: Text(formatClassLength(length)),
                ),
            ],
            selected: {_classLength},
            onSelectionChanged: (s) => setState(() => _classLength = s.first),
          ),
          const SizedBox(height: 32),
          if (expired) ...[
            Text(
              'This request expired and the borrow was denied.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            key: const Key('approve-confirm'),
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
            // Disabled until a room is picked, and once time runs out.
            onPressed: room == null || expired
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
