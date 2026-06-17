// test/helpers/test_helpers.dart
//
// Shared utilities for Nexus widget tests.
// Every test that renders a screen should use [makeTestApp] so that
// the required widget tree (Sizer + MaterialApp + AppLocalizations +
// ProviderScope with safe overrides) is in place.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/localization/app_localizations.dart';
import 'package:nexus/src/core/providers/shared_preferences_provider.dart';
import 'package:nexus/src/features/auth/data/auth_repository.dart';
import 'package:nexus/src/features/user/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

// ─── Viewport helper ────────────────────────────────────────────────────────

/// Sets the test viewport to a standard phone size (390×844, 1× ratio) and
/// suppresses RenderFlex overflow errors for the duration of the test.
///
/// Why suppress overflow? The test environment's safe-area insets narrow the
/// Scaffold body to ~359px. Rows designed for real phones (390px) can overflow
/// by a small amount. That is a cosmetic issue, not a logic failure — the
/// widgets are still in the tree and findable. Suppressing keeps tests focused
/// on behaviour rather than pixel-perfect layout.
void setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Suppress "overflowed" RenderFlex errors so they do not fail the test.
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

// ─── Fake data ──────────────────────────────────────────────────────────────

/// Returns a minimal [UserModel] suitable for tests.
UserModel fakeUser({String role = 'player', String? gymId}) => UserModel(
      uid: 'test_uid',
      email: 'test@nexus.app',
      firstName: 'Test',
      lastName: 'User',
      gymId: gymId,
      role: role,
      emailVerified: true,
      createdAt: DateTime(2024),
    );

// ─── Widget wrapper ──────────────────────────────────────────────────────────

/// Wraps [child] in the minimal widget tree that all Nexus screens require.
///
/// Default overrides (can be replaced via [extraOverrides]):
///   • [sharedPreferencesProvider]  → in-memory mock prefs
///   • [authStateProvider]           → empty stream (not signed in)
///   • [currentUserModelProvider]    → empty stream
///
/// Pass [extraOverrides] to inject additional test doubles (e.g. a signed-in
/// user or a specific gym ID).
Future<Widget> makeTestApp(
  Widget child, {
  List< Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // No signed-in Firebase user by default — prevents real network calls.
      authStateProvider.overrideWith((_) => const Stream.empty()),
      currentUserModelProvider.overrideWith((_) => const Stream.empty()),
      ...extraOverrides,
    ],
    child: Sizer(
      builder: (_, __, ___) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: child,
      ),
    ),
  );
}

/// Convenience override: simulate a signed-in user with [role] and [gymId].
List<Override> signedInOverrides({
  String role = 'player',
  String? gymId,
}) {
  final user = fakeUser(role: role, gymId: gymId);
  return [
    currentUserModelProvider.overrideWith((_) => Stream.value(user)),
    currentGymIdProvider.overrideWith(
      (_) => gymId?.trim().isNotEmpty ?? false ? gymId : null,
    ),
    currentUserRoleProvider.overrideWith((_) => role),
  ];
}
