// test/unit/models/user_model_test.dart
//
// Pure-Dart unit tests for UserModel.
// No Firebase, no network — runs in milliseconds.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/user/models/user_model.dart';

void main() {
  // ── Fixture ──────────────────────────────────────────────────────────────────

  final now = DateTime(2024, 6, 1, 12);

  UserModel makeUser({
    String uid = 'uid_001',
    String email = 'test@nexus.app',
    String? firstName = 'Oday',
    String? lastName = 'Hindy',
    String? gymId = 'gym_abc',
    String? role = 'player',
    bool isActive = true,
    int trophies = 5,
    bool emailVerified = true,
    bool temporaryPasswordSet = false,
    DateTime? subscriptionEnd,
  }) =>
      UserModel(
        uid: uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
        gymId: gymId,
        role: role,
        isActive: isActive,
        trophies: trophies,
        emailVerified: emailVerified,
        temporaryPasswordSet: temporaryPasswordSet,
        createdAt: now,
        subscriptionEnd: subscriptionEnd,
      );

  // ── toMap / fromMap round-trip ────────────────────────────────────────────

  group('UserModel.toMap / fromMap round-trip', () {
    test('scalar fields survive round-trip', () {
      final user = makeUser();
      final map = user.toMap();
      final restored = UserModel.fromMap(map);

      expect(restored.uid, equals(user.uid));
      expect(restored.email, equals(user.email));
      expect(restored.firstName, equals(user.firstName));
      expect(restored.lastName, equals(user.lastName));
      expect(restored.gymId, equals(user.gymId));
      expect(restored.role, equals(user.role));
      expect(restored.isActive, equals(user.isActive));
      expect(restored.trophies, equals(user.trophies));
      expect(restored.emailVerified, equals(user.emailVerified));
      expect(restored.temporaryPasswordSet, equals(user.temporaryPasswordSet));
    });

    test('numeric fields survive round-trip', () {
      final user = makeUser().copyWith(
        weight: 80.5,
        height: 175.0,
        age: 28,
        bodyFat: 15.2,
      );
      final restored = UserModel.fromMap(user.toMap());

      expect(restored.weight, closeTo(80.5, 0.001));
      expect(restored.height, closeTo(175.0, 0.001));
      expect(restored.age, equals(28));
      expect(restored.bodyFat, closeTo(15.2, 0.001));
    });

    test('null optional fields stay null after round-trip', () {
      final user = makeUser(firstName: null, lastName: null, gymId: null);
      final restored = UserModel.fromMap(user.toMap());

      expect(restored.firstName, isNull);
      expect(restored.lastName, isNull);
      expect(restored.gymId, isNull);
    });

    test('DateTime fields survive round-trip via Timestamp', () {
      final sub = DateTime(2025, 12, 31);
      final user = makeUser().copyWith(subscriptionEnd: sub);
      final map = user.toMap();

      // toMap stores DateTime as Timestamp
      expect(map['subscriptionEnd'], isA<Timestamp>());

      final restored = UserModel.fromMap(map);
      expect(restored.subscriptionEnd?.year, equals(2025));
      expect(restored.subscriptionEnd?.month, equals(12));
      expect(restored.subscriptionEnd?.day, equals(31));
    });

    test('fromMap accepts int epoch millis for dates', () {
      final epoch = now.millisecondsSinceEpoch;
      final map = {
        'uid': 'u1',
        'email': 'a@b.com',
        'emailVerified': false,
        'temporaryPasswordSet': false,
        'isActive': true,
        'trophies': 0,
        'createdAt': epoch,  // int millis
      };
      final user = UserModel.fromMap(map);
      expect(user.createdAt.year, equals(now.year));
    });

    test('fromMap accepts string ISO date for dates', () {
      final iso = now.toIso8601String();
      final map = {
        'uid': 'u1',
        'email': 'a@b.com',
        'emailVerified': false,
        'temporaryPasswordSet': false,
        'isActive': true,
        'trophies': 0,
        'createdAt': iso,
      };
      final user = UserModel.fromMap(map);
      expect(user.createdAt.year, equals(now.year));
    });

    test('fromMap falls back gracefully when missing optional booleans', () {
      final map = {
        'uid': 'u2',
        'email': 'b@c.com',
        'createdAt': Timestamp.fromDate(now),
      };
      final user = UserModel.fromMap(map);
      expect(user.emailVerified, isFalse);
      expect(user.temporaryPasswordSet, isFalse);
      expect(user.isActive, isTrue);
      expect(user.trophies, equals(0));
    });
  });

  // ── isSubscriptionExpired ─────────────────────────────────────────────────

  group('isSubscriptionExpired', () {
    test('returns false when subscriptionEnd is null', () {
      expect(makeUser().isSubscriptionExpired, isFalse);
    });

    test('returns false when subscriptionEnd is in the future', () {
      final future = DateTime.now().add(const Duration(days: 30));
      expect(makeUser(subscriptionEnd: future).isSubscriptionExpired, isFalse);
    });

    test('returns true when subscriptionEnd is in the past', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(makeUser(subscriptionEnd: past).isSubscriptionExpired, isTrue);
    });
  });

  // ── copyWith ─────────────────────────────────────────────────────────────

  group('copyWith', () {
    test('updates only the specified field', () {
      final original = makeUser(firstName: 'Ali', trophies: 3);
      final updated = original.copyWith(firstName: 'Sara');

      expect(updated.firstName, equals('Sara'));
      expect(updated.trophies, equals(3));      // unchanged
      expect(updated.uid, equals(original.uid)); // unchanged
    });

    test('can change multiple fields at once', () {
      final original = makeUser();
      final updated = original.copyWith(role: 'coach', gymId: 'gym_xyz');

      expect(updated.role, equals('coach'));
      expect(updated.gymId, equals('gym_xyz'));
    });

    test('does not mutate the original', () {
      final original = makeUser(firstName: 'Original');
      original.copyWith(firstName: 'Changed');

      expect(original.firstName, equals('Original'));
    });
  });

  // ── toMap field correctness ───────────────────────────────────────────────

  group('toMap field correctness', () {
    test('discountAmount defaults to 0.0 in map', () {
      final map = makeUser().toMap();
      expect(map['discountAmount'], equals(0.0));
    });

    test('emailVerified is present in map', () {
      final map = makeUser().toMap();
      expect(map['emailVerified'], isTrue);
    });

    test('trophies count is present in map', () {
      final map = makeUser(trophies: 42).toMap();
      expect(map['trophies'], equals(42));
    });
  });
}
