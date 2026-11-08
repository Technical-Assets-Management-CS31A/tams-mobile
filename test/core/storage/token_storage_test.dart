import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/storage/token_storage.dart';

void main() {
  late TokenStorage storage;

  setUp(() {
    // In-memory secure storage; no platform channel needed.
    FlutterSecureStorage.setMockInitialValues({});
    storage = const TokenStorage(FlutterSecureStorage());
  });

  test('is empty initially', () async {
    expect(await storage.readToken(), isNull);
    expect(await storage.readEmail(), isNull);
  });

  test('save then read returns tokens and email', () async {
    await storage.save(token: 't-123', email: 'a@b.com', refreshToken: 'r-1');

    expect(await storage.readToken(), 't-123');
    expect(await storage.readRefreshToken(), 'r-1');
    expect(await storage.readEmail(), 'a@b.com');
  });

  test('saving without a refresh token removes the old one', () async {
    await storage.save(token: 't-1', email: 'a@b.com', refreshToken: 'r-1');
    await storage.save(token: 't-2', email: 'a@b.com');

    expect(await storage.readRefreshToken(), isNull);
  });

  test('clear removes tokens and email', () async {
    await storage.save(token: 't-123', email: 'a@b.com', refreshToken: 'r-1');
    await storage.clear();

    expect(await storage.readToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
    expect(await storage.readEmail(), isNull);
  });
}
