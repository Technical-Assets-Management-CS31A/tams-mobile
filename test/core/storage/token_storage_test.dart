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

  test('save then read returns token and email', () async {
    await storage.save(token: 't-123', email: 'a@b.com');

    expect(await storage.readToken(), 't-123');
    expect(await storage.readEmail(), 'a@b.com');
  });

  test('clear removes token and email', () async {
    await storage.save(token: 't-123', email: 'a@b.com');
    await storage.clear();

    expect(await storage.readToken(), isNull);
    expect(await storage.readEmail(), isNull);
  });
}
