import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the current auth token so the Dio interceptor can attach it.
class TokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String token) => state = token;
  void clear() => state = null;
}

final authTokenProvider = NotifierProvider<TokenNotifier, String?>(
  TokenNotifier.new,
);
