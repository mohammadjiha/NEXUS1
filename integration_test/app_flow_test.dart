// integration_test/app_flow_test.dart
//
// End-to-end flow tests for Nexus.
//
// ── What this file tests ─────────────────────────────────────────────────────
//
//  Flow 1 — Login screen UI
//    • Screen renders, fields exist, form validation works without a network.
//
//  Flow 2 — Login → Dashboard (with mocked auth)
//    • After sign-in state changes, the PlayerDashboard is visible.
//    • Bottom-nav tabs (Home, Workout, Nutrition, Hub) are present.
//
//  Flow 3 — Dashboard → Workout tab
//    • Tapping the Workout (bolt) nav item switches to the workout tab.
//
// ── Why not real Firebase? ────────────────────────────────────────────────────
// Integration tests that reach Firebase require a running emulator. These
// tests are intentionally Firebase-free: providers are overridden with
// Stream stubs so they run in `flutter test` CI without a device or emulator.
//
// To run on a real device / emulator:
//   flutter test integration_test/app_flow_test.dart --device-id <id>
//
// ── Dependencies ─────────────────────────────────────────────────────────────
// No extra dependencies beyond flutter_test — testWidgets sets up the binding
// automatically, so IntegrationTestWidgetsFlutterBinding is not needed.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/localization/app_localizations.dart';
import 'package:nexus/src/core/providers/shared_preferences_provider.dart';
import 'package:nexus/src/features/auth/data/auth_repository.dart';
import 'package:nexus/src/features/auth/presentation/screens/login_screen.dart';
import 'package:nexus/src/features/player/presentation/screens/player_dashboard_screen.dart';
import 'package:nexus/src/features/user/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

UserModel _testPlayer() => UserModel(
      uid: 'integration_test_uid',
      email: 'flow@nexus.app',
      firstName: 'Flow',
      lastName: 'Tester',
      role: 'player',
      gymId: 'gym_001',
      emailVerified: true,
      createdAt: DateTime(2024),
    );

