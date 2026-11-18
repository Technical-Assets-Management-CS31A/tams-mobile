import 'package:dio/dio.dart';

import '../../../../core/utils/clock.dart';
import '../../../../core/utils/http_date.dart';
import '../../domain/entities/pending_approval.dart';
import '../models/pending_approvals_model.dart';

/// The Approvals API (PRD 6.3, tams-backend `ApprovalEndpoints`).
class ApprovalsRemoteDataSource {
  const ApprovalsRemoteDataSource(this._dio, {this._now = DateTime.now});

  final Dio _dio;
  final Clock _now;

  /// Smaller differences between the server's and the phone's clock are
  /// ignored: the `Date` header only has whole seconds, plus network delay.
  static const clockSkewTolerance = Duration(seconds: 3);

  /// Pending requests with their times on the phone's clock, so the
  /// 120 s countdown is right even when the phone's clock is off.
  Future<PendingApprovals> pending() async {
    final res = await _dio.get<Object?>('/approvals/pending');
    final approvals = parsePendingApprovals(
      res.data,
      baseUrl: _dio.options.baseUrl,
    );
    return approvals.shifted(_clockOffset(res.headers.value('date')));
  }

  /// How far ahead the phone's clock is of the server's.
  Duration _clockOffset(String? dateHeader) {
    final server = parseHttpDate(dateHeader);
    if (server == null) return Duration.zero;
    final offset = _now().difference(server);
    return offset.abs() < clockSkewTolerance ? Duration.zero : offset;
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
