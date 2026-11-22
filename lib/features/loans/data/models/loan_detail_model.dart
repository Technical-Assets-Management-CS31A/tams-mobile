import '../../domain/entities/loan_detail.dart';

/// Parses the body of `GET /loans/{id}` (tams-backend
/// `LoanEndpoints.DetailAsync`):
///
/// ```json
/// {"loan": {"id", "loanNo", "status", "custodyState",
///           "asset": {"assetCode", "name", "status"},
///           "student": {"studentNo", "fullName", "sectionCode"},
///           "event": {"title"}, "borrower": {"name"},
///           "destinationRoom": {"code", "name"},
///           "checkedOutAt", "transitDeadlineAt", "verifiedAt",
///           "classEndsAt", "graceMinutes", "dueAt",
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
  final ledger = body['ledger'];
  return parseLoan(
    body['loan'],
    baseUrl: baseUrl,
    ledger: [
      if (ledger is List)
        for (final e in ledger)
          if (e is Map && _string(e['event']) != null)
            if (_date(e['occurredAt']) case final at?)
              LedgerEntry(event: e['event'] as String, occurredAt: at),
    ],
  );
}

/// Parses the body of `GET /loans` (tams-backend `LoanEndpoints.List`):
/// `{"items": [loan, ...], "page", "pageSize", "total"}`, each item shaped
/// like the `loan` of [parseLoanDetail]. A malformed row is skipped rather
/// than hiding every other loan.
LoansPage parseLoansPage(Object? body, {required String baseUrl}) {
  if (body is! Map || body['items'] is! List) {
    throw const FormatException('Loans response has no "items".');
  }
  final loans = <LoanDetail>[
    for (final item in body['items'] as List)
      ?_tryParse(item, baseUrl: baseUrl),
  ];
  final total = body['total'];
  return LoansPage(
    items: loans,
    total: total is num ? total.toInt() : loans.length,
  );
}

LoanDetail? _tryParse(Object? json, {required String baseUrl}) {
  try {
    return parseLoan(json, baseUrl: baseUrl);
  } on FormatException {
    return null;
  }
}

/// One loan (`LoanEndpoints.DtosAsync`).
LoanDetail parseLoan(
  Object? json, {
  required String baseUrl,
  List<LedgerEntry> ledger = const [],
}) {
  if (json is! Map) throw const FormatException('Loan is not an object.');
  final loan = json;
  final asset = _map(loan['asset']);
  final student = _map(loan['student']);
  final room = _map(loan['destinationRoom']);
  final photo = _string(loan['photoUrl']);

  return LoanDetail(
    id: _required(loan['id'], 'id'),
    loanNo: _required(loan['loanNo'], 'loanNo'),
    status: _required(loan['status'], 'status'),
    custodyState: _string(loan['custodyState']),
    assetStatus: _string(asset['status']),
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
    classEndsAt: _date(loan['classEndsAt']),
    graceMinutes: _int(loan['graceMinutes']),
    dueAt: _date(loan['dueAt']),
    overdueAt: _date(loan['overdueAt']),
    missingAt: _date(loan['missingAt']),
    returnedAt: _date(loan['returnedAt']),
    photoUrl: photo == null
        ? null
        : Uri.parse(baseUrl).resolve(photo).toString(),
    lateArrivalWarningNo: _int(loan['lateArrivalWarningNo']),
    ledger: ledger,
  );
}

Map _map(Object? value) => value is Map ? value : const {};

String _required(Object? value, String field) =>
    _string(value) ?? (throw FormatException('Loan has no "$field".'));

String? _string(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

int? _int(Object? value) => value is num ? value.toInt() : null;

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
