import 'package:dio/dio.dart';

import '../../domain/entities/pending_approval.dart';
import '../models/pending_approvals_model.dart';

/// The Approvals API (PRD 6.3, tams-backend `ApprovalEndpoints`).
class ApprovalsRemoteDataSource {
  const ApprovalsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PendingApprovals> pending() async {
    final res = await _dio.get<Object?>('/approvals/pending');
    return parsePendingApprovals(res.data, baseUrl: _dio.options.baseUrl);
  }

  Future<void> approve(String id, ApprovalDecision decision) =>
      _dio.post<Object?>(
        '/approvals/${Uri.encodeComponent(id)}/approve',
        data: {
          'destinationRoomId': decision.room.id,
          'classLengthMinutes': decision.classLength.inMinutes,
        },
      );

  Future<void> decline(String id) =>
      _dio.post<Object?>('/approvals/${Uri.encodeComponent(id)}/decline');
}
