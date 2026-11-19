import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
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
