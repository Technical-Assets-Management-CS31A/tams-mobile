import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/core/utils/clock.dart';
import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/domain/repositories/approvals_repository.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:tams_mobile/features/approvals/presentation/widgets/student_avatar.dart';

import '../../helpers/fake_approvals_repository.dart';

Future<FakeApprovalsRepository> _pump(
  WidgetTester tester, {
  List<PendingApproval>? requests,
  FakeApprovalsRepository? repo,
  FakeClock? clock,
}) async {
  final fake =
      repo ??
      FakeApprovalsRepository(
        requests ??
            [
              approval('a'),
              approval(
                'b',
                studentName: 'John Dela Cruz',
                itemName: 'HDMI Cable',
                assetCode: 'CBL-0230',
              ),
            ],
      );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        approvalsRepositoryProvider.overrideWithValue(fake),
        clockProvider.overrideWithValue((clock ?? FakeClock()).call),
      ],
      child: const MaterialApp(home: Scaffold(body: ApprovalsScreen())),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Finder _onCard(String student, Finder matching) => find.descendant(
  of: find.ancestor(of: find.text(student), matching: find.byType(Card)),
  matching: matching,
);

Finder _approveOn(String student) =>
    _onCard(student, find.widgetWithText(FilledButton, 'Approve'));

Finder _declineOn(String student) =>
    _onCard(student, find.widgetWithText(TextButton, 'Decline'));

