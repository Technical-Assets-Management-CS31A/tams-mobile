import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/approvals/data/datasources/approvals_remote_datasource.dart';
import 'package:tams_mobile/features/approvals/data/repositories/approvals_repository_impl.dart';
import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/domain/repositories/approvals_repository.dart';

import '../../helpers/fake_http_adapter.dart';

/// One item of `GET /approvals/pending`, as tams-backend sends it.
Map<String, Object?> _item({
  String sessionId = 's-1',
  Object? items,
  Object? defaultRoomId = 'r-2',
  Object? classLengthOptions = const [90, 120, 150, 180],
  Object? defaultClassLengthMinutes = 120,
}) => {
  'sessionId': sessionId,
  'student': {
    'id': 'st-1',
    'studentNo': '2023-00142',
    'fullName': 'Maria Santos',
    'sectionCode': 'BSCS-3A',
  },
  'asset': {'id': 'a-1', 'assetCode': 'PRJ-0012', 'name': 'Epson Projector'},
  'items':
      items ??
      [
        {
          'id': 'a-1',
          'assetCode': 'PRJ-0012',
          'name': 'Epson Projector',
          'condition': 'GOOD',
        },
        {
          'id': 'a-2',
          'assetCode': 'CBL-0230',
          'name': 'HDMI Cable',
          'condition': 'GOOD',
        },
      ],
  'photoUrl': '/api/approvals/$sessionId/photo',
  'roomOptions': [
    {'id': 'r-1', 'code': 'AVR', 'name': 'Audio-Visual Room'},
    {'id': 'r-2', 'code': 'CL1', 'name': 'Computer Lab 1'},
  ],
  'defaultRoomId': defaultRoomId,
  'classLengthOptions': classLengthOptions,
  'defaultClassLengthMinutes': defaultClassLengthMinutes,
  'requestedAt': '2026-11-18T02:00:00+00:00',
  'expiresAt': '2026-11-18T02:02:00+00:00',
};

Map<String, Object?> _problem(int status, String code, String detail) => {
  'type': 'https://tools.ietf.org/html/rfc9110',
  'title': 'Conflict',
  'status': status,
  'detail': detail,
  'code': code,
  'traceId': '00-abc',
};

