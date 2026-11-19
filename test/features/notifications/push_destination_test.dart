import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/notifications/domain/push_destination.dart';

void main() {
  test('approval requests open Pending Approvals', () {
    expect(locationForPush({'type': 'approval.requested'}), '/approvals');
  });

  test('loan and freeze events open My Loans', () {
    for (final type in [
      'loan.created',
      'instructor.frozen',
      'instructor.unfrozen',
    ]) {
      expect(locationForPush({'type': type}), '/loans', reason: type);
    }
  });

  test('warnings, anomalies and overdue notices open Alerts', () {
    for (final type in [
      'anomaly.raised',
      'anomaly.resolved',
      'warning.issued',
      'loan.overdue',
      'LATE_ARRIVAL_WARNING',
      'LOAN_OVERDUE',
    ]) {
      expect(locationForPush({'type': type}), '/alerts', reason: type);
    }
  });

  group('notice pushes (tams-backend NoticePush)', () {
    Map<String, dynamic> notice({Object? payload}) => {
      'type': 'notice',
      'notificationId': 'n-1',
      'noticeType': 'LOAN_OVERDUE',
      'payload': ?payload,
    };

    test('a notice about a loan opens that loan from Alerts', () {
      final data = notice(
        payload:
            '{"type":"notice","loanId":"loan-7","noticeType":"LOAN_OVERDUE"}',
      );
      expect(locationForPush(data), '/alerts/loans/loan-7');
      expect(noticeId(data), 'n-1');
      expect(isAlertPush(data), isTrue);
    });

    test('a notice without a loan opens Alerts', () {
      expect(locationForPush(notice()), '/alerts');
      expect(locationForPush(notice(payload: '{"loanId":null}')), '/alerts');
      expect(locationForPush(notice(payload: 'not json')), '/alerts');
    });

    test('only notices carry a notification to mark read', () {
      expect(
        noticeId({'type': 'approval.requested', 'notificationId': 'x'}),
        isNull,
      );
      expect(isAlertPush({'type': 'approval.requested'}), isFalse);
    });
  });

  test('every destination is a shell tab', () {
    expect(
      pushDestinations.values.toSet(),
      everyElement(isIn(['/approvals', '/loans', '/alerts', '/audit'])),
    );
  });

  test('missing, unknown or non-string types open nothing', () {
    expect(locationForPush({}), isNull);
    expect(locationForPush({'type': 'station.healthChanged'}), isNull);
    expect(locationForPush({'type': 42}), isNull);
  });
}
