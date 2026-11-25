import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/network/dio_client.dart';
import 'package:tams_mobile/core/network/token_provider.dart';
import 'package:tams_mobile/core/storage/token_storage.dart';
import 'package:tams_mobile/features/auth/presentation/controllers/auth_controller.dart';

import '../../helpers/login_fixtures.dart';
import '../../helpers/route_http_adapter.dart';

void main() {
  const storage = TokenStorage(FlutterSecureStorage());
  final oldToken = fakeJwt(DateTime.now().add(const Duration(minutes: 5)));
  late DebugPrintCallback originalDebugPrint;

  Future<ProviderContainer> signedIn(RouteHttpAdapter adapter) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(dioProvider).httpClientAdapter = adapter;
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    return container;
  }

  Reply refreshed(RequestOptions r) => ok({
    'accessToken': 'new-token',
    'refreshToken': 'rt-2',
    'user': {'email': 'a@b.com'},
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': oldToken,
      'auth_refresh_token': 'rt-1',
      'auth_email': 'a@b.com',
    });
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
  });

  tearDown(() => debugPrint = originalDebugPrint);

  test('a 401 renews the token and retries the request', () async {
    final adapter = RouteHttpAdapter(
      (r) => switch (r.path) {
        '/auth/refresh' => refreshed(r),
        _ when r.headers['Authorization'] == 'Bearer new-token' => ok({
          'id': 1,
        }),
        _ => problem(401, 'UNAUTHORIZED'),
      },
    );
    final c = await signedIn(adapter);

    final res = await c.read(dioProvider).get<Object?>('/items');

    expect(res.data, {'id': 1});
    final refresh = adapter.to('POST', '/auth/refresh').single;
    expect(refresh.data, {'refreshToken': 'rt-1'});
    expect(refresh.headers['Authorization'], isNull);
    expect(c.read(authTokenProvider), 'new-token');
    expect(c.read(authControllerProvider).value?.token, 'new-token');
    expect(await storage.readToken(), 'new-token');
    expect(await storage.readRefreshToken(), 'rt-2');
    expect(await storage.readEmail(), 'a@b.com');
  });

  test('a refresh without a new refresh token keeps the saved one', () async {
    final adapter = RouteHttpAdapter(
      (r) => switch (r.path) {
        '/auth/refresh' => ok({'accessToken': 'new-token'}),
        _ when r.headers['Authorization'] == 'Bearer new-token' => ok(),
        _ => problem(401, 'UNAUTHORIZED'),
      },
    );
    final c = await signedIn(adapter);

    await c.read(dioProvider).get<Object?>('/items');

    expect(c.read(authControllerProvider).value?.token, 'new-token');
    expect(await storage.readToken(), 'new-token');
    expect(await storage.readRefreshToken(), 'rt-1');
  });

  test('requests failing together renew the token once', () async {
    final adapter = RouteHttpAdapter(
      (r) => switch (r.path) {
        '/auth/refresh' => refreshed(r),
        _ when r.headers['Authorization'] == 'Bearer new-token' => ok(),
        _ => problem(401, 'UNAUTHORIZED'),
      },
    );
    final c = await signedIn(adapter);
    final dio = c.read(dioProvider);

    await Future.wait([dio.get('/a'), dio.get('/b'), dio.get('/c')]);

    expect(adapter.to('POST', '/auth/refresh'), hasLength(1));
    expect(c.read(authControllerProvider).value, isNotNull);
  });

  test('a rejected refresh token signs the user out', () async {
    final adapter = RouteHttpAdapter(
      (r) => r.path == '/auth/refresh'
          ? problem(401, 'INVALID_REFRESH_TOKEN')
          : problem(401, 'UNAUTHORIZED'),
    );
    final c = await signedIn(adapter);

    await expectLater(
      c.read(dioProvider).get('/items'),
      throwsA(isA<DioException>()),
    );
    await pumpEventQueue();

    expect(c.read(authControllerProvider).value, isNull);
    expect(c.read(authTokenProvider), isNull);
    expect(await storage.readToken(), isNull);
  });

  test('no connection during the refresh keeps the user signed in', () async {
    final adapter = RouteHttpAdapter(
      (r) =>
          r.path == '/auth/refresh' ? offline(r) : problem(401, 'UNAUTHORIZED'),
    );
    final c = await signedIn(adapter);

    await expectLater(
      c.read(dioProvider).get('/items'),
      throwsA(isA<DioException>()),
    );
    await pumpEventQueue();

    expect(c.read(authControllerProvider).value, isNotNull);
    expect(c.read(authTokenProvider), oldToken);
    expect(await storage.readRefreshToken(), 'rt-1');
  });

  test('the retried request is not renewed a second time', () async {
    final adapter = RouteHttpAdapter(
      (r) => r.path == '/auth/refresh'
          ? refreshed(r)
          : problem(401, 'UNAUTHORIZED'),
    );
    final c = await signedIn(adapter);

    await expectLater(
      c.read(dioProvider).get('/items'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.to('POST', '/auth/refresh'), hasLength(1));
    expect(adapter.to('GET', '/items'), hasLength(2));
  });

  test('an expired saved token with a refresh token is restored', () async {
    final expired = fakeJwt(DateTime.now().subtract(const Duration(hours: 1)));
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': expired,
      'auth_refresh_token': 'rt-1',
      'auth_email': 'a@b.com',
    });
    final c = await signedIn(RouteHttpAdapter((r) => ok()));

    expect(c.read(authControllerProvider).value?.email, 'a@b.com');
    expect(c.read(authTokenProvider), expired);
  });
}
