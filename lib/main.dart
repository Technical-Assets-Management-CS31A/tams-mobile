import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/notifications/data/push_messaging.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Required before any async code runs ahead of runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the generated platform options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const ProviderScope(child: App()));
}
