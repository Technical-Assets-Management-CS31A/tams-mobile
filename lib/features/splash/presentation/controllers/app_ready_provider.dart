import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

/// Shortest time the splash stays up, so it never just flickers.
const splashMinDuration = Duration(milliseconds: 1500);

/// Completes once the app can leave the splash: the saved session has been
/// checked and the splash has been up for [splashMinDuration].
final appReadyProvider = FutureProvider<void>((ref) async {
  await Future.wait<Object?>([
    // read, not watch: a later login must not send the user back here.
    // Errors are fine to ignore; the router reads the auth state itself.
    ref.read(authControllerProvider.future).catchError((_) => null),
    Future<void>.delayed(splashMinDuration),
  ]);
});
