import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
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
      overrides: [approvalsRepositoryProvider.overrideWithValue(fake)],
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

  testWidgets('an expired decline removes the request and says so', (
    tester,
  ) async {
    final repo = FakeApprovalsRepository([approval('a')])
      ..decisionError = const ApprovalFailure(
        'This request timed out and the borrow was denied.',
        code: 'APPROVAL_EXPIRED',
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
    expect(find.text('No pending approvals'), findsOneWidget);
  });

  testWidgets('requests drop off once their 120 s run out', (tester) async {
    await _pump(
      tester,
      requests: [
        approval(
          'a',
          expiresAt: DateTime.now().add(const Duration(seconds: 2)),
        ),
      ],
    );
    expect(find.text('Maria Santos'), findsOneWidget);

    // The countdown uses the real clock, so let real time pass.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 3)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Maria Santos'), findsNothing);
    expect(find.text('No pending approvals'), findsOneWidget);
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
