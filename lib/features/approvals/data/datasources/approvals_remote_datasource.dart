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

  /// A phone clock found to be ahead by less than this is treated as
  /// right. That only makes the countdown end a little early, never late,
  /// and keeps it from jumping around between reloads.
  static const clockSkewTolerance = Duration(seconds: 3);

  /// Pending requests with their times on the phone's clock, so the
  /// 120 s countdown is right even when the phone's clock is off.
  ///
  /// The server's time comes from the `Date` response header; without it
  /// the phone's clock is used as is.
  Future<PendingApprovals> pending() async {
    final sentAt = _now();
    final res = await _dio.get<Object?>('/approvals/pending');
    final approvals = parsePendingApprovals(
      res.data,
      baseUrl: _dio.options.baseUrl,
    );
    return approvals.shifted(_clockOffset(res.headers.value('date'), sentAt));
  }

  /// How far ahead the phone's clock is of the server's, erring low so the
  /// phone never shows more time than the server allows.
  ///
  /// The server stamped `Date` somewhere between [sentAt] and now on the
  /// phone's clock, and `Date` is rounded down to the second. So the
  /// smallest offset that fits is [sentAt] minus (`Date` + 1 s).
  Duration _clockOffset(String? dateHeader, DateTime sentAt) {
    final server = parseHttpDate(dateHeader);
    if (server == null) return Duration.zero;
    final offset = sentAt.difference(server.add(const Duration(seconds: 1)));
    return offset >= Duration.zero && offset < clockSkewTolerance
        ? Duration.zero
        : offset;
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
