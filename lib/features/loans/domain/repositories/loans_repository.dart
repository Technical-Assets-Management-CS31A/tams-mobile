import '../entities/loan_detail.dart';

abstract interface class LoansRepository {
  /// Loan [id], if I approved it (or staff).
  Future<LoanDetail> detail(String id);
}