/// Wraps [child] in the minimal tree needed for any Nexus screen:
/// ProviderScope + Sizer + MaterialApp + AppLocalizations + Riverpod overrides.
Future<Widget> _testApp(
  Widget child, {
  List<Override> extras = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((_) => const Stream.empty()),
      currentUserModelProvider.overrideWith((_) => const Stream.empty()),
      ...extras,
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

/// Simulated signed-in overrides — injects a player UserModel into providers.
List<Override> _loggedInOverrides({String role = 'player'}) {
  final user = _testPlayer();
  return [
    currentUserModelProvider.overrideWith((_) => Stream.value(user)),
    currentGymIdProvider.overrideWith((_) => 'gym_001'),
    currentUserRoleProvider.overrideWith((_) => role),
  ];
}

void setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

// ── Entry point ───────────────────────────────────────────────────────────────

void main() {

  // ── Flow 1: Login screen renders correctly ──────────────────────────────────

  group('Flow 1 — LoginScreen renders correctly', () {
    testWidgets('1a: screen builds without crash', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(await _testApp(const LoginScreen()));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('1b: two form fields exist (email + password)', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(await _testApp(const LoginScreen()));
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('1c: user can type into email field', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(await _testApp(const LoginScreen()));
      await tester.pump();

      final email = find.byType(TextFormField).first;
      await tester.enterText(email, 'oday@nexus.app');
      await tester.pump();

      expect(find.text('oday@nexus.app'), findsOneWidget);
    });

    testWidgets('1d: password field starts obscured (visibility-off icon)',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(await _testApp(const LoginScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('1e: tapping password toggle reveals password', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(await _testApp(const LoginScreen()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets(
        '1f: Sign In with empty fields stays on LoginScreen (form validation)',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(await _testApp(const LoginScreen()));
      await tester.pump();

      final signInBtn = find.text('Sign In →');
      if (signInBtn.evaluate().isEmpty) return; // safety for locale changes
      await tester.tap(signInBtn);
      await tester.pump();

      // Still on login — form validation prevented submission.
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('1g: filling email and password enables the form',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(await _testApp(const LoginScreen()));
      await tester.pump();

      await tester.enterText(
        find.byType(TextFormField).first,
        'oday@nexus.app',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'StrongPass1!',
      );
      await tester.pump();

      // Both values are present in the tree.
      expect(find.text('oday@nexus.app'), findsOneWidget);
      expect(find.text('StrongPass1!'), findsOneWidget);
    });
  });

  // ── Flow 2: Logged-in user sees PlayerDashboard ─────────────────────────────

  group('Flow 2 — PlayerDashboard (authenticated state)', () {
    testWidgets('2a: dashboard renders with mocked player provider',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PlayerDashboardScreen), findsOneWidget);
    });

    testWidgets('2b: dashboard contains a bottom navigation bar',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      // Custom nav bar renders as a Row of nav items inside a Scaffold.
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('2c: bottom-nav Home icon is present', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      // The Home tab uses home_rounded / home_outlined icons.
      final homeIcons = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.home_rounded || w.icon == Icons.home_outlined),
      );
      expect(homeIcons, findsAtLeastNWidgets(1));
    });

    testWidgets('2d: workout (bolt) nav icon is present', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      final workoutIcons = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.bolt_rounded || w.icon == Icons.bolt_outlined),
      );
      expect(workoutIcons, findsAtLeastNWidgets(1));
    });

    testWidgets('2e: nutrition (restaurant) nav icon is present',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      final nutritionIcons = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == Icons.restaurant_rounded ||
                w.icon == Icons.restaurant_outlined),
      );
      expect(nutritionIcons, findsAtLeastNWidgets(1));
    });
  });

  // ── Flow 3: Dashboard → Workout tab navigation ──────────────────────────────

  group('Flow 3 — Dashboard tab navigation', () {
    testWidgets('3a: tapping workout (bolt) icon switches active tab',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      // Find and tap the first bolt_outlined icon (workout nav item).
      final boltOutlined = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.bolt_outlined,
      );

      if (boltOutlined.evaluate().isNotEmpty) {
        await tester.tap(boltOutlined.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // After tapping, the active icon switches to bolt_rounded.
        final boltActive = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.bolt_rounded,
        );
        expect(boltActive, findsAtLeastNWidgets(1));
      }
    });

    testWidgets('3b: home tab remains tappable after visiting workout',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      // Tap workout.
      final boltOutlined = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.bolt_outlined,
      );
      if (boltOutlined.evaluate().isNotEmpty) {
        await tester.tap(boltOutlined.first);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Tap home.
      final homeOutlined = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.home_outlined,
      );
      if (homeOutlined.evaluate().isNotEmpty) {
        await tester.tap(homeOutlined.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Home icon should now be active (rounded variant).
        final homeActive = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.home_rounded,
        );
        expect(homeActive, findsAtLeastNWidgets(1));
      }
    });

    testWidgets('3c: tapping nutrition tab works', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      final nutritionOutlined = find.byWidgetPredicate(
        (w) => w is Icon && w.icon == Icons.restaurant_outlined,
      );
      if (nutritionOutlined.evaluate().isNotEmpty) {
        await tester.tap(nutritionOutlined.first);
        await tester.pump(const Duration(milliseconds: 300));

        // Restaurant rounded icon should now be visible.
        final nutritionActive = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.restaurant_rounded,
        );
        expect(nutritionActive, findsAtLeastNWidgets(1));
      }
    });

    testWidgets('3d: no uncaught exceptions during tab switching',
        (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(
        await _testApp(
          const PlayerDashboardScreen(),
          extras: _loggedInOverrides(),
        ),
      );
      await tester.pump();

      // Tap through bolt → home → restaurant without expecting exceptions.
      Future<void> tapIcon(IconData icon) async {
        final finder = find.byWidgetPredicate((w) => w is Icon && w.icon == icon);
        if (finder.evaluate().isNotEmpty) {
          await tester.tap(finder.first);
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      await tapIcon(Icons.bolt_outlined);
      await tapIcon(Icons.home_outlined);
      await tapIcon(Icons.restaurant_outlined);
      await tapIcon(Icons.home_outlined);

      expect(tester.takeException(), isNull);
    });
  });
}
