import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase_options.dart';

/// The parts of Firebase Cloud Messaging the app uses, so tests can fake it.
abstract interface class PushMessaging {
  /// Pushes that arrive while the app is in the foreground. The OS doesn't
  /// show these, so the app has to.
  Stream<RemoteMessage> get onMessage;

  /// The user tapped a notification while the app was in the background.
  Stream<RemoteMessage> get onMessageOpenedApp;

  /// The notification the user tapped to launch the app from terminated,
  /// or null if it was opened some other way. Only returned once.
  Future<RemoteMessage?> getInitialMessage();

  /// Asks to show notifications (iOS, and Android 13+).
  Future<void> requestPermission();

  /// Registers this install with FCM. The ID to push to then arrives on
  /// [onRegistered], and again whenever it changes.
  Future<void> register();
  Stream<String> get onRegistered;
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();

  @override
  Future<void> requestPermission() => _messaging.requestPermission();

  @override
  Future<void> register() => _messaging.register();

  @override
  Stream<String> get onRegistered => _messaging.onRegistered;
}

final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => FirebasePushMessaging(FirebaseMessaging.instance),
);

/// Runs in a separate isolate for pushes that arrive while the app is in the
/// background or terminated. Pushes with a `notification` block are shown by
/// the OS on their own; tapping one is handled by [PushMessaging]
/// .onMessageOpenedApp / getInitialMessage in the main isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background push received: ${message.data['type']}');
}
