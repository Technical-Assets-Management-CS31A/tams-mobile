import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/errors/failures.dart';
import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/domain/repositories/approvals_repository.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/core/utils/clock.dart';
import 'package:tams_mobile/features/approvals/presentation/widgets/countdown.dart';
import 'package:tams_mobile/features/approvals/presentation/widgets/freeze_banner.dart';
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

  test('formatTimeLeft', () {
    expect(formatTimeLeft(const Duration(seconds: 120)), '2:00 left');
    expect(formatTimeLeft(const Duration(seconds: 102)), '1:42 left');
    expect(formatTimeLeft(const Duration(seconds: 5)), '0:05 left');
    // Rounds up: never "0:00 left" while there is still time.
    expect(formatTimeLeft(const Duration(milliseconds: 4200)), '0:05 left');
    expect(formatTimeLeft(const Duration(milliseconds: 1)), '0:01 left');
    expect(formatTimeLeft(Duration.zero), 'Expired');
    expect(formatTimeLeft(const Duration(seconds: -3)), 'Expired');
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

    test('shifted and expiredAt keep every other field', () {
      // Every field set to something other than its default. A new field
      // belongs here and in fields() below, and must survive the copy.
      final full = PendingApproval(
        id: 'full',
        studentName: 'Maria Santos',
        studentNumber: '2023-00142',
        sectionCode: 'BSCS-3A',
        photoUrl: 'http://test.local/api/approvals/full/photo',
        items: const [
          ApprovalItem(name: 'Epson Projector', assetCode: 'PRJ-0012'),
          ApprovalItem(name: 'HDMI Cable', assetCode: 'CBL-0230'),
        ],
        requestedAt: t0,
        expiresAt: t0.add(const Duration(seconds: 120)),
        roomOptions: const [room301, avr],
        defaultRoomId: 'r-avr',
        classLengthOptions: const [Duration(minutes: 60)],
        defaultClassLength: const Duration(minutes: 60),
      );
      List<Object?> fields(PendingApproval r) => [
        r.id,
        r.studentName,
        r.studentNumber,
        r.sectionCode,
        r.photoUrl,
        r.items,
        r.roomOptions,
        r.defaultRoomId,
        r.classLengthOptions,
        r.defaultClassLength,
      ];

      final shifted = full.shifted(const Duration(seconds: 7));
      expect(fields(shifted), fields(full));
      final expired = full.expiredAt(t0.add(const Duration(seconds: 30)));
      expect(fields(expired), fields(full));
      expect(expired.requestedAt, full.requestedAt);
    });
  });

  group('keepingExpired', () {
    final t0 = DateTime(2026, 11, 18, 9);
    final old = approval(
      'old',
      requestedAt: t0,
      expiresAt: t0.add(const Duration(seconds: 120)),
    );
    final pending = approval(
      'new',
      requestedAt: t0.add(const Duration(seconds: 100)),
      expiresAt: t0.add(const Duration(seconds: 220)),
    );
    final later = t0.add(const Duration(seconds: 150));

    test('keeps requests that expired and the server dropped, first', () {
      final shown = PendingApprovals(items: [old, pending]);
      final fresh = PendingApprovals(items: [pending], frozen: true);
      final merged = fresh.keepingExpired(shown, later);
      expect([for (final r in merged.items) r.id], ['old', 'new']);
      expect(merged.frozen, isTrue);
    });

    test('drops requests that left the list for other reasons', () {
      // Still pending when it left, so it was decided somewhere else.
      final shown = PendingApprovals(items: [old, pending]);
      final merged = PendingApprovals.empty.keepingExpired(shown, later);
      expect([for (final r in merged.items) r.id], ['old']);
    });

    test('the server copy wins when a request is in both', () {
      final shown = PendingApprovals(items: [old]);
      final fresh = PendingApprovals(items: [old.shifted(Duration.zero)]);
      expect(identical(fresh.keepingExpired(shown, later), fresh), isTrue);
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

    group('expired requests survive reloads', () {
      final t0 = DateTime(2026, 11, 18, 9);
      late FakeClock clock;

      setUp(() {
        clock = FakeClock(t0);
        repo = FakeApprovalsRepository([
          approval(
            'old',
            requestedAt: t0,
            expiresAt: t0.add(const Duration(seconds: 120)),
          ),
        ]);
        container = ProviderContainer(
          overrides: [
            approvalsRepositoryProvider.overrideWithValue(repo),
            clockProvider.overrideWithValue(clock.call),
          ],
        );
        addTearDown(container.dispose);
      });

      /// The server has dropped 'old' (it expired) and has a new request.
      void serverMovesOn() {
        clock.advance(const Duration(seconds: 130));
        repo.result = PendingApprovals(
          items: [
            approval(
              'new',
              requestedAt: clock(),
              expiresAt: clock().add(const Duration(seconds: 120)),
            ),
          ],
        );
      }

      test('when a push reloads the list', () async {
        expect(await ids(), ['old']);
        serverMovesOn();
        // What push_notifications.dart does for `approval.requested`.
        container.invalidate(approvalsControllerProvider);
        expect(await ids(), ['old', 'new']);
        expect(repo.pendingCalls, 2);
      });

      test('when pulled to refresh', () async {
        expect(await ids(), ['old']);
        serverMovesOn();
        await controller().refresh();
        expect(await ids(), ['old', 'new']);
      });

      test('until dismissed', () async {
        expect(await ids(), ['old']);
        serverMovesOn();
        await controller().refresh();
        controller().dismiss('old');
        await controller().refresh();
        expect(await ids(), ['new']);
      });
    });
  });

  group('freezes', () {
    const freeze = ApprovalFreeze(
      id: 'f',
      reason: FreezeReason.missing,
      assetName: 'Epson Projector',
      assetCode: 'PRJ-0012',
    );

    test('survive list changes', () {
      final list = PendingApprovals(
        items: [approval('a'), approval('b')],
        frozen: true,
        freezes: const [freeze],
      );
      for (final changed in [
        list.without('a'),
        list.updating('b', (r) => r.expiredAt(DateTime.now())),
        list.shifted(const Duration(seconds: 5)),
        // A reload keeps the expired requests and has its own freezes.
        const PendingApprovals(
          items: [],
          frozen: true,
          freezes: [freeze],
        ).keepingExpired(list, DateTime.now().add(const Duration(hours: 1))),
      ]) {
        expect(changed.freezes, isNotEmpty);
      }
      expect(list.without('a').frozen, isTrue);
    });

    test('banner line says what it can', () {
      expect(freezeLine(freeze), 'Missing: Epson Projector (PRJ-0012)');
      expect(
        freezeLine(
          const ApprovalFreeze(
            id: 'f',
            reason: FreezeReason.overdue,
            loanNo: 'L-2026-0001',
            studentName: 'Maria Santos',
          ),
        ),
        'Overdue: L-2026-0001, borrowed by Maria Santos',
      );
      expect(
        freezeLine(const ApprovalFreeze(id: 'f', reason: FreezeReason.other)),
        'Frozen',
      );
    });
  });
}
