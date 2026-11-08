import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/network/dio_client.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/core/storage/token_storage.dart';
import 'package:tams_mobile/features/auth/presentation/controllers/auth_controller.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/login_fixtures.dart';

/// Secure storage that fails like a broken Android keystore.
class _BrokenStorage extends TokenStorage {
  _BrokenStorage() : super(const FlutterSecureStorage());

  bool failReads = false;
  bool failSave = false;
  bool failClear = false;
  bool cleared = false;

  @override
  Future<String?> readToken() async {
    if (failReads) throw PlatformException(code: 'BadPaddingException');
    return super.readToken();
  }

  @override
  Future<void> save({
    required String token,
    required String email,
    String? refreshToken,
  }) async {
    if (failSave) throw PlatformException(code: 'KeyStoreException');
    return super.save(token: token, email: email, refreshToken: refreshToken);
  }

  @override
  Future<void> clear() async {
    cleared = true;
    if (failClear) throw PlatformException(code: 'KeyStoreException');
    return super.clear();
  }
}

void main() {
  const storage = TokenStorage(FlutterSecureStorage());
  late DebugPrintCallback originalDebugPrint;

  ProviderContainer makeContainer(
    FakeHttpAdapter adapter, {
    TokenStorage tokenStorage = storage,
  }) {
    final container = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(tokenStorage)],
    );
    addTearDown(container.dispose);
    // Real Dio (with the auth interceptor), fake network.
    container.read(dioProvider).httpClientAdapter = adapter;
    // Keep the controller alive for the whole test.
    container.listen(authControllerProvider, (_, _) {});
    return container;
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    // Silence the debug HTTP logger.
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
  });

  tearDown(() => debugPrint = originalDebugPrint);

  group('session restore', () {
    test('starts logged out when nothing is stored', () async {
      final c = makeContainer(FakeHttpAdapter());

      expect(await c.read(authControllerProvider.future), isNull);
      expect(c.read(authTokenProvider), isNull);
    });

    test('restores a saved session with a valid token', () async {
      final token = fakeJwt(DateTime.now().add(const Duration(minutes: 10)));
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': token,
        'auth_refresh_token': 'rt',
        'auth_email': 'a@b.com',
      });
      final c = makeContainer(FakeHttpAdapter());

      final user = await c.read(authControllerProvider.future);
      expect(user?.email, 'a@b.com');
      expect(user?.refreshToken, 'rt');
      expect(c.read(authTokenProvider), token);
    });

    test('an expired token is not restored and is cleared', () async {
      FlutterSecureStorage.setMockInitialValues({
        'auth_token': fakeJwt(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        'auth_email': 'a@b.com',
      });
      final c = makeContainer(FakeHttpAdapter());

      expect(await c.read(authControllerProvider.future), isNull);
      expect(c.read(authTokenProvider), isNull);
      expect(await storage.readToken(), isNull);
    });

    test('unreadable storage starts logged out and clears it', () async {
      final broken = _BrokenStorage()..failReads = true;
      final c = makeContainer(FakeHttpAdapter(), tokenStorage: broken);

      final result = await c.read(authControllerProvider.future);

      expect(result, isNull);
      expect(c.read(authControllerProvider).hasError, isFalse);
      expect(broken.cleared, isTrue);
    });
  });

  group('login', () {
    test('success saves the tokens and logs in', () async {
      final c = makeContainer(
        FakeHttpAdapter(body: loginResponse(accessToken: 'jwt-3')),
      );
      await c.read(authControllerProvider.future);

      await c.read(authControllerProvider.notifier).login('a@b.com', 'pw');

      expect(c.read(authControllerProvider).value?.email, 'a@b.com');
      expect(c.read(authTokenProvider), 'jwt-3');
      expect(await storage.readToken(), 'jwt-3');
      expect(await storage.readRefreshToken(), 'refresh-token');
    });

    test('invalid credentials set an error and stay logged out', () async {
      final c = makeContainer(FakeHttpAdapter(statusCode: 401));
      await c.read(authControllerProvider.future);

      await c.read(authControllerProvider.notifier).login('a@b.com', 'wrong');

      final state = c.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), 'Incorrect email or password.');
      expect(c.read(authTokenProvider), isNull);
      expect(await storage.readToken(), isNull);
    });
  });

  test(
    'a storage failure on login shows a message and stays logged out',
    () async {
      final broken = _BrokenStorage()..failSave = true;
      final c = makeContainer(
        FakeHttpAdapter(body: loginResponse()),
        tokenStorage: broken,
      );
      await c.read(authControllerProvider.future);

      await c.read(authControllerProvider.notifier).login('a@b.com', 'pw');

      final state = c.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect(
        state.error.toString(),
        "Couldn't save your sign-in on this device. Please try again.",
      );
      expect(c.read(authTokenProvider), isNull);
      expect(broken.cleared, isTrue);
    },
  );

  test('logout signs out even if clearing storage fails', () async {
    final broken = _BrokenStorage();
    final c = makeContainer(
      FakeHttpAdapter(body: loginResponse()),
      tokenStorage: broken,
    );
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier).login('a@b.com', 'pw');

    broken.failClear = true;
    await c.read(authControllerProvider.notifier).logout();

    expect(c.read(authControllerProvider).value, isNull);
    expect(c.read(authControllerProvider).hasError, isFalse);
    expect(c.read(authTokenProvider), isNull);
  });

  test('logout clears the session', () async {
    final c = makeContainer(FakeHttpAdapter(body: loginResponse()));
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier).login('a@b.com', 'pw');

    await c.read(authControllerProvider.notifier).logout();

    expect(c.read(authControllerProvider).value, isNull);
    expect(c.read(authTokenProvider), isNull);
    expect(await storage.readToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
  });

  group('server rejects the token (401)', () {
    test('signs the user out and clears storage', () async {
      final adapter = FakeHttpAdapter(body: loginResponse());
      final c = makeContainer(adapter);
      await c.read(authControllerProvider.future);
      await c.read(authControllerProvider.notifier).login('a@b.com', 'pw');

      adapter
        ..statusCode = 401
        ..body = errorResponse('Unauthorized');
      await expectLater(
        c.read(dioProvider).get('/items'),
        throwsA(isA<DioException>()),
      );
      await pumpEventQueue();

      expect(
        adapter.lastRequest!.headers['Authorization'],
        'Bearer access-token',
      );
      expect(c.read(authControllerProvider).value, isNull);
      expect(c.read(authTokenProvider), isNull);
      expect(await storage.readToken(), isNull);
    });
  });
}
