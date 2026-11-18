import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tams_mobile/features/approvals/domain/entities/pending_approval.dart';
import 'package:tams_mobile/features/approvals/presentation/controllers/approvals_controller.dart';
import 'package:tams_mobile/features/auth/domain/entities/user.dart';
import 'package:tams_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:tams_mobile/features/notifications/data/push_messaging.dart';
import 'package:tams_mobile/features/notifications/presentation/controllers/push_notifications.dart';
import 'package:tams_mobile/features/splash/presentation/controllers/app_ready_provider.dart';
import 'package:tams_mobile/routing/app_router.dart';
import 'package:tams_mobile/routing/pending_location.dart';

class _FakeMessaging implements PushMessaging {
  final foreground = StreamController<RemoteMessage>.broadcast();
  final opened = StreamController<RemoteMessage>.broadcast();
  final registered = StreamController<String>.broadcast();
  RemoteMessage? initial;
  bool permissionRequested = false;
  bool didRegister = false;

  @override
  Stream<RemoteMessage> get onMessage => foreground.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => opened.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => initial;

  @override
  Future<void> requestPermission() async => permissionRequested = true;

  @override
  Future<void> register() async => didRegister = true;

  @override
  Stream<String> get onRegistered => registered.stream;

  void close() {
    foreground.close();
    opened.close();
    registered.close();
  }
}

class _SignedIn extends AuthController {
  @override
  Future<User?> build() async => const User(email: 'a@b.c', token: 't');
}

class _SignedOut extends AuthController {
  @override
  Future<User?> build() async => null;
}

class _NoApprovals extends ApprovalsController {
  @override
  List<PendingApproval> build() => const [];
}

RemoteMessage _push(String type, {String? title = 'Title', String? body}) =>
    RemoteMessage(
      data: {'type': type},
      notification: title == null && body == null
          ? null
          : RemoteNotification(title: title, body: body),
    );

class _Harness {
  _Harness(this.container, this.router, this.messaging);

  final ProviderContainer container;
  final GoRouter router;
  final _FakeMessaging messaging;

  String get location => router.routerDelegate.currentConfiguration.uri.path;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  bool signedIn = true,
  String initialLocation = '/approvals',
  RemoteMessage? initialMessage,
}) async {
  final messaging = _FakeMessaging()..initial = initialMessage;
  addTearDown(messaging.close);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [shellRoute()],
  );
  addTearDown(router.dispose);

  final container = ProviderContainer(
    overrides: [
      pushMessagingProvider.overrideWithValue(messaging),
      authControllerProvider.overrideWith(
        signedIn ? _SignedIn.new : _SignedOut.new,
      ),
      appReadyProvider.overrideWith((ref) async {}),
      routerProvider.overrideWithValue(router),
      approvalsControllerProvider.overrideWith(_NoApprovals.new),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appReadyProvider.future);
  await container.read(authControllerProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        scaffoldMessengerKey: container.read(scaffoldMessengerKeyProvider),
        routerConfig: router,
      ),
    ),
  );
  await container.read(pushNotificationsProvider).start();
  await tester.pumpAndSettle();
  return _Harness(container, router, messaging);
}

void main() {
  group('tapping a notification', () {
    testWidgets('approval request opens Pending Approvals', (tester) async {
      final h = await _pump(tester, initialLocation: '/alerts');

      h.messaging.opened.add(_push('approval.requested'));
      await tester.pumpAndSettle();

      expect(h.location, '/approvals');
      expect(find.text('No pending approvals'), findsOneWidget);
    });

    testWidgets('overdue loan opens Alerts', (tester) async {
      final h = await _pump(tester);

      h.messaging.opened.add(_push('loan.overdue'));
      await tester.pumpAndSettle();

      expect(h.location, '/alerts');
    });

    testWidgets('one that launched the app opens its screen', (tester) async {
      final h = await _pump(tester, initialMessage: _push('instructor.frozen'));

      expect(h.location, '/loans');
    });

    testWidgets('unknown type stays where it is', (tester) async {
      final h = await _pump(tester, initialLocation: '/audit');

      h.messaging.opened.add(_push('station.healthChanged'));
      await tester.pumpAndSettle();

      expect(h.location, '/audit');
      expect(h.container.read(pendingLocationProvider), isNull);
    });

    testWidgets('signed out: waits for sign-in', (tester) async {
      final h = await _pump(tester, signedIn: false);

      h.messaging.opened.add(_push('approval.requested'));
      await tester.pumpAndSettle();

      expect(h.container.read(pendingLocationProvider), '/approvals');
    });
  });

  group('push in the foreground', () {
    testWidgets('shows a snackbar whose View opens the screen', (tester) async {
      final h = await _pump(tester);

      h.messaging.foreground.add(
        _push('LOAN_OVERDUE', title: 'Loan overdue', body: 'Projector P-12'),
      );
      await _showSnackBar(tester);

      expect(find.text('Loan overdue'), findsOneWidget);
      expect(find.text('Projector P-12'), findsOneWidget);
      expect(h.location, '/approvals', reason: 'no navigation until tapped');

      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pumpAndSettle();
      expect(h.location, '/alerts');
    });

    testWidgets('unknown type shows without a View button', (tester) async {
      final h = await _pump(tester);

      h.messaging.foreground.add(_push('something.new', title: 'Hello'));
      await _showSnackBar(tester);

      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('View'), findsNothing);
    });

    testWidgets('data-only push shows nothing', (tester) async {
      final h = await _pump(tester);

      h.messaging.foreground.add(_push('approval.requested', title: null));
      await _showSnackBar(tester);

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('registration', () {
    testWidgets('signed in: asks permission and registers', (tester) async {
      final h = await _pump(tester);

      expect(h.messaging.permissionRequested, isTrue);
      expect(h.messaging.didRegister, isTrue);
    });

    testWidgets('signed out: does neither', (tester) async {
      final h = await _pump(tester, signedIn: false);

      expect(h.messaging.permissionRequested, isFalse);
      expect(h.messaging.didRegister, isFalse);
    });
  });
}

/// Delivers the stream event, then runs the snackbar's entrance animation.
Future<void> _showSnackBar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
