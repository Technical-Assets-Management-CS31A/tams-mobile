import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/features/alerts/domain/entities/alert.dart';
import 'package:tams_mobile/features/alerts/domain/repositories/alerts_repository.dart';

/// An alert about Maria Santos's projector loan, created [ago] before now.
Alert alert(
  String id, {
  String type = 'LATE_ARRIVAL_WARNING',
  String title = 'Item not checked in at the room',
  String body = 'Maria Santos (BSCS-3A), PRJ-0012 was not tapped in time.',
  Duration ago = const Duration(minutes: 5),
  DateTime? createdAt,
  bool read = false,
  String? loanId = 'loan-1',
  String? studentName = 'Maria Santos',
  String? sectionCode = 'BSCS-3A',
  int? warningNo,
  bool penaltyTriggered = false,
}) {
  final created = createdAt ?? DateTime.now().subtract(ago);
  return Alert(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: created,
    readAt: read ? created.add(const Duration(minutes: 1)) : null,
    loanId: loanId,
    loanNo: 'L-0001',
    studentName: studentName,
    sectionCode: sectionCode,
    assetCode: 'PRJ-0012',
    warningNo: warningNo,
    penaltyTriggered: penaltyTriggered,
  );
}

/// In-memory [AlertsRepository] serving [alerts] in pages of [pageSize].
class FakeAlertsRepository implements AlertsRepository {
  FakeAlertsRepository([this.alerts = const [], this.pageSize = 25]);

  List<Alert> alerts;
  final int pageSize;

  /// Thrown by [list] when set.
  Object? listError;

  /// Thrown by [markRead] when set.
  Object? markReadError;

  final listedPages = <int>[];
  final markedRead = <String>[];

  @override
  Future<AlertsPage> list({int page = 1}) async {
    listedPages.add(page);
    if (listError case final e?) throw e;
    final sorted = [...alerts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return AlertsPage(
      items: sorted.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      total: sorted.length,
      unreadCount: sorted.where((a) => a.isUnread).length,
    );
  }

  @override
  Future<void> markRead(String id) async {
    if (markReadError case final e?) throw e;
    markedRead.add(id);
  }
}

/// A signed-in session, so screens that need a token load their data.
class SignedInToken extends TokenNotifier {
  @override
  String? build() => 'test-token';
}
