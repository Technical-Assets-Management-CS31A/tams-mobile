import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tams_mobile/features/audit/data/local/audit_database.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_room.dart';
import 'package:tams_mobile/features/audit/domain/entities/audit_scan.dart';
import 'package:tams_mobile/features/audit/domain/entities/roster.dart';

const lab1 = AuditRoom(
  id: 'room-lab1',
  code: 'CL1',
  name: 'Computer Lab 1',
  building: 'Main',
  floor: 2,
);

const storageRoom = AuditRoom(
  id: 'room-store',
  code: 'ST1',
  name: 'Storage 1',
  isStorage: true,
);

const assetA = '11111111-1111-4111-8111-111111111111';
const assetB = '22222222-2222-4222-8222-222222222222';
const assetC = '33333333-3333-4333-8333-333333333333';
const strayAsset = '99999999-9999-4999-8999-999999999999';

Roster roster({
  AuditRoom room = lab1,
  List<RosterItem>? items,
  DateTime? downloadedAt,
}) => Roster(
  room: room,
  downloadedAt: downloadedAt ?? DateTime.utc(2026, 11, 25, 1),
  items:
      items ??
      const [
        RosterItem(
          assetId: assetA,
          assetCode: 'PC-01',
          name: 'Desktop 01',
          category: 'Desktops',
          type: 'FIXED',
          status: 'IN_STORAGE',
        ),
        RosterItem(
          assetId: assetB,
          assetCode: 'PC-02',
          name: 'Desktop 02',
          category: 'Desktops',
          type: 'FIXED',
          status: 'IN_STORAGE',
        ),
        RosterItem(
          assetId: assetC,
          assetCode: 'LPT-01',
          name: 'Laptop 01',
          category: 'Laptops',
          type: 'BORROWABLE',
          status: 'IN_TRANSIT',
        ),
      ],
);

LocalAudit openAudit({
  String localId = 'local-1',
  String userId = 'user-1',
  String roomId = 'room-lab1',
  String? serverId,
  DateTime? startedAt,
}) => LocalAudit(
  localId: localId,
  serverId: serverId,
  userId: userId,
  roomId: roomId,
  status: AuditStatus.inProgress,
  startedAt: startedAt ?? DateTime.utc(2026, 11, 25, 2),
);

AuditScan scan(
  String clientScanId, {
  String localAuditId = 'local-1',
  String value = 'tams:asset:$assetA',
  String? key,
  ScanResult result = ScanResult.matched,
  String? assetId = assetA,
  DateTime? at,
}) => AuditScan(
  clientScanId: clientScanId,
  localAuditId: localAuditId,
  scannedValue: value,
  scanKey: key ?? assetId ?? value,
  scannedAt: at ?? DateTime.utc(2026, 11, 25, 2, 5),
  localResult: result,
  assetId: assetId,
);

Future<AuditDatabase> memoryAuditDatabase() async {
  sqfliteFfiInit();
  return AuditDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
  );
}
