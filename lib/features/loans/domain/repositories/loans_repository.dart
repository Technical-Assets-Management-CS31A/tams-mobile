import '../entities/loan_detail.dart';

abstract interface class LoansRepository {
  /// The open (ACTIVE or OVERDUE) loans I approved or coordinate, soonest
  /// due first (FR-2.5).
  Future<LoansPage> myOpenLoans();

  /// Loan [id], if I approved it (or staff).
  Future<LoanDetail> detail(String id);
}
