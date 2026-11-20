import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/auth_headers.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/token_provider.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/pending_approval.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/approval_card.dart';
import '../widgets/approve_sheet.dart';

/// Pending Approvals (PRD 6.6): borrow requests addressed to me, each
/// approved with a room and class length, or declined (FR-2.2, US-04).
class ApprovalsScreen extends ConsumerStatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  ConsumerState<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends ConsumerState<ApprovalsScreen> {
  /// Ticks the countdowns; cards switch to expired when theirs runs out.
  Timer? _ticker;
  late DateTime _now = _clock();

  /// Requests with a decision on its way to the server.
  final _busy = <String>{};

  Clock get _clock => ref.read(clockProvider);

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // The ticker skips rebuilds in the background; catch up on return.
    _lifecycle = AppLifecycleListener(onResume: _catchUp);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Rebuilds only if a card on screen is still counting down. [_now]
  /// moves on regardless, so a rebuild for any other reason (such as a new
  /// request arriving) shows the right time.
  void _tick() {
    if (!mounted) return;
    final shownAt = _now;
    _now = _clock();
    final requests = ref.read(approvalsControllerProvider).value?.items;
    final counting = requests?.any((r) => !r.isExpired(shownAt)) ?? false;
    if (counting && _inForeground) setState(() {});
  }

  void _catchUp() {
    if (mounted) setState(() => _now = _clock());
  }

  static bool get _inForeground => switch (WidgetsBinding
      .instance
      .lifecycleState) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    // Includes inactive (e.g. the notification shade is down): still visible.
    _ => true,
  };

  ApprovalsController get _controller =>
      ref.read(approvalsControllerProvider.notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(approvalsControllerProvider);
    final token = ref.watch(authTokenProvider);
    final apiBaseUrl = ref.watch(dioProvider).options.baseUrl;
    // Only photos on the API's own host get the token.
    Map<String, String>? photoHeaders(String? url) =>
        authHeadersFor(url, token: token, apiBaseUrl: apiBaseUrl);

    return switch (state) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: _controller.refresh,
        child: _list(value, photoHeaders),
      ),
      AsyncValue(:final error?) => _Scrollable(
        onRefresh: _controller.refresh,
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load approvals",
          message: error is Failure
              ? error.message
              : 'Something went wrong. Please try again.',
          action: FilledButton.tonal(
            onPressed: _controller.refresh,
            child: const Text('Try again'),
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _list(
    PendingApprovals data,
    Map<String, String>? Function(String? url) photoHeaders,
  ) {
    final requests = data.items;

    if (requests.isEmpty && !data.frozen) {
      return _Scrollable(
        child: const EmptyState(
          icon: Icons.fact_check_outlined,
          title: 'No pending approvals',
          message: 'Borrow requests waiting for your review will show up here.',
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (data.frozen) ...[const _FrozenBanner(), const SizedBox(height: 12)],
        for (final request in requests) ...[
          ApprovalCard(
            key: ValueKey(request.id),
            request: request,
            now: _now,
            photoHeaders: photoHeaders(request.photoUrl),
            busy: _busy.contains(request.id),
            canApprove: !data.frozen,
            onApprove: () => _approve(request, photoHeaders(request.photoUrl)),
            onDecline: () => _decline(request),
            onDismiss: () => _controller.dismiss(request.id),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _approve(
    PendingApproval request,
    Map<String, String>? photoHeaders,
  ) async {
    final decision = await showApproveSheet(
      context,
      request: request,
      clock: _clock,
      photoHeaders: photoHeaders,
    );
    if (decision == null || !mounted || _expiredMeanwhile(request)) return;

    final ok = await _send(
      request,
      () => _controller.approve(request.id, decision),
    );
    if (ok) {
      _snack(
        'Approved ${request.itemName} for ${request.studentName} · '
        '${decision.room.name.isEmpty ? decision.room.code : decision.room.name}, '
        '${formatClassLength(decision.classLength)}',
      );
    }
  }

  Future<void> _decline(PendingApproval request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline request?'),
        content: Text(
          '${request.studentName} won\'t be able to borrow '
          '${request.itemName}. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('decline-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _expiredMeanwhile(request)) return;

    final ok = await _send(request, () => _controller.decline(request.id));
    if (ok) _snack('Declined request from ${request.studentName}');
  }

  /// True, with a message, if [request] ran out of time while the
  /// instructor was deciding. Nothing is sent: the kiosk already denied it.
  bool _expiredMeanwhile(PendingApproval request) {
    final now = _clock();
    if (!request.isExpired(now)) return false;
    setState(() => _now = now);
    _snack('This request timed out and the borrow was denied.');
    return true;
  }

  /// Runs [call] with the card busy; shows the error and returns false if
  /// it fails.
  Future<bool> _send(
    PendingApproval request,
    Future<void> Function() call,
  ) async {
    setState(() => _busy.add(request.id));
    try {
      await call();
      return true;
    } on Failure catch (f) {
      _snack(f.message);
      return false;
    } catch (_) {
      _snack('Something went wrong. Please try again.');
      return false;
    } finally {
      // Also catch up the clock: if the server said the request expired,
      // the controller marked it expired as of now, which may be up to a
      // second after the last tick. With the older _now the card would
      // briefly show Approve/Decline and "0:01 left" again.
      if (mounted) {
        setState(() {
          _busy.remove(request.id);
          _now = _clock();
        });
      }
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Fills the screen with [child] and lets it be pulled down to refresh.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child, this.onRefresh});

  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final scrollable = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: constraints.maxHeight, child: child),
      ),
    );
    final refresh = onRefresh;
    return refresh == null
        ? scrollable
        : RefreshIndicator(onRefresh: refresh, child: scrollable);
  }
}

/// Shown while staff have frozen my approval rights (FR-2.3).
class _FrozenBanner extends StatelessWidget {
  const _FrozenBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(Icons.lock_outline, color: colors.onErrorContainer),
        title: Text(
          'Approvals frozen',
          style: TextStyle(color: colors.onErrorContainer),
        ),
        subtitle: Text(
          'Staff must lift the freeze before you can approve. '
          'You can still decline.',
          style: TextStyle(color: colors.onErrorContainer),
        ),
      ),
    );
  }
}
