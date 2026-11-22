import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/loans/data/models/loan_detail_model.dart';
import 'package:tams_mobile/features/loans/data/repositories/loans_repository_impl.dart';
import 'package:tams_mobile/features/loans/domain/entities/loan_detail.dart';
import 'package:tams_mobile/features/loans/domain/repositories/loans_repository.dart';
import 'package:tams_mobile/features/loans/presentation/controllers/loan_detail_provider.dart';
import 'package:tams_mobile/features/loans/presentation/screens/loan_detail_screen.dart';

import '../../helpers/fake_http_adapter.dart';

/// `GET /loans/{id}` as tams-backend `LoanEndpoints.DetailAsync` sends it.
Map<String, Object?> _body({String status = 'OVERDUE', Object? photo}) => {
  'loan': {
    'id': 'loan-1',
    'loanNo': 'L-2026-0042',
    'type': 'STANDARD',
    'status': status,
    'custodyState': 'ANOMALY',
    'asset': {
      'id': 'a-1',
      'assetCode': 'PRJ-0012',
      'name': 'Epson Projector',
      'status': 'OVERDUE',
    },
    'student': {
      'id': 'st-1',
      'studentNo': '2023-00142',
      'fullName': 'Maria Santos',
      'sectionCode': 'BSCS-3A',
    },
    'approvedBy': {'id': 'u-1', 'fullName': 'Ana Reyes'},
    'coordinator': null,
    'event': null,
    'destinationRoom': {'id': 'r-1', 'code': 'CL1', 'name': 'Computer Lab 1'},
    'checkedOutAt': '2026-11-18T01:00:00Z',
    'transitDeadlineAt': '2026-11-18T01:10:00Z',
    'verifiedAt': null,
    'classLengthMinutes': 90,
    'dueAt': '2026-11-18T02:45:00Z',
    'overdueAt': '2026-11-18T02:45:30Z',
    'missingAt': null,
    'returnedAt': null,
    'photoUrl': photo,
    'lateArrivalWarningNo': 2,
  },
  'approval': {'id': 'ap-1'},
  'ledger': [
    {'id': 'l1', 'event': 'CHECKED_OUT', 'occurredAt': '2026-11-18T01:00:00Z'},
    {
      'id': 'l2',
      'event': 'LATE_ARRIVAL_WARNING',
      'occurredAt': '2026-11-18T01:10:00Z',
    },
    {'id': 'l3', 'event': 'OVERDUE', 'occurredAt': '2026-11-18T02:45:30Z'},
  ],
};

class _FakeLoans implements LoansRepository {
  _FakeLoans(this.result);

  LoanDetail? result;
  Object? error;

  @override
  Future<LoansPage> myOpenLoans() async => LoansPage.empty;

  @override
  Future<LoanDetail> detail(String id) async {
    if (error case final e?) throw e;
    return result!;
  }
}

Future<void> _pump(WidgetTester tester, LoansRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loansRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: LoanDetailScreen(loanId: 'loan-1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('parse', () {
    test('reads the loan, student, room and ledger', () {
      final loan = parseLoanDetail(
        _body(photo: '/api/loans/loan-1/photo'),
        baseUrl: 'http://test.local/api/v1',
      );
      expect(loan.loanNo, 'L-2026-0042');
      expect(loan.status, 'OVERDUE');
      expect(loan.isOpen, isTrue);
      expect(loan.assetName, 'Epson Projector');
      expect(loan.studentName, 'Maria Santos');
      expect(loan.sectionCode, 'BSCS-3A');
      expect(loan.room, 'Computer Lab 1 (CL1)');
      expect(loan.lateArrivalWarningNo, 2);
      expect(loan.photoUrl, 'http://test.local/api/loans/loan-1/photo');
      expect(loan.ledger.map((e) => e.event), [
        'CHECKED_OUT',
        'LATE_ARRIVAL_WARNING',
        'OVERDUE',
      ]);
    });

    test('a body without a loan is a FormatException', () {
      expect(
        () => parseLoanDetail({'items': []}, baseUrl: 'http://x'),
        throwsFormatException,
      );
    });

    test('a loan I may not see is "no longer available"', () async {
      final http = FakeHttpAdapter(
        statusCode: 404,
        body: {
          'status': 404,
          'code': 'LOAN_NOT_FOUND',
          'detail': 'Loan not found.',
        },
      );
      await expectLater(
        LoansRepositoryImpl(fakeDio(http)).detail('loan-1'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'This loan is no longer available.',
          ),
        ),
      );
      expect(http.lastRequest!.path, '/loans/loan-1');
    });
  });

  testWidgets('shows the loan the alert is about', (tester) async {
    // Tall enough for the activity list, which the ListView builds lazily.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final loan = parseLoanDetail(_body(), baseUrl: 'http://test.local');
    await _pump(tester, _FakeLoans(loan));

    expect(find.text('L-2026-0042'), findsOneWidget); // app bar
    expect(find.text('Epson Projector'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StatusChip),
        matching: find.text('Overdue'),
      ),
      findsOneWidget,
    );
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('2023-00142 · BSCS-3A'), findsOneWidget);
    expect(find.text('Computer Lab 1 (CL1)'), findsOneWidget);
    expect(find.text('Not checked in at the room in time'), findsOneWidget);
    expect(find.text('Overdue since'), findsOneWidget);
    expect(find.text('#2 this term'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Late arrival warning'), findsNWidgets(2));
  });

  testWidgets('shows the error and retries', (tester) async {
    final repo = _FakeLoans(null)
      ..error = const Failure('This loan is no longer available.');
    await _pump(tester, repo);
    expect(find.text("Couldn't load this loan"), findsOneWidget);
    expect(find.text('This loan is no longer available.'), findsOneWidget);

    repo
      ..error = null
      ..result = parseLoanDetail(_body(), baseUrl: 'http://test.local');
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Epson Projector'), findsOneWidget);
  });

  test('humanize turns codes into words', () {
    expect(humanize('LATE_ARRIVAL_WARNING'), 'Late arrival warning');
    expect(humanize('OVERDUE'), 'Overdue');
  });
}
