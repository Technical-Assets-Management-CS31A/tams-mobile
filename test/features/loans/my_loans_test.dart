import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/core/utils/clock.dart';
import 'package:tams_mobile/core/utils/time_format.dart';
import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/features/loans/data/models/loan_detail_model.dart';
import 'package:tams_mobile/features/loans/data/repositories/loans_repository_impl.dart';
import 'package:tams_mobile/features/loans/domain/entities/loan_detail.dart';
import 'package:tams_mobile/features/loans/presentation/controllers/loan_detail_provider.dart';
import 'package:tams_mobile/features/loans/presentation/screens/my_loans_screen.dart';

import '../../helpers/fake_alerts_repository.dart' show SignedInToken;
import '../../helpers/fake_approvals_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_loans_repository.dart';

/// A `GET /loans` item as tams-backend `LoanEndpoints.DtosAsync` sends it.
Map<String, Object?> _item(String id, {Object? checkedOutAt}) => {
  'id': id,
  'loanNo': 'L-2026-$id',
  'type': 'STANDARD',
  'status': 'ACTIVE',
  'custodyState': 'AWAITING_ARRIVAL',
  'asset': {
    'id': 'a-$id',
    'assetCode': 'PRJ-0012',
    'name': 'Epson Projector',
    'status': 'IN_TRANSIT',
  },
  'student': {
    'id': 'st-1',
    'studentNo': '2023-00142',
    'fullName': 'Maria Santos',
    'sectionCode': 'BSCS-3A',
  },
  'destinationRoom': {'id': 'r-1', 'code': 'CL1', 'name': 'Computer Lab 1'},
  'checkedOutAt': checkedOutAt,
  'transitDeadlineAt': '2026-11-18T01:10:00Z',
  'classLengthMinutes': 90,
  'classEndsAt': '2026-11-18T02:30:00Z',
  'graceMinutes': 15,
  'dueAt': '2026-11-18T02:45:00Z',
};

