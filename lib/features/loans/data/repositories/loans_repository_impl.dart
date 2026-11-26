import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/loan_detail.dart';
import '../../domain/repositories/loans_repository.dart';
import '../models/loan_detail_model.dart';

/// The Loans API (PRD 6.3, tams-backend `LoanEndpoints`).
class LoansRepositoryImpl implements LoansRepository {
  const LoansRepositoryImpl(this._dio);

  final Dio _dio;

  /// An instructor's open loans are one or two classes' worth, so one
  /// page of the most the API serves covers them.
  static const pageSize = 100;

  @override
  Future<LoansPage> myOpenLoans() async {
    try {
      final res = await _dio.get<Object?>(
        '/loans',
        queryParameters: {
          'approvedBy': 'me',
          'status': 'open',
          'sort': 'dueAt',
          'pageSize': pageSize,
        },
      );
      return parseLoansPage(res.data, baseUrl: _dio.options.baseUrl);
    } on DioException catch (e) {
      throw Failure.fromDio(e);
    } on FormatException {
      throw const Failure('Unexpected response from the server.');
    }
  }

  /// Loan History pages: small enough to load quickly, with "Load more".
  static const historyPageSize = 25;

  @override
  Future<LoansPage> myLoanHistory({
    LoanHistoryFilter filter = LoanHistoryFilter.all,
    int page = 1,
  }) async {
    try {
      final res = await _dio.get<Object?>(
        '/loans',
        queryParameters: {
          'approvedBy': 'me',
          'status': ?filter.status,
          'sort': '-checkedOutAt',
          'page': page,
          'pageSize': historyPageSize,
        },
      );
      final parsed = parseLoansPage(res.data, baseUrl: _dio.options.baseUrl);
      return LoansPage(items: parsed.items, total: parsed.total, page: page);
    } on DioException catch (e) {
      throw Failure.fromDio(e);
    } on FormatException {
      throw const Failure('Unexpected response from the server.');
    }
  }

  @override
  Future<LoanDetail> detail(String id) async {
    try {
      final res = await _dio.get<Object?>('/loans/${Uri.encodeComponent(id)}');
      return parseLoanDetail(res.data, baseUrl: _dio.options.baseUrl);
    } on DioException catch (e) {
      // An instructor only sees loans they approved; anything else is 404.
      if (Failure.errorCode(e) == 'LOAN_NOT_FOUND') {
        throw const Failure('This loan is no longer available.');
      }
      throw Failure.fromDio(e);
    } on FormatException {
      throw const Failure('Unexpected response from the server.');
    }
  }
}
