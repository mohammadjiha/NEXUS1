// test/unit/utils/app_role_test.dart
//
// Unit tests for AppRole utility — pure Dart, zero dependencies.

import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/core/utils/role_utils.dart';

void main() {
  // ── Role constants ────────────────────────────────────────────────────────

  group('AppRole constants', () {
    test('player constant equals "player"', () {
      expect(AppRole.player, equals('player'));
    });

    test('coach constant equals "coach"', () {
      expect(AppRole.coach, equals('coach'));
    });

    test('admin constant equals "admin"', () {
      expect(AppRole.admin, equals('admin'));
    });

    test('owner constant equals "owner"', () {
      expect(AppRole.owner, equals('owner'));
    });

    test('gymAdmin constant equals "gym_admin"', () {
      expect(AppRole.gymAdmin, equals('gym_admin'));
    });
  });

  // ── isPrivileged ─────────────────────────────────────────────────────────

  group('AppRole.isPrivileged', () {
    test('coach is privileged', () {
      expect(AppRole.isPrivileged('coach'), isTrue);
    });

    test('admin is privileged', () {
      expect(AppRole.isPrivileged('admin'), isTrue);
    });

    test('owner is privileged', () {
      expect(AppRole.isPrivileged('owner'), isTrue);
    });

    test('gym_admin is privileged', () {
      expect(AppRole.isPrivileged('gym_admin'), isTrue);
    });

    test('player is NOT privileged', () {
      expect(AppRole.isPrivileged('player'), isFalse);
    });

    test('null is NOT privileged', () {
      expect(AppRole.isPrivileged(null), isFalse);
    });

    test('empty string is NOT privileged', () {
      expect(AppRole.isPrivileged(''), isFalse);
    });

    test('unknown role is NOT privileged', () {
      expect(AppRole.isPrivileged('superuser'), isFalse);
    });

    test('privilegedRoles set contains exactly 4 roles', () {
      expect(AppRole.privilegedRoles.length, equals(4));
    });
  });

  // ── isPlayer ─────────────────────────────────────────────────────────────

  group('AppRole.isPlayer', () {
    test('player role returns true', () {
      expect(AppRole.isPlayer('player'), isTrue);
    });

    test('coach role returns false', () {
      expect(AppRole.isPlayer('coach'), isFalse);
    });

    test('null returns false', () {
      expect(AppRole.isPlayer(null), isFalse);
    });

    test('empty string returns false', () {
      expect(AppRole.isPlayer(''), isFalse);
    });

    test('PLAYER (uppercase) returns false — case sensitive', () {
      expect(AppRole.isPlayer('PLAYER'), isFalse);
    });
  });
}
