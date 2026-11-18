import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time. Overridden in tests so countdowns can be driven
/// without waiting for real time to pass.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);
