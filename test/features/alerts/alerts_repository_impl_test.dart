import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/alerts/data/datasources/alerts_remote_datasource.dart';
import 'package:tams_mobile/features/alerts/data/repositories/alerts_repository_impl.dart';
import 'package:tams_mobile/features/alerts/domain/entities/alert.dart';
import 'package:tams_mobile/features/alerts/domain/repositories/alerts_repository.dart';

import '../../helpers/fake_http_adapter.dart';

/// A late arrival warning as tams-backend `LoanRules.LateArrivalAsync`
/// stores it.
Map<String, Object?> _lateArrival({
  String id = 'n-1',
  String createdAt = '2026-11-18T02:10:00+00:00',
  String? readAt,
}) => {
  'id': id,
  'type': 'LATE_ARRIVAL_WARNING',
  'title': 'Item not checked in at the room',
  'body':
      'Maria Santos (BSCS-3A), PRJ-0012 was not tapped at the room in time. '
      'Late Arrival Warning #2.',
  'loanId': 'loan-1',
  'studentId': 'st-1',
  'createdAt': createdAt,
  'readAt': readAt,
  'payload': {
    'anomalyId': 'an-1',
    'warningNo': 2,
    'penaltyTriggered': false,
    'studentName': 'Maria Santos',
    'sectionCode': 'BSCS-3A',
    'assetCode': 'PRJ-0012',
    'loanNo': 'L-2026-0042',
    'details': {'assetCode': 'PRJ-0012', 'assetName': 'Epson Projector'},
  },
};

