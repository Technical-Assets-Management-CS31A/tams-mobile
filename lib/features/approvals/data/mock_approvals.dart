import '../domain/entities/pending_approval.dart';

// Mock data until the approvals API is ready.
// TODO: replace with a repository backed by the API.

/// Rooms an item can be approved for.
const mockRooms = [
  'Room 301',
  'Room 302',
  'Room 303',
  'Computer Lab 1',
  'Computer Lab 2',
  'AVR',
];

List<PendingApproval> mockPendingApprovals(DateTime now) => [
  PendingApproval(
    id: 'req-1001',
    studentName: 'Maria Santos',
    studentNumber: '2023-00142',
    photoUrl: 'https://i.pravatar.cc/150?img=47',
    itemName: 'Epson Projector EB-X51',
    assetTag: 'PRJ-0012',
    requestedAt: now.subtract(const Duration(minutes: 4)),
  ),
  PendingApproval(
    id: 'req-1002',
    studentName: 'John Dela Cruz',
    studentNumber: '2022-00871',
    photoUrl: 'https://i.pravatar.cc/150?img=12',
    itemName: 'HDMI Cable (5 m)',
    assetTag: 'CBL-0230',
    requestedAt: now.subtract(const Duration(minutes: 18)),
  ),
  PendingApproval(
    id: 'req-1003',
    studentName: 'Angela Reyes',
    studentNumber: '2024-00309',
    // No photo uploaded: shows initials.
    itemName: 'Logitech Wireless Presenter',
    assetTag: 'PRS-0007',
    requestedAt: now.subtract(const Duration(hours: 1, minutes: 5)),
  ),
];
