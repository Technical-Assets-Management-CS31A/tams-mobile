import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/features/approvals/presentation/widgets/approval_card.dart';
import 'package:tams_mobile/features/approvals/presentation/widgets/student_avatar.dart';

void main() {
  test('class length options run from 1.5 h to 3 h in 30 min steps', () {
    expect(classLengthOptions.map(formatClassLength), [
      '1.5 h',
      '2 h',
      '2.5 h',
      '3 h',
    ]);
  });

  test('initials', () {
    expect(initials('Maria Santos'), 'MS');
    expect(initials('  john   dela cruz '), 'JC');
    expect(initials('Cher'), 'C');
    expect(initials(''), '?');
  });

  test('timeAgo', () {
    final now = DateTime(2026, 11, 16, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 30)), now), 'Just now');
    expect(timeAgo(now.subtract(const Duration(minutes: 4)), now), '4 min ago');
    expect(timeAgo(now.subtract(const Duration(minutes: 65)), now), '1 h ago');
    expect(timeAgo(now.subtract(const Duration(days: 2)), now), '2 d ago');
  });

  group('ApprovalsController', () {
    late ProviderContainer container;
    ApprovalsController controller() =>
        container.read(approvalsControllerProvider.notifier);
    List<String> ids() => [
      for (final r in container.read(approvalsControllerProvider)) r.id,
    ];

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('starts with the mock requests', () {
      expect(ids(), ['req-1001', 'req-1002', 'req-1003']);
    });

    test('approve and reject remove the request', () {
      controller().approve(
        'req-1002',
        const ApprovalDecision(room: 'AVR', classLength: Duration(hours: 2)),
      );
      expect(ids(), ['req-1001', 'req-1003']);

      controller().reject('req-1001');
      expect(ids(), ['req-1003']);
    });

    test('restore puts a rejected request back where it was, once', () {
      final request = container.read(approvalsControllerProvider)[1];
      controller().reject(request.id);
      controller().restore(request, 1);
      controller().restore(request, 1);
      expect(ids(), ['req-1001', 'req-1002', 'req-1003']);
    });
  });
}
