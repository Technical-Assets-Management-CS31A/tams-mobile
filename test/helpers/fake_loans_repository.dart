import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/loans/domain/entities/loan_detail.dart';
import 'package:tams_mobile/features/loans/domain/repositories/loans_repository.dart';

/// In-memory Loans API: [loans] are my open loans. Set [error] to make the
/// next calls fail.
class FakeLoansRepository implements LoansRepository {
  FakeLoansRepository([List<LoanDetail>? loans]) : loans = [...?loans];

  List<LoanDetail> loans;
  Object? error;
  int listCalls = 0;

  @override
  Future<LoansPage> myOpenLoans() async {
    listCalls++;
    if (error case final e?) throw e;
    return LoansPage(items: [...loans], total: loans.length);
  }

  @override
  Future<LoanDetail> detail(String id) async {
    if (error case final e?) throw e;
    return loans.firstWhere(
      (l) => l.id == id,
      orElse: () => throw const Failure('This loan is no longer available.'),
    );
  }
}

/// An open loan of [assetName], due at [dueAt].
LoanDetail openLoan(
  String id, {
  required DateTime dueAt,
  String status = 'ACTIVE',
  String? custodyState = 'VERIFIED',
  String? assetStatus = 'IN_ROOM_VERIFIED',
  String assetName = 'Epson Projector',
  DateTime? transitDeadlineAt,
  int graceMinutes = 15,
}) => LoanDetail(
  id: id,
  loanNo: 'L-$id',
  status: status,
  custodyState: custodyState,
  assetStatus: assetStatus,
  assetName: assetName,
  assetCode: 'PRJ-$id',
  studentName: 'Maria Santos',
  sectionCode: 'BSCS-3A',
  roomCode: 'CL1',
  roomName: 'Computer Lab 1',
  checkedOutAt: dueAt.subtract(const Duration(hours: 2)),
  transitDeadlineAt: transitDeadlineAt,
  classEndsAt: dueAt.subtract(Duration(minutes: graceMinutes)),
  graceMinutes: graceMinutes,
  dueAt: dueAt,
);
