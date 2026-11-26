import '../entities/loan_detail.dart';

abstract interface class LoansRepository {
  /// The open (ACTIVE or OVERDUE) loans I approved or coordinate, soonest
  /// due first (FR-2.5).
  Future<LoansPage> myOpenLoans();

  /// Page [page] (from 1) of every loan I approved or coordinate that
  /// matches [filter], newest checkout first (FR-2.5).
  Future<LoansPage> myLoanHistory({
    LoanHistoryFilter filter = LoanHistoryFilter.all,
    int page = 1,
  });

  /// Loan [id], if I approved it (or staff).
  Future<LoanDetail> detail(String id);
}
