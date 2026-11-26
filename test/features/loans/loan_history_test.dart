import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/core/utils/clock.dart';
import 'package:tams_mobile/features/loans/data/repositories/loans_repository_impl.dart';
import 'package:tams_mobile/features/loans/domain/entities/loan_detail.dart';
import 'package:tams_mobile/features/loans/presentation/controllers/loan_detail_provider.dart';
import 'package:tams_mobile/features/loans/presentation/screens/loan_history_screen.dart';

import '../../helpers/fake_alerts_repository.dart' show SignedInToken;
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_loans_repository.dart';

void main() {
  final now = DateTime(2026, 11, 18, 16);

  group('repository', () {
    test('asks for every loan I approved, newest first', () async {
      final http = FakeHttpAdapter(body: {'items': [], 'total': 0});
      final page = await LoansRepositoryImpl(fakeDio(http)).myLoanHistory();

      expect(page.items, isEmpty);
      expect(page.page, 1);
      expect(http.lastRequest!.path, '/loans');
      expect(http.lastRequest!.queryParameters, {
        'approvedBy': 'me',
        'sort': '-checkedOutAt',
        'page': 1,
        'pageSize': LoansRepositoryImpl.historyPageSize,
      });
    });

    test('sends the filter as `status`, and the page', () async {
      final http = FakeHttpAdapter(body: {'items': [], 'total': 0});
      final page = await LoansRepositoryImpl(fakeDio(http))
          .myLoanHistory(filter: LoanHistoryFilter.returned, page: 3);

      expect(page.page, 3);
      expect(http.lastRequest!.queryParameters['status'], 'RETURNED');
      expect(http.lastRequest!.queryParameters['page'], 3);
    });

    test('a server error is a Failure', () async {
      final http = FakeHttpAdapter(statusCode: 500, body: {});
      expect(
        LoansRepositoryImpl(fakeDio(http)).myLoanHistory(),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('screen', () {
    final returned = openLoan(
      'r',
      dueAt: now.subtract(const Duration(hours: 4)),
      status: 'RETURNED',
      assetName: 'HDMI Cable',
      returnedAt: now.subtract(const Duration(hours: 4, minutes: 30)),
    );
    final open = openLoan(
      'o',
      dueAt: now.add(const Duration(hours: 1)),
      assetName: 'Projector',
    );
    final missing = openLoan(
      'm',
      dueAt: now.subtract(const Duration(days: 1)),
      status: 'MISSING',
      assetName: 'Laptop',
    );

    Future<FakeLoansRepository> pump(
      WidgetTester tester,
      FakeLoansRepository repo,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loansRepositoryProvider.overrideWithValue(repo),
            clockProvider.overrideWithValue(() => now),
            authTokenProvider.overrideWith(SignedInToken.new),
          ],
          child: const MaterialApp(home: LoanHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('lists open and closed loans; closed ones say how they ended', (
      tester,
    ) async {
      await pump(
        tester,
        FakeLoansRepository()..history = [open, returned, missing],
      );

      expect(find.text('Projector'), findsOneWidget);
      expect(find.text('Due in 1 h 00 min'), findsOneWidget);
      expect(find.text('Returned'), findsWidgets);
      expect(
        find.text('Checked out 18 Nov, 10:00 AM · returned 11:30 AM'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('ended-r')), findsOneWidget);
      expect(find.byKey(const ValueKey('countdown-r')), findsNothing);
      expect(find.byKey(const ValueKey('countdown-m')), findsNothing);
      expect(
        find.text('Checked out 17 Nov, 2:00 PM · marked missing'),
        findsOneWidget,
      );
    });

    testWidgets('a filter reloads with that status', (tester) async {
      final repo = await pump(
        tester,
        FakeLoansRepository()..history = [open, returned, missing],
      );
      expect(repo.historyCalls.last, (LoanHistoryFilter.all, 1));

      await tester.tap(find.byKey(const ValueKey('history-filter-returned')));
      await tester.pumpAndSettle();

      expect(repo.historyCalls.last, (LoanHistoryFilter.returned, 1));
      expect(find.text('HDMI Cable'), findsOneWidget);
      expect(find.text('Projector'), findsNothing);
      expect(find.text('Laptop'), findsNothing);
    });

    testWidgets('an empty filter says so', (tester) async {
      await pump(tester, FakeLoansRepository()..history = [open]);
      await tester.tap(find.byKey(const ValueKey('history-filter-cancelled')));
      await tester.pumpAndSettle();
      expect(find.text('No cancelled loans you approved.'), findsOneWidget);
    });

    testWidgets('scrolling to the end loads the next page', (tester) async {
      final repo = FakeLoansRepository()
        ..historyPageSize = 3
        ..history = [
          for (var i = 0; i < 5; i++)
            openLoan(
              'l$i',
              dueAt: now.subtract(Duration(days: i + 1)),
              status: 'RETURNED',
              assetName: 'Item $i',
            ),
        ];
      await pump(tester, repo);

      // The list, not the row of filter chips.
      await tester.scrollUntilVisible(
        find.text('Item 4'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(repo.historyCalls, [
        (LoanHistoryFilter.all, 1),
        (LoanHistoryFilter.all, 2),
      ]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    FakeLoansRepository fiveLoans() => FakeLoansRepository()
      ..historyPageSize = 3
      ..history = [
        for (var i = 0; i < 5; i++)
          openLoan(
            'l$i',
            dueAt: now.subtract(Duration(days: i + 1)),
            status: 'RETURNED',
            assetName: 'Item $i',
          ),
      ];

    Future<void> scrollToEnd(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Item 4'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an empty page ends the list, even short of the total', (
      tester,
    ) async {
      // A loan counted in the total but skipped as a repeat.
      final repo = fiveLoans()..historyTotal = 6;
      await pump(tester, repo);
      await scrollToEnd(tester);

      expect(repo.historyCalls, [
        (LoanHistoryFilter.all, 1),
        (LoanHistoryFilter.all, 2),
        (LoanHistoryFilter.all, 3),
      ]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a renewed token keeps the pages loaded', (tester) async {
      final repo = await pump(tester, fiveLoans());
      await scrollToEnd(tester);

      ProviderScope.containerOf(tester.element(find.byType(LoanHistoryScreen)))
          .read(authTokenProvider.notifier)
          .set('renewed-token');
      await tester.pumpAndSettle();

      expect(repo.historyCalls, [
        (LoanHistoryFilter.all, 1),
        (LoanHistoryFilter.all, 2),
      ]);
      expect(find.text('Item 4'), findsOneWidget);
    });
    testWidgets("a filter change mid-page still loads the new filter's pages", (
      tester,
    ) async {
      final held = Completer<void>();
      final repo = fiveLoans()
        ..beforeHistory = (filter, page) async {
          if (filter == LoanHistoryFilter.all && page == 2) await held.future;
        };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loansRepositoryProvider.overrideWithValue(repo),
            clockProvider.overrideWithValue(() => now),
            authTokenProvider.overrideWith(SignedInToken.new),
          ],
          child: const MaterialApp(home: LoanHistoryScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      // All's page 2 is under way and stays open.
      expect(repo.historyCalls.last, (LoanHistoryFilter.all, 2));

      await tester.tap(find.byKey(const ValueKey('history-filter-returned')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(repo.historyCalls, contains((LoanHistoryFilter.returned, 2)));
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // All's late page is dropped, not added to Returned's list.
      held.complete();
      await tester.pumpAndSettle();
      await scrollToEnd(tester);
      expect(find.text('Item 4'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed page offers a retry instead of spinning', (
      tester,
    ) async {
      var offline = true;
      final repo = fiveLoans()
        ..beforeHistory = (filter, page) async {
          if (page == 2 && offline) throw const Failure('Offline.');
        };
      await pump(tester, repo);

      final retry = find.byKey(const ValueKey('history-load-more-retry'));
      expect(retry, findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Nothing retries on its own while the row shows.
      expect(repo.historyCalls, [
        (LoanHistoryFilter.all, 1),
        (LoanHistoryFilter.all, 2),
      ]);

      offline = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(retry, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(repo.historyCalls.last, (LoanHistoryFilter.all, 2));
      expect(repo.historyCalls, hasLength(3));
    });

    testWidgets('a retry that fails again stays on the error', (tester) async {
      await pump(
        tester,
        FakeLoansRepository()..error = const Failure('Offline.'),
      );

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text("Couldn't load your loan history"), findsOneWidget);
    });

    testWidgets('an error offers a retry', (tester) async {
      final repo = FakeLoansRepository()..error = const Failure('Offline.');
      await pump(tester, repo);
      expect(find.text("Couldn't load your loan history"), findsOneWidget);

      repo
        ..error = null
        ..history = [returned];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('HDMI Cable'), findsOneWidget);
    });
  });
}
