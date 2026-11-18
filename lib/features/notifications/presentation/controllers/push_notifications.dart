import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../routing/app_router.dart';
import '../../../../routing/pending_location.dart';
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
      if (auth.value != null) unawaited(_register());
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

  void _opened(RemoteMessage message) {
    final location = locationForPush(message.data);
    if (location != null) open(location);
  }

  void _showInApp(RemoteMessage message) {
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
              : SnackBarAction(label: 'View', onPressed: () => open(location)),
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