void main() {
  testWidgets('lists each request with photo, student, item and time left', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(StudentAvatar), findsNWidgets(2));
    expect(find.text('MS'), findsOneWidget); // initials when no photo
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('2023-00142 · BSCS-3A'), findsNWidgets(2));
    expect(find.text('Epson Projector'), findsOneWidget);
    expect(find.text('PRJ-0012'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^1:\d\d left$')), findsNWidgets(2));
    expect(find.text('John Dela Cruz'), findsOneWidget);
  });

  testWidgets('a checkout with several items says how many more', (
    tester,
  ) async {
    await _pump(
      tester,
      requests: [
        approval(
          'a',
          items: const [
            ApprovalItem(name: 'Epson Projector', assetCode: 'PRJ-0012'),
            ApprovalItem(name: 'HDMI Cable', assetCode: 'CBL-0230'),
          ],
        ),
      ],
    );
    expect(find.text('Epson Projector + 1 more'), findsOneWidget);
  });

  testWidgets('approve: default room is pre-filled, pick a class length', (
    tester,
  ) async {
    final repo = await _pump(tester);

    await tester.tap(_approveOn('Maria Santos'));
    await tester.pumpAndSettle();
    expect(find.text('Approve request'), findsOneWidget);

    // Every class length from 1.5 to 3 h is offered.
    for (final label in ['1.5 h', '2 h', '2.5 h', '3 h']) {
      expect(find.text(label), findsOneWidget);
    }
    // The instructor's default room is already picked, so Approve is ready.
    expect(find.text('Room 301 (RM301)'), findsOneWidget);
    final confirm = find.byKey(const Key('approve-confirm'));
    expect(tester.widget<ButtonStyleButton>(confirm).onPressed, isNotNull);

    await tester.tap(find.text('2.5 h'));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Approve request'), findsNothing);
    expect(repo.approved, [
      (
        'a',
        const ApprovalDecision(
          room: room301,
          classLength: Duration(minutes: 150),
        ),
      ),
    ]);
    expect(find.text('Maria Santos'), findsNothing);
    expect(
      find.text('Approved Epson Projector for Maria Santos · Room 301, 2.5 h'),
      findsOneWidget,
    );
  });

  testWidgets('approve: another room can be picked', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(_approveOn('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio-Visual Room (AVR)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approve-confirm')));
    await tester.pumpAndSettle();

    expect(repo.approved.single.$2.room, avr);
    expect(repo.approved.single.$2.classLength, const Duration(minutes: 90));
  });

  testWidgets('approve: without a default room, a room must be picked', (
    tester,
  ) async {
    await _pump(tester, requests: [approval('a', defaultRoomId: null)]);

    await tester.tap(_approveOn('Maria Santos'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('approve-confirm'));
    expect(tester.widget<ButtonStyleButton>(confirm).onPressed, isNull);
  });

  testWidgets('closing the sheet keeps the request', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(_approveOn('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // tap the scrim
    await tester.pumpAndSettle();

    expect(find.text('Approve request'), findsNothing);
    expect(repo.approved, isEmpty);
    expect(find.text('Maria Santos'), findsOneWidget);
  });

  testWidgets('a refused approve shows why and keeps the request', (
    tester,
  ) async {
    final repo = FakeApprovalsRepository([approval('a')])
      ..decisionError = const ApprovalFailure(
        'Your approval rights are frozen.',
        code: 'INSTRUCTOR_FROZEN',
      );
    await _pump(tester, repo: repo);

    await tester.tap(_approveOn('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approve-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Your approval rights are frozen.'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
  });

  testWidgets('decline asks first, then sends it', (tester) async {
    final repo = await _pump(tester);

    await tester.tap(_declineOn('Maria Santos'));
    await tester.pumpAndSettle();
    expect(find.text('Decline request?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.declined, isEmpty);

    await tester.tap(_declineOn('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('decline-confirm')));
    await tester.pumpAndSettle();

    expect(repo.declined, ['a']);
    expect(find.text('Maria Santos'), findsNothing);
    expect(find.text('Declined request from Maria Santos'), findsOneWidget);
  });

  testWidgets('a decline the server says expired marks the card expired', (
    tester,
  ) async {
    final repo = FakeApprovalsRepository([approval('a')])
      ..decisionError = const ApprovalFailure(
        'This request timed out and the borrow was denied.',
        code: ApprovalFailure.expired,
        requestGone: true,
      );
    await _pump(tester, repo: repo);

    await tester.tap(_declineOn('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('decline-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text('This request timed out and the borrow was denied.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('approval-expired')), findsOneWidget);
    expect(_onCard('Maria Santos', find.text('Expired')), findsOneWidget);
  });

  group('120 s countdown', () {
    late FakeClock clock;
    late DateTime t0;

    /// A request made at [t0], expiring 120 s later.
    PendingApproval fresh(String id, {String studentName = 'Maria Santos'}) =>
        approval(
          id,
          studentName: studentName,
          requestedAt: t0,
          expiresAt: t0.add(const Duration(seconds: 120)),
        );

    /// Moves the clock on and lets the screen's ticker see it.
    Future<void> elapse(WidgetTester tester, Duration by) async {
      clock.advance(by);
      await tester.pump(const Duration(seconds: 1));
    }

    LinearProgressIndicator bar(WidgetTester tester, String student) =>
        tester.widget(_onCard(student, find.byType(LinearProgressIndicator)));

    setUp(() {
      t0 = DateTime(2026, 11, 18, 9);
      clock = FakeClock(t0);
    });

    testWidgets('counts down every second with a shrinking bar', (
      tester,
    ) async {
      await _pump(tester, requests: [fresh('a')], clock: clock);
      expect(_onCard('Maria Santos', find.text('2:00 left')), findsOneWidget);
      expect(bar(tester, 'Maria Santos').value, 1);

      await elapse(tester, const Duration(seconds: 1));
      expect(_onCard('Maria Santos', find.text('1:59 left')), findsOneWidget);

      await elapse(tester, const Duration(seconds: 59));
      expect(_onCard('Maria Santos', find.text('1:00 left')), findsOneWidget);
      expect(bar(tester, 'Maria Santos').value, 0.5);
    });

    testWidgets('turns red in the last 30 s', (tester) async {
      await _pump(tester, requests: [fresh('a')], clock: clock);
      final theme = Theme.of(tester.element(find.byType(ApprovalsScreen)));
      expect(bar(tester, 'Maria Santos').color, theme.colorScheme.primary);

      await elapse(tester, const Duration(seconds: 91));
      expect(_onCard('Maria Santos', find.text('0:29 left')), findsOneWidget);
      expect(bar(tester, 'Maria Santos').color, theme.colorScheme.error);
    });

    testWidgets('switches to expired when time runs out, then dismisses', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        requests: [
          fresh('a'),
          approval(
            'b',
            studentName: 'John Dela Cruz',
            requestedAt: t0,
            expiresAt: t0.add(const Duration(seconds: 200)),
          ),
        ],
        clock: clock,
      );

      await elapse(tester, const Duration(seconds: 119));
      expect(_onCard('Maria Santos', find.text('0:01 left')), findsOneWidget);
      expect(_approveOn('Maria Santos'), findsOneWidget);

      await elapse(tester, const Duration(seconds: 1));
      // Still listed, but expired: no way to approve or decline it.
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(_onCard('Maria Santos', find.text('Expired')), findsOneWidget);
      expect(
        _onCard(
          'Maria Santos',
          find.text('No decision in time, so the borrow was denied.'),
        ),
        findsOneWidget,
      );
      expect(_approveOn('Maria Santos'), findsNothing);
      expect(_declineOn('Maria Santos'), findsNothing);
      expect(bar(tester, 'Maria Santos').value, 0);
      // The other request is unaffected.
      expect(_onCard('John Dela Cruz', find.text('1:20 left')), findsOneWidget);

      await tester.tap(_onCard('Maria Santos', find.text('Dismiss')));
      await tester.pumpAndSettle();
      expect(find.text('Maria Santos'), findsNothing);
      expect(find.text('John Dela Cruz'), findsOneWidget);
      expect(repo.declined, isEmpty);
      expect(repo.approved, isEmpty);
    });

    testWidgets('a request that arrives already expired shows as expired', (
      tester,
    ) async {
      clock.advance(const Duration(seconds: 130));
      await _pump(tester, requests: [fresh('a')], clock: clock);
      expect(find.byKey(const Key('approval-expired')), findsOneWidget);
      expect(find.text('No pending approvals'), findsNothing);
    });

    testWidgets('the approve sheet counts down and locks on expiry', (
      tester,
    ) async {
      final repo = await _pump(tester, requests: [fresh('a')], clock: clock);
      await elapse(tester, const Duration(seconds: 100));

      await tester.tap(_approveOn('Maria Santos'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('0:20 left')),
        findsOneWidget,
      );
      final confirm = find.byKey(const Key('approve-confirm'));
      expect(tester.widget<ButtonStyleButton>(confirm).onPressed, isNotNull);

      await elapse(tester, const Duration(seconds: 20));
      expect(
        find.descendant(of: sheet, matching: find.text('Expired')),
        findsOneWidget,
      );
      expect(
        find.text('This request expired and the borrow was denied.'),
        findsOneWidget,
      );
      expect(tester.widget<ButtonStyleButton>(confirm).onPressed, isNull);
      expect(repo.approved, isEmpty);
    });

    testWidgets('a decline confirmed after expiry is not sent', (tester) async {
      final repo = await _pump(tester, requests: [fresh('a')], clock: clock);

      await tester.tap(_declineOn('Maria Santos'));
      await tester.pumpAndSettle();
      // The instructor waits too long on the dialog.
      clock.advance(const Duration(seconds: 121));
      await tester.tap(find.byKey(const Key('decline-confirm')));
      await tester.pumpAndSettle();

      expect(repo.declined, isEmpty);
      expect(
        find.text('This request timed out and the borrow was denied.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('approval-expired')), findsOneWidget);
    });

    testWidgets('pull to refresh keeps expired requests until dismissed', (
      tester,
    ) async {
      final repo = await _pump(tester, requests: [fresh('a')], clock: clock);
      await elapse(tester, const Duration(seconds: 121));
      expect(find.byKey(const Key('approval-expired')), findsOneWidget);

      // The server leaves expired requests out.
      repo.result = PendingApprovals.empty;
      await tester.fling(find.text('Maria Santos'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(repo.pendingCalls, 2);
      expect(find.byKey(const Key('approval-expired')), findsOneWidget);

      await tester.tap(_onCard('Maria Santos', find.text('Dismiss')));
      await tester.pumpAndSettle();
      expect(find.text('No pending approvals'), findsOneWidget);
    });

    testWidgets('a new request push keeps expired cards on screen', (
      tester,
    ) async {
      final repo = await _pump(tester, requests: [fresh('a')], clock: clock);
      await elapse(tester, const Duration(seconds: 121));

      repo.result = PendingApprovals(
        items: [
          approval(
            'b',
            studentName: 'John Dela Cruz',
            requestedAt: clock(),
            expiresAt: clock().add(const Duration(seconds: 120)),
          ),
        ],
      );
      // What push_notifications.dart does for `approval.requested`.
      ProviderScope.containerOf(tester.element(find.byType(ApprovalsScreen)))
          .invalidate(approvalsControllerProvider);
      await tester.pumpAndSettle();

      expect(repo.pendingCalls, 2);
      expect(_onCard('Maria Santos', find.text('Expired')), findsOneWidget);
      expect(_onCard('John Dela Cruz', find.text('2:00 left')), findsOneWidget);
    });

    testWidgets('an expired answer shows expired at once, not after a tick', (
      tester,
    ) async {
      final repo = await _pump(tester, requests: [fresh('a')], clock: clock);
      await elapse(tester, const Duration(seconds: 119));
      expect(_onCard('Maria Santos', find.text('0:01 left')), findsOneWidget);

      // Half a second passes on the way to the server, which says the
      // request expired (the phone still had it at "0:01 left").
      repo.whileDeciding = () {
        clock.advance(const Duration(milliseconds: 500));
      };
      repo.decisionError = const ApprovalFailure(
        'This request timed out and the borrow was denied.',
        code: ApprovalFailure.expired,
        requestGone: true,
      );
      await tester.tap(_declineOn('Maria Santos'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('decline-confirm')));
      // Less than one tick: only the decision's answer may update the card.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.declined, isEmpty);
      expect(find.byKey(const Key('approval-expired')), findsOneWidget);
      expect(_approveOn('Maria Santos'), findsNothing);
      expect(_onCard('Maria Santos', find.text('0:01 left')), findsNothing);
    });

    testWidgets('the countdown pauses in the background and catches up', (
      tester,
    ) async {
      await _pump(tester, requests: [fresh('a')], clock: clock);
      final binding = tester.binding;

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await elapse(tester, const Duration(seconds: 10));
      expect(_onCard('Maria Santos', find.text('2:00 left')), findsOneWidget);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(_onCard('Maria Santos', find.text('1:50 left')), findsOneWidget);
    });
  });

  testWidgets('frozen: the banner names each item and student (US-06)', (
    tester,
  ) async {
    final repo = FakeApprovalsRepository()
      ..result = const PendingApprovals(
        items: [],
        frozen: true,
        freezes: [
          ApprovalFreeze(
            id: 'f2',
            reason: FreezeReason.lateArrivalLimit,
            assetName: 'HDMI Cable',
            assetCode: 'CBL-0230',
            studentName: 'Juan Cruz',
          ),
          ApprovalFreeze(
            id: 'f1',
            reason: FreezeReason.overdue,
            assetName: 'Epson Projector',
            assetCode: 'PRJ-0012',
            studentName: 'Maria Santos',
          ),
        ],
      );
    await _pump(tester, repo: repo);

    expect(
      find.text(
        '4th late arrival: HDMI Cable (CBL-0230), borrowed by Juan Cruz',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Overdue: Epson Projector (PRJ-0012), borrowed by Maria Santos',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Technical staff must lift the freeze before you can approve. '
        'You can still decline.',
      ),
      findsOneWidget,
    );
    // Frozen with nothing pending: the banner, not the empty state.
    expect(find.text('No pending approvals'), findsNothing);
  });

  testWidgets('frozen: banner shows and Approve is disabled', (tester) async {
    final repo = FakeApprovalsRepository()
      ..result = PendingApprovals(frozen: true, items: [approval('a')]);
    await _pump(tester, repo: repo);

    expect(find.text('Approvals frozen'), findsOneWidget);
    expect(
      tester.widget<ButtonStyleButton>(_approveOn('Maria Santos')).onPressed,
      isNull,
    );
    expect(
      tester.widget<ButtonStyleButton>(_declineOn('Maria Santos')).onPressed,
      isNotNull,
    );
  });

  testWidgets('shows the empty state when nothing is pending', (tester) async {
    await _pump(tester, requests: []);
    expect(find.text('No pending approvals'), findsOneWidget);
  });

  testWidgets('load error shows the message and Try again reloads', (
    tester,
  ) async {
    final repo = FakeApprovalsRepository([approval('a')])
      ..pendingError = const Failure("Can't reach the server.");
    await _pump(tester, repo: repo);

    expect(find.text("Couldn't load approvals"), findsOneWidget);
    expect(find.text("Can't reach the server."), findsOneWidget);

    repo.pendingError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsOneWidget);
  });

  testWidgets('pull to refresh reloads the list', (tester) async {
    final repo = await _pump(tester, requests: []);
    repo.result = PendingApprovals(items: [approval('a')]);

    await tester.fling(
      find.text('No pending approvals'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repo.pendingCalls, 2);
    expect(find.text('Maria Santos'), findsOneWidget);
  });
}
