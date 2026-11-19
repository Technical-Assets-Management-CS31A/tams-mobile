import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/domain/repositories/approvals_repository.dart';

const room301 = Room(id: 'r-301', code: 'RM301', name: 'Room 301');
const avr = Room(id: 'r-avr', code: 'AVR', name: 'Audio-Visual Room');

/// A request without a photo, so tests never touch the network.
PendingApproval approval(
  String id, {
  String studentName = 'Maria Santos',
  String itemName = 'Epson Projector',
  String assetCode = 'PRJ-0012',
  List<ApprovalItem>? items,
  DateTime? requestedAt,
  DateTime? expiresAt,
  String? defaultRoomId = 'r-301',
  Duration defaultClassLength = const Duration(minutes: 90),
}) => PendingApproval(
  id: id,
  studentName: studentName,
  studentNumber: '2023-00142',
  sectionCode: 'BSCS-3A',
  items: items ?? [ApprovalItem(name: itemName, assetCode: assetCode)],
  requestedAt:
      requestedAt ?? DateTime.now().subtract(const Duration(seconds: 10)),
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(seconds: 110)),
  roomOptions: const [room301, avr],
  defaultRoomId: defaultRoomId,
  defaultClassLength: defaultClassLength,
);

/// A clock that only moves when told to, for driving countdowns.
class FakeClock {
  FakeClock([DateTime? start]) : current = start ?? DateTime.now();

  DateTime current;

  DateTime call() => current;

  void advance(Duration by) => current = current.add(by);
}

/// In-memory [ApprovalsRepository] that records the calls made to it.
class FakeApprovalsRepository implements ApprovalsRepository {
  FakeApprovalsRepository([List<PendingApproval> items = const []])
    : result = PendingApprovals(items: items);

  PendingApprovals result;

  /// Thrown by [pending] when set.
  Object? pendingError;

  /// Thrown by [approve] / [decline] when set.
  Object? decisionError;

  /// Runs while [approve] / [decline] wait for the "server", e.g. to let
  /// time pass during the call.
  void Function()? whileDeciding;

  int pendingCalls = 0;
  final approved = <(String, ApprovalDecision)>[];
  final declined = <String>[];

  @override
  Future<PendingApprovals> pending() async {
    pendingCalls++;
    if (pendingError case final e?) throw e;
    return result;
  }

  @override
  Future<void> approve(String id, ApprovalDecision decision) async {
    whileDeciding?.call();
    if (decisionError case final e?) throw e;
    approved.add((id, decision));
  }

  @override
  Future<void> decline(String id) async {
    whileDeciding?.call();
    if (decisionError case final e?) throw e;
    declined.add(id);
  }
}
