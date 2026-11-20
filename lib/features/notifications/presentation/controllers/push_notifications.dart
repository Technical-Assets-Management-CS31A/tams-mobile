import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../routing/app_router.dart';
import '../../../../routing/pending_location.dart';
import '../../../alerts/presentation/controllers/alerts_controller.dart';
import '../../../approvals/presentation/controllers/approvals_controller.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../splash/presentation/controllers/app_ready_provider.dart';
import '../../data/push_messaging.dart';
import '../../domain/push_destination.dart';

/// Shows in-app snackbars from outside the widget tree (foreground pushes).
final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>(
      (ref) => GlobalKey<ScaffoldMessengerState>(),
    );

/// How long a foreground push stays on screen. Long enough to reach for the
/// phone: an approval request times out after 120 s (PRD 10.2).
const foregroundPushDuration = Duration(seconds: 10);

/// Handles Firebase Cloud Messaging while the app runs:
/// - tapping a notification (app in background or terminated) opens the
///   screen for its type, after the splash and sign-in if needed;
/// - a push that arrives in the foreground shows as a snackbar with "View";
/// - once signed in, asks for notification permission and registers with FCM.
class PushNotifications {
  PushNotifications(this._ref);

  final Ref _ref;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _started = false;
  bool _registered = false;

  /// A notice opened before the session was restored (e.g. the one that
  /// launched the app): marked read once signed in, when it actually opens.
  String? _unreadOpenedNotice;

  PushMessaging get _messaging => _ref.read(pushMessagingProvider);

  /// Starts listening. Safe to call more than once.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _subscriptions
      ..add(_messaging.onMessageOpenedApp.listen(_opened))
      ..add(_messaging.onMessage.listen(_showInApp));

    // Only signed-in staff get pushes, so ask for permission then rather
    // than on the login screen.
    _ref.listen(authControllerProvider, (_, auth) {
      if (auth.value == null) return;
      unawaited(_register());
      if (_unreadOpenedNotice case final id?) {
        _unreadOpenedNotice = null;
        unawaited(_markRead(id));
      }
    }, fireImmediately: true);

    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _opened(initial);
    } catch (e) {
      debugPrint('Could not read the notification that opened the app: $e');
    }
  }

  /// Opens [location] now if the user can see it, otherwise once the splash
  /// is done and they've signed in.
  void open(String location) {
    final ready = _ref.read(appReadyProvider).hasValue;
    final signedIn = _ref.read(authControllerProvider).value != null;
    if (ready && signedIn) {
      _ref.read(routerProvider).go(location);
    } else {
      _ref.read(pendingLocationProvider.notifier).set(location);
    }
  }

  /// The user tapped the system notification.
  void _opened(RemoteMessage message) {
    // A notice reloads Alerts once it is marked read; anything else now.
    if (noticeId(message.data) == null) _refreshData(message);
    _view(message, locationForPush(message.data));
  }

  /// Opens what [message] is about, from the system notification or the
  /// snackbar's "View". Either way, opening a notice is reading it, as
  /// tapping it in Alerts would be.
  void _view(RemoteMessage message, String? location) {
    if (noticeId(message.data) case final id?) _markReadWhenSignedIn(id);
    if (location != null) open(location);
  }

  /// Marking read needs the session's token, which isn't restored yet on a
  /// cold start; until then the notice waits for sign-in.
  void _markReadWhenSignedIn(String id) {
    if (_ref.read(authControllerProvider).value != null) {
      unawaited(_markRead(id));
    } else {
      _unreadOpenedNotice = id;
    }
  }

  /// A new request or notice means the cached list it belongs to is stale.
  void _refreshData(RemoteMessage message) {
    if (message.data['type'] == 'approval.requested') {
      _ref.invalidate(approvalsControllerProvider);
    }
    if (isAlertPush(message.data)) _ref.invalidate(alertsControllerProvider);
  }

  Future<void> _markRead(String id) async {
    try {
      await _ref.read(alertsRepositoryProvider).markRead(id);
    } catch (e) {
      debugPrint('Could not mark notification $id read: $e');
    } finally {
      // One reload, after the read: it has the new notice and the unread
      // dot and badge match the server.
      _ref.invalidate(alertsControllerProvider);
    }
  }

  void _showInApp(RemoteMessage message) {
    _refreshData(message);
    final messenger = _ref.read(scaffoldMessengerKeyProvider).currentState;
    final title = message.notification?.title;
    final body = message.notification?.body;
    // Data-only pushes carry nothing to show.
    if (messenger == null || (title == null && body == null)) return;

    final location = locationForPush(message.data);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: foregroundPushDuration,
          behavior: SnackBarBehavior.floating,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (body != null) Text(body),
            ],
          ),
          action: location == null
              ? null
              : SnackBarAction(
                  label: 'View',
                  onPressed: () => _view(message, location),
                ),
        ),
      );
  }

  Future<void> _register() async {
    if (_registered) return;
    _registered = true;
    try {
      await _messaging.requestPermission();
      _subscriptions.add(_messaging.onRegistered.listen(_onRegistered));
      await _messaging.register();
    } catch (e) {
      // e.g. no Google Play services, or the user said no. The in-app
      // Pending Approvals list still works without pushes.
      debugPrint('Push notifications unavailable: $e');
      _registered = false;
    }
  }

  void _onRegistered(String id) {
    // TODO: send to the backend's device_tokens (PRD 7.3) once it has an
    // endpoint for it; until then pushes can only be sent to this ID by hand.
    debugPrint('Registered for push notifications: $id');
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
  }
}

final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  final push = PushNotifications(ref);
  ref.onDispose(push.dispose);
  return push;
});
