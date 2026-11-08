import 'package:flutter/foundation.dart';

/// Endpoints of the TAMS .NET backend (BackendTechnicalAssetsManagement).
class ApiConstants {
  /// Override per device with:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5289/api/v1`
  static const _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Backend's local dev port (Properties/launchSettings.json, "http" profile).
  static const _devPort = 5278;

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    // The Android emulator reaches the host machine at 10.0.2.2;
    // "localhost" there is the emulator itself.
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return 'http://$host:$_devPort/api/v1';
  }

  /// Returns the JWT and refresh token in the body (the web `/auth/login`
  /// sets cookies instead).
  static const loginPath = '/auth/login-mobile';
}
