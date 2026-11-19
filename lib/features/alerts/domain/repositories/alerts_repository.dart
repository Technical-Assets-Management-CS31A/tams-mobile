import '../entities/alert.dart';

abstract interface class AlertsRepository {
  /// Page [page] (from 1) of my notifications, newest first.
  Future<AlertsPage> list({int page = 1});

  /// Marks notification [id] read. Reading one twice is fine.
  Future<void> markRead(String id);
}
