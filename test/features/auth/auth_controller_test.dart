import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/network/dio_client.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/core/storage/token_storage.dart';
import 'package:tams_mobile/features/auth/presentation/controllers/auth_controller.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  const storage = TokenStorage(FlutterSecureStorage());

  ProviderContainer makeContainer(FakeHttpAdapter adapter) {
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(fakeDio(adapter)),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    // Keep the controller alive for the whole test.
    container.listen(authControllerProvider, (_, _) {});
    return container;
  }

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('starts logged out when nothing is stored', () async {
    final c = makeContainer(FakeHttpAdapter());

    expect(await c.read(authControllerProvider.future), isNull);
    expect(c.read(authTokenProvider), isNull);
  });

  test('restores a saved session on start', () async {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'saved-token',
      'auth_email': 'a@b.com',
    });
    final c = makeContainer(FakeHttpAdapter());

    final user = await c.read(authControllerProvider.future);
    expect(user?.email, 'a@b.com');
    expect(c.read(authTokenProvider), 'saved-token');
  });

  test('successful login saves the token and logs in', () async {
    final c = makeContainer(FakeHttpAdapter(body: {'id': 3}));
    await c.read(authControllerProvider.future);

    await c.read(authControllerProvider.notifier).login('a@b.com', 'pw');

    expect(c.read(authControllerProvider).value?.email, 'a@b.com');
    expect(c.read(authTokenProvider), 'fake-token-3');
    expect(await storage.readToken(), 'fake-token-3');
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

  test('logout clears the session', () async {
    final c = makeContainer(FakeHttpAdapter(body: {'id': 3}));
    await c.read(authControllerProvider.future);
    await c.read(authControllerProvider.notifier).login('a@b.com', 'pw');

    await c.read(authControllerProvider.notifier).logout();

    expect(c.read(authControllerProvider).value, isNull);
    expect(c.read(authTokenProvider), isNull);
    expect(await storage.readToken(), isNull);
  });
}
