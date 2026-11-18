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
