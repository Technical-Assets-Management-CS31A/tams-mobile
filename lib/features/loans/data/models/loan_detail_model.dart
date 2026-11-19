import '../../domain/entities/loan_detail.dart';

/// Parses the body of `GET /loans/{id}` (tams-backend
/// `LoanEndpoints.DetailAsync`):
///
/// ```json
/// {"loan": {"id", "loanNo", "status", "custodyState",
///           "asset": {"assetCode", "name"},
///           "student": {"studentNo", "fullName", "sectionCode"},
///           "event": {"title"}, "borrower": {"name"},
///           "destinationRoom": {"code", "name"},
///           "checkedOutAt", "transitDeadlineAt", "verifiedAt", "dueAt",
///           "overdueAt", "missingAt", "returnedAt",
///           "photoUrl": "/api/loans/{id}/photo", "lateArrivalWarningNo"},
///  "approval": {...},
///  "ledger": [{"event": "CHECKED_OUT", "occurredAt"}]}
/// ```
///
/// Relative photo URLs are resolved against [baseUrl]. Throws
/// [FormatException] if the body doesn't have that shape.
LoanDetail parseLoanDetail(Object? body, {required String baseUrl}) {
  if (body is! Map || body['loan'] is! Map) {
    throw const FormatException('Loan response has no "loan".');
  }
  final loan = body['loan'] as Map;
  final asset = _map(loan['asset']);
  final student = _map(loan['student']);
  final room = _map(loan['destinationRoom']);
  final photo = _string(loan['photoUrl']);
  final ledger = body['ledger'];

  return LoanDetail(
    id: _required(loan['id'], 'id'),
    loanNo: _required(loan['loanNo'], 'loanNo'),
    status: _required(loan['status'], 'status'),
    custodyState: _string(loan['custodyState']),
    assetName: _string(asset['name']) ?? '',
    assetCode: _string(asset['assetCode']) ?? '',
    studentName: _string(student['fullName']),
    studentNo: _string(student['studentNo']),
    sectionCode: _string(student['sectionCode']),
    eventTitle: _string(_map(loan['event'])['title']),
    borrowerName: _string(_map(loan['borrower'])['name']),
    roomCode: _string(room['code']),
    roomName: _string(room['name']),
    checkedOutAt:
        _date(loan['checkedOutAt']) ??
        (throw const FormatException('Loan has no "checkedOutAt".')),
    transitDeadlineAt: _date(loan['transitDeadlineAt']),
    verifiedAt: _date(loan['verifiedAt']),
    dueAt: _date(loan['dueAt']),
    overdueAt: _date(loan['overdueAt']),
    missingAt: _date(loan['missingAt']),
    returnedAt: _date(loan['returnedAt']),
    photoUrl: photo == null
        ? null
        : Uri.parse(baseUrl).resolve(photo).toString(),
    lateArrivalWarningNo: loan['lateArrivalWarningNo'] is num
        ? (loan['lateArrivalWarningNo'] as num).toInt()
        : null,
    ledger: [
      if (ledger is List)
        for (final e in ledger)
          if (e is Map && _string(e['event']) != null)
            if (_date(e['occurredAt']) case final at?)
              LedgerEntry(event: e['event'] as String, occurredAt: at),
    ],
  );
}

Map _map(Object? value) => value is Map ? value : const {};

String _required(Object? value, String field) =>
    _string(value) ?? (throw FormatException('Loan has no "$field".'));

String? _string(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
