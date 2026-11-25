class AuditRoom {
  const AuditRoom({
    required this.id,
    required this.code,
    required this.name,
    this.building = '',
    this.floor,
    this.isStorage = false,
    this.status = '',
  });

  final String id;
  final String code;
  final String name;
  final String building;
  final int? floor;
  final bool isStorage;
  final String status;

  String get label => name.isEmpty || name == code ? code : '$code · $name';

  String get place => [
    if (building.isNotEmpty) building,
    if (floor case final floor?) 'Floor $floor',
    if (isStorage) 'Storage',
  ].join(' · ');
}

class RoomsPage {
  const RoomsPage({
    required this.items,
    required this.page,
    required this.total,
  });

  final List<AuditRoom> items;
  final int page;
  final int total;
}