void main() {
  late FakeHttpAdapter http;
  late ApprovalsRepository repo;

  setUp(() {
    http = FakeHttpAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api'))
      ..httpClientAdapter = http;
    repo = ApprovalsRepositoryImpl(ApprovalsRemoteDataSource(dio));
  });

  group('pending', () {
    test('parses requests, rooms, default room and class lengths', () async {
      http.body = {
        'frozen': false,
        'freezes': [],
        'items': [_item()],
      };

      final result = await repo.pending();

      expect(http.lastRequest!.method, 'GET');
      expect(http.lastRequest!.path, '/approvals/pending');
      expect(result.frozen, isFalse);
      final r = result.items.single;
      expect(r.id, 's-1');
      expect(r.studentName, 'Maria Santos');
      expect(r.studentNumber, '2023-00142');
      expect(r.sectionCode, 'BSCS-3A');
      expect(r.items.map((i) => i.assetCode), ['PRJ-0012', 'CBL-0230']);
      expect(r.itemName, 'Epson Projector');
      expect(r.photoUrl, 'http://test.local/api/approvals/s-1/photo');
      expect(r.roomOptions.map((x) => x.label), [
        'Audio-Visual Room (AVR)',
        'Computer Lab 1 (CL1)',
      ]);
      expect(r.defaultRoom?.id, 'r-2');
      expect(r.classLengthOptions, standardClassLengths);
      expect(r.defaultClassLength, const Duration(minutes: 120));
      expect(r.expiresAt.difference(r.requestedAt), const Duration(minutes: 2));
      expect(r.expiresAt.isUtc, isFalse, reason: 'shown in local time');
    });

    test('frozen instructor', () async {
      http.body = {
        'frozen': true,
        'freezes': [{}],
        'items': [],
      };
      final result = await repo.pending();
      expect(result.frozen, isTrue);
      expect(result.items, isEmpty);
    });

    test(
      'falls back to `asset`, standard lengths and no default room',
      () async {
        http.body = {
          'items': [
            _item(
              items: [],
              defaultRoomId: null,
              classLengthOptions: null,
              defaultClassLengthMinutes: 45,
            ),
          ],
        };
        final r = (await repo.pending()).items.single;
        expect(r.items.single.name, 'Epson Projector');
        expect(r.defaultRoom, isNull);
        expect(r.classLengthOptions, standardClassLengths);
        expect(r.defaultClassLength, const Duration(minutes: 90));
      },
    );

    test('a default room that is not an option is not pre-selected', () async {
      http.body = {
        'items': [_item(defaultRoomId: 'storage-room')],
      };
      expect((await repo.pending()).items.single.defaultRoom, isNull);
    });

    test('unexpected body is a Failure', () async {
      http.body = {'data': []};
      await expectLater(
        repo.pending(),
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
      await expectLater(repo.pending(), throwsA(isA<Failure>()));
    });

    group('clock skew', () {
      // The server answered at 02:00:30 UTC, 30 s into the 120 s window.
      const serverDate = 'Wed, 18 Nov 2026 02:00:30 GMT';
      final serverNow = DateTime.utc(2026, 11, 18, 2, 0, 30);
      final serverExpiry = DateTime.utc(2026, 11, 18, 2, 2);

      Future<PendingApproval> fetchWithPhoneAt(DateTime phoneNow) {
        final dio = Dio(BaseOptions(baseUrl: 'http://test.local/api'))
          ..httpClientAdapter = http;
        http
          ..body = {
            'items': [_item()],
          }
          ..headers = {
            'date': [serverDate],
          };
        return ApprovalsRepositoryImpl(
          ApprovalsRemoteDataSource(dio, now: () => phoneNow),
        ).pending().then((p) => p.items.single);
      }

      test('a phone clock that runs ahead still shows 90 s left', () async {
        final phoneNow = serverNow.add(const Duration(seconds: 25));
        final r = await fetchWithPhoneAt(phoneNow);
        expect(r.timeLeft(phoneNow), const Duration(seconds: 90));
        expect(
          r.expiresAt.difference(r.requestedAt),
          const Duration(minutes: 2),
        );
      });

      test('a phone clock that runs behind still shows 90 s left', () async {
        final phoneNow = serverNow.subtract(const Duration(minutes: 3));
        final r = await fetchWithPhoneAt(phoneNow);
        expect(r.timeLeft(phoneNow), const Duration(seconds: 90));
      });

      test('differences under 3 s are ignored', () async {
        final phoneNow = serverNow.add(const Duration(seconds: 2));
        final r = await fetchWithPhoneAt(phoneNow);
        expect(r.expiresAt, serverExpiry.toLocal());
      });

      test('without a Date header the server times are used', () async {
        http.body = {
          'items': [_item()],
        };
        final r = (await repo.pending()).items.single;
        expect(r.expiresAt, serverExpiry.toLocal());
      });
    });
  });

  group('approve', () {
    const decision = ApprovalDecision(
      room: Room(id: 'r-1', code: 'AVR', name: 'Audio-Visual Room'),
      classLength: Duration(minutes: 150),
    );

    test('posts the room and class length in minutes', () async {
      http.body = {'sessionId': 's-1', 'decision': 'APPROVED'};
      await repo.approve('s-1', decision);

      expect(http.lastRequest!.method, 'POST');
      expect(http.lastRequest!.path, '/approvals/s-1/approve');
      expect(http.lastRequest!.data, {
        'destinationRoomId': 'r-1',
        'classLengthMinutes': 150,
      });
    });

    test('expired, already decided or unknown requests are gone', () async {
      for (final (status, code, message) in [
        (
          409,
          'APPROVAL_EXPIRED',
          'This request timed out and the borrow was denied.',
        ),
        (409, 'APPROVAL_ALREADY_DECIDED', 'This request was already decided.'),
        (404, 'APPROVAL_NOT_FOUND', 'This request is no longer available.'),
      ]) {
        http
          ..statusCode = status
          ..body = _problem(status, code, 'server text');
        await expectLater(
          repo.approve('s-1', decision),
          throwsA(
            isA<ApprovalFailure>()
                .having((f) => f.code, 'code', code)
                .having((f) => f.requestGone, 'requestGone', isTrue)
                .having((f) => f.message, 'message', message),
          ),
        );
      }
    });

    test('frozen shows the server message and keeps the request', () async {
      http
        ..statusCode = 409
        ..body = _problem(
          409,
          'INSTRUCTOR_FROZEN',
          'Your approval rights are frozen.',
        );
      await expectLater(
        repo.approve('s-1', decision),
        throwsA(
          isA<ApprovalFailure>()
              .having((f) => f.requestGone, 'requestGone', isFalse)
              .having(
                (f) => f.message,
                'message',
                'Your approval rights are frozen.',
              ),
        ),
      );
    });

    test('validation errors show the first field message', () async {
      http
        ..statusCode = 400
        ..body = {
          'status': 400,
          'code': 'VALIDATION_FAILED',
          'errors': {
            'destinationRoomId': [
              'Required: an active room that is not the counter.',
            ],
          },
        };
      await expectLater(
        repo.approve('s-1', decision),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Required: an active room that is not the counter.',
          ),
        ),
      );
    });
  });

  group('decline', () {
    test('posts to decline', () async {
      http.body = {'sessionId': 's-1', 'decision': 'DECLINED'};
      await repo.decline('s-1');
      expect(http.lastRequest!.method, 'POST');
      expect(http.lastRequest!.path, '/approvals/s-1/decline');
    });

    test('other errors use the generic mapping', () async {
      http.error = DioExceptionType.connectionTimeout;
      await expectLater(
        repo.decline('s-1'),
        throwsA(
          isA<Failure>().having(
            (f) => f.message,
            'message',
            'Connection timed out. Please try again.',
          ),
        ),
      );
    });
  });
}
