import 'package:dio/dio.dart';

import '../../domain/entities/alert.dart';
import '../models/alerts_page_model.dart';

/// The Notifications API (PRD 6.3, tams-backend `NotificationEndpoints`).
class AlertsRemoteDataSource {
  const AlertsRemoteDataSource(this._dio);

  final Dio _dio;

  static const pageSize = 25;

  Future<AlertsPage> list({int page = 1}) async {
    final res = await _dio.get<Object?>(
      '/notifications',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return parseAlertsPage(res.data);
  }

  Future<void> markRead(String id) =>
      _dio.post<Object?>('/notifications/${Uri.encodeComponent(id)}/read');
}
