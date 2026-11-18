import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/pending_approval.dart';
import '../../domain/repositories/approvals_repository.dart';
import '../datasources/approvals_remote_datasource.dart';

class ApprovalsRepositoryImpl implements ApprovalsRepository {
  const ApprovalsRepositoryImpl(this._remote);

  final ApprovalsRemoteDataSource _remote;

  @override
  Future<PendingApprovals> pending() async {
    try {
      return await _remote.pending();
    } on DioException catch (e) {
      throw Failure.fromDio(e);
    } on FormatException {
      throw const Failure('Unexpected response from the server.');
    }
  }

  @override
  Future<void> approve(String id, ApprovalDecision decision) =>
      _decide(() => _remote.approve(id, decision));

  @override
  Future<void> decline(String id) => _decide(() => _remote.decline(id));

  Future<void> _decide(Future<void> Function() call) async {
    try {
      await call();
    } on DioException catch (e) {
      throw _decisionFailure(e);
    }
  }

  /// Error codes from `ApprovalEndpoints` (tams-backend).
  static Failure _decisionFailure(DioException e) {
    final code = Failure.errorCode(e);
    switch (code) {
      case ApprovalFailure.expired:
        return ApprovalFailure(
          'This request timed out and the borrow was denied.',
          code: code,
          requestGone: true,
        );
      case 'APPROVAL_ALREADY_DECIDED':
        return ApprovalFailure(
          'This request was already decided.',
          code: code,
          requestGone: true,
        );
      case 'APPROVAL_NOT_FOUND':
        return ApprovalFailure(
          'This request is no longer available.',
          code: code,
          requestGone: true,
        );
      case 'INSTRUCTOR_FROZEN':
        return ApprovalFailure(
          Failure.serverMessage(e) ??
              'Your approval rights are frozen until staff lift the freeze.',
          code: code,
        );
      case 'VALIDATION_FAILED':
        return ApprovalFailure(
          _firstFieldError(e) ?? 'Check the room and class length.',
          code: code,
        );
    }
    return Failure.fromDio(e);
  }

  /// First message of a validation problem's `errors` map, e.g.
  /// `{"destinationRoomId": ["Required: an active room ..."]}`.
  static String? _firstFieldError(DioException e) {
    final data = e.response?.data;
    final errors = data is Map ? data['errors'] : null;
    if (errors is! Map) return null;
    for (final messages in errors.values) {
      if (messages is List && messages.isNotEmpty && messages.first is String) {
        return messages.first as String;
      }
    }
    return null;
  }
}
