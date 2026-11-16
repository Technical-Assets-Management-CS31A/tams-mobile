import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:tams_mobile/features/approvals/presentation/widgets/student_avatar.dart';

final _requests = [
  PendingApproval(
    id: 'a',
    studentName: 'Maria Santos',
    studentNumber: '2023-00142',
    itemName: 'Epson Projector',
    assetTag: 'PRJ-0012',
    requestedAt: DateTime.now().subtract(const Duration(minutes: 4)),
  ),
  PendingApproval(
    id: 'b',
    studentName: 'John Dela Cruz',
    studentNumber: '2022-00871',
    itemName: 'HDMI Cable',
    assetTag: 'CBL-0230',
    requestedAt: DateTime.now().subtract(const Duration(minutes: 18)),
  ),
];

/// Mock requests without photos, so tests never touch the network.
class _TestApprovals extends ApprovalsController {
  @override
  List<PendingApproval> build() => _requests;
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        approvalsControllerProvider.overrideWith(_TestApprovals.new),
        roomsProvider.overrideWithValue(['Room 301', 'AVR']),
      ],
      child: const MaterialApp(home: Scaffold(body: ApprovalsScreen())),
    ),
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(ApprovalsScreen)),
  );
}

Finder _approveOn(String student) => find.descendant(
  of: find.ancestor(of: find.text(student), matching: find.byType(Card)),
  matching: find.widgetWithText(FilledButton, 'Approve'),
);

List<String> _ids(ProviderContainer c) => [
  for (final r in c.read(approvalsControllerProvider)) r.id,
];

void main() {
  testWidgets('lists each request with photo, student and item', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(StudentAvatar), findsNWidgets(2));
    expect(find.text('MS'), findsOneWidget); // initials when no photo
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Epson Projector'), findsOneWidget);
    expect(find.text('PRJ-0012'), findsOneWidget);
    expect(find.text('4 min ago'), findsOneWidget);
    expect(find.text('John Dela Cruz'), findsOneWidget);
  });

  testWidgets('approve: pick room and class length, then confirm', (
    tester,
  ) async {
    final container = await _pump(tester);

    await tester.tap(_approveOn('Maria Santos'));
    await tester.pumpAndSettle();
    expect(find.text('Approve request'), findsOneWidget);

    // Every class length from 1.5 to 3 h is offered; 1.5 h is the default.
    for (final label in ['1.5 h', '2 h', '2.5 h', '3 h']) {
      expect(find.text(label), findsOneWidget);
    }

    // Can't approve until a room is picked.
    final confirm = find.byKey(const Key('approve-confirm'));
    expect(tester.widget<ButtonStyleButton>(confirm).onPressed, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AVR').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2.5 h'));
    await tester.pumpAndSettle();

    expect(tester.widget<ButtonStyleButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('Approve request'), findsNothing);
    expect(_ids(container), ['b']);
    expect(
      find.text('Approved Epson Projector for Maria Santos · AVR, 2.5 h'),
      findsOneWidget,
    );
  });

  testWidgets('closing the sheet keeps the request', (tester) async {
    final container = await _pump(tester);

    await tester.tap(_approveOn('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // tap the scrim
    await tester.pumpAndSettle();

    expect(find.text('Approve request'), findsNothing);
    expect(_ids(container), ['a', 'b']);
  });

  testWidgets('reject removes the request and Undo brings it back', (
    tester,
  ) async {
    final container = await _pump(tester);

    await tester.tap(find.text('Reject').first);
    await tester.pumpAndSettle();
    expect(_ids(container), ['b']);
    expect(find.text('Maria Santos'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(_ids(container), ['a', 'b']);
  });

  testWidgets('shows the empty state once nothing is pending', (tester) async {
    final container = await _pump(tester);

    container.read(approvalsControllerProvider.notifier)
      ..reject('a')
      ..reject('b');
    await tester.pumpAndSettle();

    expect(find.text('No pending approvals'), findsOneWidget);
  });
}
