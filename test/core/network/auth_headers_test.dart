import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/core/network/auth_headers.dart';

void main() {
  const api = 'http://10.0.2.2:5278/api/v1';
  const bearer = {'Authorization': 'Bearer t'};

  Map<String, String>? headers(String? url, {String? token = 't'}) =>
      authHeadersFor(url, token: token, apiBaseUrl: api);

  test("a photo on the API's own host gets the token", () {
    expect(headers('http://10.0.2.2:5278/api/v1/checkouts/1/photo'), bearer);
  });

  test('a photo on another host does not', () {
    expect(headers('https://storage.example.com/photo.jpg'), isNull);
  });

  test('nor one on the same host but another port or scheme', () {
    expect(headers('http://10.0.2.2:9000/photo.jpg'), isNull);
    expect(headers('https://10.0.2.2:5278/photo.jpg'), isNull);
  });

  test('default ports match when written out', () {
    expect(
      authHeadersFor(
        'https://api.example.com:443/photo.jpg',
        token: 't',
        apiBaseUrl: 'https://api.example.com/api/v1',
      ),
      bearer,
    );
  });

  test('no token, no photo or a relative URL: no header', () {
    expect(headers('http://10.0.2.2:5278/photo.jpg', token: null), isNull);
    expect(headers(null), isNull);
    expect(headers('/photo.jpg'), isNull);
  });
}
