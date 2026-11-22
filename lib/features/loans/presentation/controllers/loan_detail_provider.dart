import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/network/token_provider.dart';
import '../../data/repositories/loans_repository_impl.dart';
import '../../domain/entities/loan_detail.dart';
import '../../domain/repositories/loans_repository.dart';

final loansRepositoryProvider = Provider<LoansRepository>(
  (ref) => LoansRepositoryImpl(ref.watch(dioProvider)),
);

/// Loan [id] from `GET /loans/{id}`. Dropped when its screen closes, so
/// opening it again shows the latest status.
final loanDetailProvider = FutureProvider.autoDispose
    .family<LoanDetail, String>(
      (ref, id) => ref.watch(loansRepositoryProvider).detail(id),
    );

/// My Loans (FR-2.5): the open loans I approved, soonest due first.
/// Invalidate it to reload; the list stays on screen meanwhile. Rebuilt on
/// sign-in and sign-out, so one user never sees another's loans.
final myLoansProvider = FutureProvider<LoansPage>((ref) async {
  final repo = ref.watch(loansRepositoryProvider);
  if (ref.watch(authTokenProvider) == null) return LoansPage.empty;
  return repo.myOpenLoans();
});
