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
/// Invalidate it to reload; the list stays on screen meanwhile. Empty while
/// signed out, so one user never sees another's loans; a Riverpod-paused
/// copy (My Loans on a hidden tab) is read at sign-out for that (see `App`).
final myLoansProvider = FutureProvider<LoansPage>((ref) {
  final repo = ref.watch(loansRepositoryProvider);
  // Signed in or not, not the token itself: a renewed token mustn't
  // reload. Not async, so a sign-out empties the list at once.
  if (!ref.watch(authTokenProvider.select((t) => t != null))) {
    return LoansPage.empty;
  }
  return repo.myOpenLoans();
});
