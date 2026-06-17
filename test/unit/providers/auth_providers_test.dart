// test/unit/providers/auth_providers_test.dart
//
// Unit tests for pure-computed providers in auth_repository.dart:
//   - currentUserFirstNameProvider
//   - currentUserInitialsProvider
//
// WHY testWidgets instead of plain test()?
// ─────────────────────────────────────────
// StreamProvider overrides emit via microtasks (Stream.value →
// Future.value.asStream → microtask delivery).  In plain test() under
// `flutter test`, those microtasks are not driven forward automatically, so
// `await container.read(provider.future)` hangs for 30 seconds.
//
// testWidgets runs inside fakeAsync; tester.pump() calls flushMicrotasks(),
// which delivers the stream event → Riverpod transitions to AsyncData →
// computed providers recompute → assertions succeed without any timeout risk.
//
// Sync tests (no-user cases) still use plain test() since they do not need
// stream settlement.

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/auth/data/auth_repository.dart';
import 'package:nexus/src/features/user/models/user_model.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Container whose providers are stubbed with Stream.value() so no Firebase
/// initialization is required.
ProviderContainer _container({
  required MockUser authUser,
  UserModel? firestoreUser,
}) {
  return ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((_) => Stream.value(authUser)),
      currentUserModelProvider.overrideWith(
        (_) => firestoreUser == null
            ? const Stream.empty()
            : Stream.value(firestoreUser),
      ),
    ],
  );
}

/// Container with NO signed-in user.
ProviderContainer _emptyContainer() => ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((_) => const Stream.empty()),
        currentUserModelProvider.overrideWith((_) => const Stream.empty()),
      ],
    );

UserModel _userModel({String? firstName, String? lastName}) => UserModel(
      uid: 'u1',
      email: 'test@nexus.app',
      firstName: firstName,
      lastName: lastName,
      emailVerified: true,
      createdAt: DateTime(2024),
    );

/// Establishes persistent listeners on both stream providers and flushes the
/// event loop until Riverpod has settled.
///
/// WHY listen() instead of read()?
/// In Riverpod 3.x, container.read() does a one-shot read.  A StreamProvider
/// only pushes state updates to active listeners — without one, the stream
/// emits but nobody receives it and the provider stays AsyncLoading.
/// container.listen() keeps the provider alive and reacts to emissions.
///
/// WHY pumpAndSettle()?
/// Riverpod 3.x has multiple async layers between stream emission and state
/// propagation (subscription setup, delivery, dirty notification, recompute).
/// pumpAndSettle() keeps flushing microtasks until nothing is pending, which
/// guarantees all layers complete before assertions run.
Future<void> _settle(ProviderContainer container, WidgetTester tester) async {
  container.listen(authStateProvider, (_, __) {}, fireImmediately: true);
  container.listen(currentUserModelProvider, (_, __) {}, fireImmediately: true);
  await tester.pumpAndSettle();
}

void main() {
  // ── currentUserFirstNameProvider ──────────────────────────────────────────

  group('currentUserFirstNameProvider', () {
    test('returns null when no user is signed in', () {
      final container = _emptyContainer();
      addTearDown(container.dispose);
      expect(container.read(currentUserFirstNameProvider), isNull);
    });

    testWidgets('returns firstName from Firestore when set', (tester) async {
      final authUser = MockUser(uid: 'u1', email: 'test@nexus.app');
      final container = _container(
        authUser: authUser,
        firestoreUser: _userModel(firstName: 'Oday', lastName: 'Hindy'),
      );
      addTearDown(container.dispose);

      await _settle(container, tester);

      expect(container.read(currentUserFirstNameProvider), equals('Oday'));
    });

    testWidgets('trims whitespace from firstName', (tester) async {
      final authUser = MockUser(uid: 'u1', email: 'test@nexus.app');
      final container = _container(
        authUser: authUser,
        firestoreUser: _userModel(firstName: '  Sara  '),
      );
      addTearDown(container.dispose);

      await _settle(container, tester);

      expect(container.read(currentUserFirstNameProvider), equals('Sara'));
    });

    testWidgets(
        'falls back to email prefix when displayName and Firestore name are absent',
        (tester) async {
      final authUser = MockUser(
        uid: 'u2',
        email: 'johndoe@nexus.app',
      );
      final container = _container(
        authUser: authUser,
        firestoreUser: _userModel(),
      );
      addTearDown(container.dispose);

      await _settle(container, tester);

      expect(container.read(currentUserFirstNameProvider), equals('johndoe'));
    });
  });

  // ── currentUserInitialsProvider ───────────────────────────────────────────

  group('currentUserInitialsProvider', () {
    test('returns "?" when no user is signed in', () {
      final container = _emptyContainer();
      addTearDown(container.dispose);
      expect(container.read(currentUserInitialsProvider), equals('?'));
    });

    testWidgets('returns two-letter initials from firstName + lastName',
        (tester) async {
      final authUser = MockUser(uid: 'u1', email: 'test@nexus.app');
      final container = _container(
        authUser: authUser,
        firestoreUser: _userModel(firstName: 'Oday', lastName: 'Hindy'),
      );
      addTearDown(container.dispose);

      await _settle(container, tester);

      expect(container.read(currentUserInitialsProvider), equals('OH'));
    });

    testWidgets('initials are always uppercase', (tester) async {
      final authUser = MockUser(uid: 'u1', email: 'test@nexus.app');
      final container = _container(
        authUser: authUser,
        firestoreUser: _userModel(firstName: 'ali', lastName: 'hassan'),
      );
      addTearDown(container.dispose);

      await _settle(container, tester);

      expect(container.read(currentUserInitialsProvider), equals('AH'));
    });

    testWidgets('falls back to email initial when name is absent',
        (tester) async {
      final authUser = MockUser(
        uid: 'u3',
        email: 'zaid@nexus.app',
      );
      final container = _container(
        authUser: authUser,
        firestoreUser: _userModel(),
      );
      addTearDown(container.dispose);

      await _settle(container, tester);

      expect(container.read(currentUserInitialsProvider), equals('Z'));
    });

    test(
        'returns "?" when firstName and lastName are both empty and no auth user',
        () {
      final container = _emptyContainer();
      addTearDown(container.dispose);
      expect(container.read(currentUserInitialsProvider), equals('?'));
    });
  });
}
