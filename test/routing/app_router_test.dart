import 'package:flutter_test/flutter_test.dart';
import 'package:tams_mobile/features/auth/domain/entities/user_role.dart';
import 'package:tams_mobile/routing/app_router.dart';

const _tabs = ['/approvals', '/loans', '/alerts', '/audit'];

void main() {
  group('authRedirect', () {
    test('not ready: everything goes to /splash', () {
      for (final loggedIn in [false, true]) {
        for (final location in ['/', '/login', ..._tabs, '/anything']) {
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
      for (final location in ['/', '/splash', ..._tabs, '/anything']) {
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

    test('signed in: /, /splash and /login go to the first tab', () {
      expect(homeLocation, _tabs.first);
      for (final location in ['/', '/splash', '/login']) {
        expect(
          authRedirect(
            ready: true,
            loggedIn: true,
            location: location,
            role: UserRole.techStaff,
          ),
          homeLocation,
        );
      }
      for (final location in _tabs) {
        expect(
          authRedirect(
            ready: true,
            loggedIn: true,
            location: location,
            role: UserRole.techStaff,
          ),
          isNull,
        );
      }
    });

    test('custodians land on Audit', () {
      for (final location in ['/', '/splash', '/login']) {
        expect(
          authRedirect(
            ready: true,
            loggedIn: true,
            location: location,
            role: UserRole.custodian,
          ),
          auditLocation,
        );
      }
    });

    test('instructors are sent home from Audit', () {
      for (final role in [UserRole.instructor, UserRole.unknown]) {
        for (final location in ['/audit', '/audit/rooms/r-1']) {
          expect(
            authRedirect(
              ready: true,
              loggedIn: true,
              location: location,
              role: role,
            ),
            homeLocation,
          );
        }
        expect(
          authRedirect(
            ready: true,
            loggedIn: true,
            location: '/alerts',
            role: role,
          ),
          isNull,
        );
      }
    });

    test('auditors can open Audit', () {
      for (final role in [
        UserRole.custodian,
        UserRole.techStaff,
        UserRole.admin,
      ]) {
        expect(
          authRedirect(
            ready: true,
            loggedIn: true,
            location: '/audit/rooms/r-1',
            role: role,
          ),
          isNull,
        );
      }
    });
  });
}
