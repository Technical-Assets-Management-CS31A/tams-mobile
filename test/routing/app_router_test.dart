import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/routing/app_router.dart';

void main() {
  group('authRedirect', () {
    test('signed out: everything goes to /login', () {
      for (final location in ['/', '/home', '/anything']) {
        expect(authRedirect(loggedIn: false, location: location), '/login');
      }
      expect(authRedirect(loggedIn: false, location: '/login'), isNull);
    });

    test('signed in: / and /login go to /home', () {
      expect(authRedirect(loggedIn: true, location: '/'), '/home');
      expect(authRedirect(loggedIn: true, location: '/login'), '/home');
      expect(authRedirect(loggedIn: true, location: '/home'), isNull);
    });
  });
}
