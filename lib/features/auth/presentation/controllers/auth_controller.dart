import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tams_mobile/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:tams_mobile/features/auth/data/repositories/auth_repository_impl.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/token_provider.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/jwt.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';

// ---- dependency providers ----
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSource(ref.watch(dioProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider)),
);

final loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

// ---- state ----
/// null = logged out, User = logged in.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    // The Dio interceptor clears the token when the server answers 401.
    ref.listen(authTokenProvider, (_, token) {
      if (token == null && state.value != null) _endSession();
    });
    return _restoreSession();
  }

  /// Restores the saved session on app start, if there is a usable one.
  Future<User?> _restoreSession() async {
    final storage = ref.read(tokenStorageProvider);
    final User? saved;
    try {
      final token = await storage.readToken();
      final email = await storage.readEmail();
      saved = (token == null || email == null)
          ? null
          : User(
              email: email,
              token: token,
              refreshToken: await storage.readRefreshToken(),
            );
    } catch (e) {
      // e.g. Android keystore reset after a backup restore: the saved
      // entries can't be decrypted any more. Start fresh.
      debugPrint('Could not read the saved session: $e');
      await _clearStorage();
      return null;
    }
    if (saved == null) return null;

    final expiry = jwtExpiry(saved.token);
    if (expiry != null && !expiry.isAfter(DateTime.now())) {
      // Student/teacher tokens last 15 minutes.
      // TODO: renew via /auth/refresh-token-mobile instead of signing out.
      await _clearStorage();
      return null;
    }

    ref.read(authTokenProvider.notifier).set(saved.token);
    return saved;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(loginUseCaseProvider)(email, password);
      try {
        await ref
            .read(tokenStorageProvider)
            .save(
              token: user.token,
              email: user.email,
              refreshToken: user.refreshToken,
            );
      } catch (e) {
        // e.g. no keyring on Linux, keystore error on Android. Remove any
        // half-written entries and stay logged out.
        debugPrint('Could not save the session: $e');
        await _clearStorage();
        throw const Failure(
          "Couldn't save your sign-in on this device. Please try again.",
        );
      }
      ref.read(authTokenProvider.notifier).set(user.token);
      return user;
    });
  }

  /// Signs out right away; clearing storage can't keep the user signed in.
  Future<void> logout() async {
    state = const AsyncData(null);
    ref.read(authTokenProvider.notifier).clear();
    await _clearStorage();
  }

  Future<void> _endSession() async {
    state = const AsyncData(null);
    await _clearStorage();
  }

  /// Best effort: a storage error must never keep the user signed in.
  Future<void> _clearStorage() async {
    try {
      await ref.read(tokenStorageProvider).clear();
    } catch (e) {
      debugPrint('Could not clear the saved session: $e');
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);
