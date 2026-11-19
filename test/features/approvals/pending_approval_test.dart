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
    expect(timeLeft(const Duration(seconds: 120)), '2:00 left');
    expect(timeLeft(const Duration(seconds: 102)), '1:42 left');
    expect(timeLeft(const Duration(seconds: 5)), '0:05 left');
    // Rounds up: never "0:00 left" while there is still time.
    expect(timeLeft(const Duration(milliseconds: 4200)), '0:05 left');
    expect(timeLeft(const Duration(milliseconds: 1)), '0:01 left');
    expect(timeLeft(Duration.zero), 'Expired');
    expect(timeLeft(const Duration(seconds: -3)), 'Expired');
  });

  group('approval window', () {
    final t0 = DateTime(2026, 11, 18, 9);
    final r = approval(
      'a',
      requestedAt: t0,
      expiresAt: t0.add(const Duration(seconds: 120)),
    );

    test('time and fraction left count down to zero', () {
      expect(r.timeLeft(t0), const Duration(seconds: 120));
      expect(r.fractionLeft(t0), 1);
      final half = t0.add(const Duration(seconds: 60));
      expect(r.timeLeft(half), const Duration(seconds: 60));
      expect(r.fractionLeft(half), 0.5);
      expect(r.isExpired(half), isFalse);

      final end = t0.add(const Duration(seconds: 120));
      expect(r.isExpired(end), isTrue);
      expect(r.timeLeft(end), Duration.zero);
      expect(r.fractionLeft(end.add(const Duration(seconds: 5))), 0);
    });

    test('expiredAt ends the window early, never extends it', () {
      final at = t0.add(const Duration(seconds: 30));
      expect(r.expiredAt(at).isExpired(at), isTrue);
      expect(r.expiredAt(at).studentName, r.studentName);
      final late = t0.add(const Duration(seconds: 200));
      expect(r.expiredAt(late).expiresAt, r.expiresAt);
    });

    test('shifted moves both timestamps', () {
      final s = r.shifted(const Duration(seconds: -20));
      expect(s.requestedAt, t0.subtract(const Duration(seconds: 20)));
      expect(
        s.expiresAt.difference(s.requestedAt),
        const Duration(seconds: 120),
      );
      expect(identical(r.shifted(Duration.zero), r), isTrue);
    });
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

    test('a request the server says expired stays, marked expired', () async {
      await ids();
      repo.decisionError = const ApprovalFailure(
        'Timed out',
        code: ApprovalFailure.expired,
        requestGone: true,
      );
      await expectLater(
        controller().decline('b'),
        throwsA(isA<ApprovalFailure>()),
      );
      expect(await ids(), ['a', 'b', 'c']);
      final items = container.read(approvalsControllerProvider).value!.items;
      final now = DateTime.now();
      expect([for (final r in items) r.isExpired(now)], [false, true, false]);
    });

    test('a request decided elsewhere leaves the list', () async {
      await ids();
      repo.decisionError = const ApprovalFailure(
        'Already decided',
        code: 'APPROVAL_ALREADY_DECIDED',
        requestGone: true,
      );
      await expectLater(
        controller().approve('b', decision),
        throwsA(isA<ApprovalFailure>()),
      );
      expect(await ids(), ['a', 'c']);
    });

    test('dismiss takes a request off the list', () async {
      await ids();
      controller().dismiss('c');
      expect(await ids(), ['a', 'b']);
      expect(repo.declined, isEmpty);
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
