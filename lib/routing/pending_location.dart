import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A screen to open once the user is past the splash and signed in, e.g. the
/// tab a tapped notification points to. The router takes it (and clears it)
/// instead of the home tab when leaving /splash or /login.
class PendingLocation extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String location) => state = location;

  void clear() => state = null;
}

final pendingLocationProvider = NotifierProvider<PendingLocation, String?>(
  PendingLocation.new,
);
