import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/domain/repositories/approvals_repository.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/features/approvals/presentation/widgets/approval_card.dart';
import 'package:tams_mobile/features/approvals/presentation/widgets/student_avatar.dart';

import '../../helpers/fake_approvals_repository.dart';

void main() {
  test('standard class lengths run from 1.5 h to 3 h in 30 min steps', () {
    expect(standardClassLengths.map(formatClassLength), [
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

  test('timeLeft', () {
    expect(timeLeft(const Duration(seconds: 102)), '1:42 left');
    expect(timeLeft(const Duration(seconds: 5)), '0:05 left');
    expect(timeLeft(Duration.zero), 'Expired');
    expect(timeLeft(const Duration(seconds: -3)), 'Expired');
  });

  test('room label', () {
    expect(room301.label, 'Room 301 (RM301)');
    expect(const Room(id: 'x', code: 'AVR', name: 'AVR').label, 'AVR');
  });

  test('defaultRoom is only one of the options', () {
    expect(approval('a').defaultRoom, room301);
    expect(approval('a', defaultRoomId: 'elsewhere').defaultRoom, isNull);
    expect(approval('a', defaultRoomId: null).defaultRoom, isNull);
  });

  group('ApprovalsController', () {
    late FakeApprovalsRepository repo;
    late ProviderContainer container;
    ApprovalsController controller() =>
        container.read(approvalsControllerProvider.notifier);
    Future<List<String>> ids() async => [
      for (final r in (await container.read(
        approvalsControllerProvider.future,
      )).items)
        r.id,
    ];
    const decision = ApprovalDecision(
      room: avr,
      classLength: Duration(hours: 2),
    );

    setUp(() {
      repo = FakeApprovalsRepository([
        approval('a'),
        approval('b'),
        approval('c'),
      ]);
      container = ProviderContainer(
        overrides: [approvalsRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
    });

    test('loads the pending requests from the repository', () async {
      expect(await ids(), ['a', 'b', 'c']);
      expect(repo.pendingCalls, 1);
    });

    test('approve sends the decision and removes the request', () async {
      await ids();
      await controller().approve('b', decision);
      expect(repo.approved, [('b', decision)]);
      expect(await ids(), ['a', 'c']);
    });

    test('decline sends it and removes the request', () async {
      await ids();
      await controller().decline('a');
      expect(repo.declined, ['a']);
      expect(await ids(), ['b', 'c']);
    });

    test('a refused decision keeps the request and rethrows', () async {
      await ids();
      repo.decisionError = const ApprovalFailure(
        'Frozen',
        code: 'INSTRUCTOR_FROZEN',
      );
      await expectLater(
        controller().approve('a', decision),
        throwsA(isA<Failure>()),
      );
      expect(await ids(), ['a', 'b', 'c']);
    });

    test('an expired request leaves the list and rethrows', () async {
      await ids();
      repo.decisionError = const ApprovalFailure(
        'Timed out',
        code: 'APPROVAL_EXPIRED',
        requestGone: true,
      );
      await expectLater(
        controller().decline('b'),
        throwsA(isA<ApprovalFailure>()),
      );
      expect(await ids(), ['a', 'c']);
    });

    test('refresh reloads, and load errors end up in the state', () async {
      await ids();
      repo
        ..result = PendingApprovals(items: [approval('d')])
        ..pendingError = null;
      await controller().refresh();
      expect(await ids(), ['d']);

      repo.pendingError = const Failure('Offline');
      await controller().refresh();
      expect(container.read(approvalsControllerProvider).error, isA<Failure>());
    });
  });
}
