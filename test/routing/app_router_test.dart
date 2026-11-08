import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/routing/app_router.dart';

void main() {
  group('authRedirect', () {
    test('not ready: everything goes to /splash', () {
      for (final loggedIn in [false, true]) {
        for (final location in ['/', '/login', '/home', '/anything']) {
          expect(
            authRedirect(ready: false, loggedIn: loggedIn, location: location),
            '/splash',
          );
        }
        expect(
          authRedirect(ready: false, loggedIn: loggedIn, location: '/splash'),
          isNull,
        );
      }
    });

    test('signed out: everything goes to /login', () {
      for (final location in ['/', '/splash', '/home', '/anything']) {
        expect(
          authRedirect(ready: true, loggedIn: false, location: location),
          '/login',
        );
      }
      expect(
        authRedirect(ready: true, loggedIn: false, location: '/login'),
        isNull,
      );
    });

    test('signed in: /, /splash and /login go to /home', () {
      for (final location in ['/', '/splash', '/login']) {
        expect(
          authRedirect(ready: true, loggedIn: true, location: location),
          '/home',
        );
      }
      expect(
        authRedirect(ready: true, loggedIn: true, location: '/home'),
        isNull,
      );
    });
  });
}
