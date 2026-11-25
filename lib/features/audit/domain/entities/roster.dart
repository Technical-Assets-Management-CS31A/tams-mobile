import 'audit_room.dart';

const _onLoanStatuses = {
  'AT_COUNTER',
  'IN_TRANSIT',
  'IN_ROOM_VERIFIED',
  'LOCATION_ANOMALY',
  'OVERDUE',
};

class RosterItem {
  const RosterItem({
    required this.assetId,
    required this.assetCode,
    required this.name,
    this.category = '',
    this.type = '',
    this.status = '',
  });

  final String assetId;
  final String assetCode;
  final String name;
  final String category;
  final String type;
  final String status;

  bool get isOnLoan => _onLoanStatuses.contains(status);
}

class Roster {
  const Roster({
    required this.room,
    required this.items,
    required this.downloadedAt,
  });

  final AuditRoom room;
  final List<RosterItem> items;
  final DateTime downloadedAt;

  RosterItem? item(String assetId) {
    for (final i in items) {
      if (i.assetId == assetId) return i;
    }
    return null;
  }
}

class RosterInfo {
  const RosterInfo({required this.itemCount, required this.downloadedAt});

  final int itemCount;
  final DateTime downloadedAt;
}