void main() {
  group('parse', () {
    test('reads live status fields and the grace', () {
      final page = parseLoansPage({
        'items': [_item('1', checkedOutAt: '2026-11-18T01:00:00Z')],
        'page': 1,
        'pageSize': 100,
        'total': 1,
      }, baseUrl: 'http://test.local');

      final loan = page.items.single;
      expect(page.total, 1);
      expect(loan.assetStatus, 'IN_TRANSIT');
      expect(loan.custodyState, 'AWAITING_ARRIVAL');
      expect(loan.graceMinutes, 15);
      expect(loan.classEndsAt!.toUtc(), DateTime.utc(2026, 11, 18, 2, 30));
      expect(loan.dueAt!.toUtc(), DateTime.utc(2026, 11, 18, 2, 45));
      expect(loan.borrower, 'Maria Santos');
    });

    test('skips a malformed row instead of failing the list', () {
      final page = parseLoansPage({
        'items': [
          _item('1', checkedOutAt: '2026-11-18T01:00:00Z'),
          _item('2'), // no checkedOutAt
          'junk',
        ],
        'total': 3,
      }, baseUrl: 'http://test.local');
      expect(page.items.map((l) => l.id), ['1']);
      expect(page.total, 3);
    });

    test('asks for my open loans, soonest due first', () async {
      final http = FakeHttpAdapter(body: {'items': [], 'total': 0});
      final page = await LoansRepositoryImpl(fakeDio(http)).myOpenLoans();

      expect(page.items, isEmpty);
      expect(http.lastRequest!.path, '/loans');
      expect(http.lastRequest!.queryParameters, {
        'approvedBy': 'me',
        'status': 'open',
        'sort': 'dueAt',
        'pageSize': 100,
      });
    });

    test('a body without items is a Failure', () async {
      final http = FakeHttpAdapter(body: {'loan': {}});
      expect(
        LoansRepositoryImpl(fakeDio(http)).myOpenLoans(),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('liveStatus', () {
    final now = DateTime(2026, 11, 18, 10);
    final later = now.add(const Duration(hours: 1));
    LoanLiveStatus of({
      String status = 'ACTIVE',
      String? custody,
      String? asset,
      DateTime? due,
    }) => openLoan(
      'x',
      dueAt: due ?? later,
      status: status,
      custodyState: custody,
      assetStatus: asset,
    ).liveStatus(now);

    test('maps custody and item status to the board columns', () {
      expect(
        of(custody: 'AWAITING_ARRIVAL', asset: 'IN_TRANSIT'),
        LoanLiveStatus.inTransit,
      );
      expect(
        of(custody: 'VERIFIED', asset: 'IN_ROOM_VERIFIED'),
        LoanLiveStatus.verifiedInRoom,
      );
      // Event loan to a venue without a room station.
      expect(of(custody: 'NOT_REQUIRED'), LoanLiveStatus.verifiedInRoom);
      expect(
        of(custody: 'VERIFIED', asset: 'AT_COUNTER'),
        LoanLiveStatus.atCounter,
      );
      expect(
        of(custody: 'ANOMALY', asset: 'LOCATION_ANOMALY'),
        LoanLiveStatus.anomaly,
      );
      expect(of(), LoanLiveStatus.atCounter);
    });

    test('overdue as soon as the due time (grace included) passes', () {
      expect(of(status: 'OVERDUE'), LoanLiveStatus.overdue);
      expect(
        of(custody: 'VERIFIED', due: now.subtract(const Duration(seconds: 1))),
        LoanLiveStatus.overdue,
      );
      expect(of(custody: 'VERIFIED', due: now), LoanLiveStatus.overdue);
    });

    test('closed loans', () {
      expect(of(status: 'MISSING'), LoanLiveStatus.missing);
      expect(of(status: 'RETURNED'), LoanLiveStatus.returned);
      expect(of(status: 'CANCELLED'), LoanLiveStatus.cancelled);
    });
  });

  test('formatCountdown', () {
    expect(formatCountdown(const Duration(hours: 1, minutes: 5)), '1 h 05 min');
    expect(
      formatCountdown(const Duration(hours: 3, minutes: 30)),
      '3 h 30 min',
    );
    expect(formatCountdown(const Duration(minutes: 4, seconds: 7)), '4:07');
    expect(formatCountdown(const Duration(seconds: 9)), '0:09');
    expect(formatCountdown(const Duration(minutes: -12, seconds: -4)), '12:04');
  });

  group('screen', () {
    late DateTime now;

    Future<FakeLoansRepository> pump(
      WidgetTester tester,
      FakeLoansRepository repo, {
      FakeApprovalsRepository? approvals,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loansRepositoryProvider.overrideWithValue(repo),
            approvalsRepositoryProvider.overrideWithValue(
              approvals ?? FakeApprovalsRepository(),
            ),
            clockProvider.overrideWithValue(() => now),
            authTokenProvider.overrideWith(SignedInToken.new),
          ],
          child: const MaterialApp(home: Scaffold(body: MyLoansScreen())),
        ),
      );
      // Not pumpAndSettle: the countdown ticks every second.
      await tester.pump();
      await tester.pump();
      return repo;
    }

    setUp(() => now = DateTime(2026, 11, 18, 10));

    testWidgets('shows each loan with its status and countdown', (
      tester,
    ) async {
      await pump(
        tester,
        FakeLoansRepository([
          openLoan(
            'a',
            dueAt: now.add(const Duration(hours: 1, minutes: 5)),
            assetName: 'Projector',
          ),
          openLoan(
            'b',
            dueAt: now.add(const Duration(hours: 2)),
            custodyState: 'AWAITING_ARRIVAL',
            assetStatus: 'IN_TRANSIT',
            transitDeadlineAt: now.add(const Duration(minutes: 7)),
            assetName: 'HDMI Cable',
          ),
          openLoan(
            'c',
            dueAt: now.subtract(const Duration(minutes: 12)),
            status: 'OVERDUE',
            assetName: 'Laptop',
          ),
        ]),
      );

      expect(find.text('Verified in Room'), findsOneWidget);
      expect(find.text('In Transit'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Due in 1 h 05 min'), findsOneWidget);
      expect(find.text('Overdue by 12:00'), findsOneWidget);
      expect(find.text('Check in at the room within 7:00'), findsOneWidget);
      expect(
        find.text('Due 11:05 AM · class ends 10:50 AM + 15 min grace'),
        findsOneWidget,
      );

      // Overdue comes first, then the soonest due.
      final titles = ['Laptop', 'Projector', 'HDMI Cable'];
      final ys = [for (final t in titles) tester.getTopLeft(find.text(t)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
    });

    testWidgets('the countdown ticks and turns overdue past due', (
      tester,
    ) async {
      await pump(
        tester,
        FakeLoansRepository([
          openLoan('a', dueAt: now.add(const Duration(seconds: 2))),
        ]),
      );
      expect(find.text('Due in 0:02'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Due in 0:01'), findsOneWidget);

      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Overdue by 0:02'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('reloads every minute', (tester) async {
      final repo = await pump(tester, FakeLoansRepository());
      expect(repo.listCalls, 1);

      await tester.pump(MyLoansScreen.pollEvery);
      await tester.pump();
      expect(repo.listCalls, 2);
    });

    testWidgets('frozen: the banner names the item and student (US-06)', (
      tester,
    ) async {
      final approvals = FakeApprovalsRepository()
        ..result = const PendingApprovals(
          items: [],
          frozen: true,
          freezes: [
            ApprovalFreeze(
              id: 'f1',
              reason: FreezeReason.overdue,
              assetName: 'Epson Projector',
              assetCode: 'PRJ-0012',
              studentName: 'Maria Santos',
            ),
          ],
        );
      await pump(tester, FakeLoansRepository(), approvals: approvals);

      expect(find.text('Approvals frozen'), findsOneWidget);
      expect(
        find.text(
          'Overdue: Epson Projector (PRJ-0012), borrowed by Maria Santos',
        ),
        findsOneWidget,
      );
      // Declining is only offered on Pending Approvals.
      expect(find.textContaining('You can still decline'), findsNothing);
    });

    testWidgets('no banner while not frozen', (tester) async {
      await pump(tester, FakeLoansRepository());
      expect(find.text('Approvals frozen'), findsNothing);
      expect(find.text('History'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await pump(tester, FakeLoansRepository());
      expect(find.text('No active loans'), findsOneWidget);
    });

    testWidgets('an error offers a retry', (tester) async {
      final repo = FakeLoansRepository()
        ..error = const Failure('No connection.');
      await pump(tester, repo);
      expect(find.text("Couldn't load your loans"), findsOneWidget);
      expect(find.text('No connection.'), findsOneWidget);

      repo
        ..error = null
        ..loans = [openLoan('a', dueAt: now.add(const Duration(hours: 1)))];
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Due in 1 h 00 min'), findsOneWidget);
    });
  });
}