void main() {
  late FakeHttpAdapter http;
  late AlertsRepository repo;

  setUp(() {
    http = FakeHttpAdapter();
    repo = AlertsRepositoryImpl(AlertsRemoteDataSource(fakeDio(http)));
  });

  group('list', () {
    test('asks for one page and parses each alert', () async {
      http.body = {
        'items': [_lateArrival()],
        'page': 1,
        'pageSize': 25,
        'total': 1,
        'unreadCount': 1,
      };

      final page = await repo.list();

      expect(http.lastRequest!.method, 'GET');
      expect(http.lastRequest!.path, '/notifications');
      expect(http.lastRequest!.queryParameters, {'page': 1, 'pageSize': 25});
      expect(page.total, 1);
      expect(page.unreadCount, 1);
      final a = page.items.single;
      expect(a.id, 'n-1');
      expect(a.kind, AlertKind.lateArrival);
      expect(a.title, 'Item not checked in at the room');
      expect(a.loanId, 'loan-1');
      expect(a.loanNo, 'L-2026-0042');
      expect(a.who, 'Maria Santos · BSCS-3A');
      expect(a.warningNo, 2);
      expect(a.penaltyTriggered, isFalse);
      expect(a.isUnread, isTrue);
      expect(a.createdAt, DateTime.utc(2026, 11, 18, 2, 10).toLocal());
      expect(a.createdAt.isUtc, isFalse, reason: 'shown in local time');
    });

    test('asks for the page it is given', () async {
      http.body = {'items': [], 'page': 3, 'total': 60, 'unreadCount': 0};
      final page = await repo.list(page: 3);
      expect(http.lastRequest!.queryParameters['page'], 3);
      expect(page.page, 3);
    });

    test('reads the student from details when the payload lacks it', () async {
      http.body = {
        'items': [
          {
            'id': 'n-2',
            'type': 'ANOMALY_RAISED',
            'title': 'Item scanned in the wrong room',
            'body': 'Epson Projector (PRJ-0012) was scanned in ST-CL2.',
            'loanId': 'loan-1',
            'createdAt': '2026-11-18T02:10:00Z',
            'readAt': '2026-11-18T02:11:00Z',
            'payload': {
              'type': 'WRONG_ROOM',
              'details': {'studentName': 'Juan Cruz', 'sectionCode': 'IT-2B'},
            },
          },
        ],
      };
      final a = (await repo.list()).items.single;
      expect(a.kind, AlertKind.anomaly);
      expect(a.who, 'Juan Cruz · IT-2B');
      expect(a.isUnread, isFalse);
    });

    test('kinds follow the notification type', () {
      expect(AlertKind.fromType('LATE_ARRIVAL_WARNING'), AlertKind.lateArrival);
      expect(AlertKind.fromType('ANOMALY_RAISED'), AlertKind.anomaly);
      expect(AlertKind.fromType('TRANSIT_TIMEOUT'), AlertKind.anomaly);
      expect(AlertKind.fromType('LOAN_OVERDUE'), AlertKind.overdue);
      expect(AlertKind.fromType('LOAN_MISSING'), AlertKind.missing);
      expect(AlertKind.fromType('STATION_OFFLINE'), AlertKind.other);
    });

    test('skips a malformed row instead of failing the list', () async {
      http.body = {
        'items': [
          _lateArrival(),
          {'id': 'bad', 'type': 'LOAN_OVERDUE'}, // no createdAt
          'not an object',
        ],
        'total': 3,
        'unreadCount': 3,
      };
      final page = await repo.list();
      expect(page.items.map((a) => a.id), ['n-1']);
    });

    test('a body without items is a Failure', () async {
      http.body = {'data': []};
      await expectLater(
        repo.list(),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Unexpected response from the server.',
          ),
        ),
      );
    });

    test('network errors are a Failure', () async {
      http.error = DioExceptionType.connectionError;
      await expectLater(repo.list(), throwsA(isA<Failure>()));
    });
  });

  group('markRead', () {
    test('posts to the read endpoint', () async {
      http.body = {'id': 'n-1', 'readAt': '2026-11-18T02:11:00Z'};
      await repo.markRead('n-1');
      expect(http.lastRequest!.method, 'POST');
      expect(http.lastRequest!.path, '/notifications/n-1/read');
    });

    test('errors are a Failure', () async {
      http
        ..statusCode = 404
        ..body = {
          'status': 404,
          'code': 'NOTIFICATION_NOT_FOUND',
          'detail': 'Notification not found.',
        };
      await expectLater(repo.markRead('n-1'), throwsA(isA<Failure>()));
    });
  });

  group('AlertsFeed', () {
    AlertsPage page(List<Alert> items, {int page = 1, int total = 3}) =>
        AlertsPage(
          items: items,
          page: page,
          total: total,
          unreadCount: items.where((a) => a.isUnread).length,
        );

    Alert at(String id, int minute, {bool read = false}) => Alert(
      id: id,
      type: 'LOAN_OVERDUE',
      title: 'Loan overdue',
      body: '',
      createdAt: DateTime(2026, 11, 18, 10, minute),
      readAt: read ? DateTime(2026, 11, 18, 11) : null,
    );

    test('is newest first', () {
      final feed = AlertsFeed.first(page([at('a', 1), at('c', 3), at('b', 2)]));
      expect(feed.items.map((a) => a.id), ['c', 'b', 'a']);
    });

    test('adding a page keeps each alert once', () {
      final feed = AlertsFeed.first(page([at('c', 3), at('b', 2)]))
          .adding(page([at('b', 2), at('a', 1)], page: 2));
      expect(feed.items.map((a) => a.id), ['c', 'b', 'a']);
      expect(feed.page, 2);
      expect(feed.hasMore, isFalse);
    });

    test('an empty page ends it even when short of the total', () {
      // e.g. a malformed row was skipped, so items never reach total.
      final feed = AlertsFeed.first(page([at('c', 3), at('b', 2)]));
      expect(feed.hasMore, isTrue);

      final ended = feed.adding(page([], page: 2));
      expect(ended.items, hasLength(2));
      expect(ended.hasMore, isFalse);
      expect(
        ended.markingRead('c', DateTime(2026, 11, 18, 12)).hasMore,
        isFalse,
      );
    });

    test('an empty first page has nothing more', () {
      expect(AlertsFeed.first(page([])).hasMore, isFalse);
    });

    test('marking read lowers the unread count once', () {
      final feed = AlertsFeed.first(page([at('a', 1), at('b', 2)]));
      final read = feed.markingRead('a', DateTime(2026, 11, 18, 12));
      expect(read.unreadCount, 1);
      expect(read.items.firstWhere((a) => a.id == 'a').isUnread, isFalse);
      expect(read.markingRead('a', DateTime(2026, 11, 18, 12)), same(read));
      expect(read.markingRead('missing', DateTime.now()), same(read));
    });
  });
}
