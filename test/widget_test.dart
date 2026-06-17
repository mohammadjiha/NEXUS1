// test/widget_test.dart
//
// Nexus — widget smoke-tests.
//
// Run:  flutter test
//
// Strategy
// --------
// • Each test pumps a single screen in isolation inside a lightweight
//   ProviderScope that replaces every Firebase-backed provider with a
//   safe stub.  No real network traffic is made.
// • Tests verify that key UI elements render correctly and that the
//   widget tree builds without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/localization/app_localizations.dart';
import 'package:nexus/src/core/providers/shared_preferences_provider.dart';
import 'package:nexus/src/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:nexus/src/features/admin/providers/admin_provider.dart';
import 'package:nexus/src/features/auth/data/auth_repository.dart';
import 'package:nexus/src/features/auth/presentation/screens/login_screen.dart';
import 'package:nexus/src/features/auth/presentation/screens/signup_screen.dart';
import 'package:nexus/src/features/onboarding/views/onboarding_view.dart';
import 'package:nexus/src/features/user/presentation/screens/account_suspended_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'helpers/test_helpers.dart';

void main() {
  // ── 1. Onboarding / splash screen ─────────────────────────────────────────

  group('OnboardingView', () {
    testWidgets('renders the NEXUS brand name', (tester) async {
      final app = await makeTestApp(const OnboardingView());
      await tester.pumpWidget(app);
      await tester.pump(); // let localizations settle

      expect(find.text('NEXUS'), findsOneWidget);
    });

    testWidgets('renders the subtitle tagline', (tester) async {
      final app = await makeTestApp(const OnboardingView());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(
        find.text('Your intelligent gym & fitness platform'),
        findsOneWidget,
      );
    });

    testWidgets('renders the Get Started button', (tester) async {
      final app = await makeTestApp(const OnboardingView());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('Get Started'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsWidgets);
    });
  });

  // ── 2. Login screen ────────────────────────────────────────────────────────

  group('LoginScreen', () {
    testWidgets('renders welcome heading', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('renders EMAIL ADDRESS and PASSWORD labels', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Labels are rendered via label.toUpperCase() → "EMAIL ADDRESS" / "PASSWORD"
      expect(find.text('EMAIL ADDRESS'), findsOneWidget);
      expect(find.text('PASSWORD'), findsOneWidget);
    });

    testWidgets('renders Google and Apple sign-in buttons', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
    });

    testWidgets('renders Forgot password link', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('renders Create account link', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('password visibility toggle icon is present', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Uses visibility_off_outlined (not _rounded) — eye-off = obscured by default
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  // ── 3. Signup screen ───────────────────────────────────────────────────────

  group('SignupScreen', () {
    testWidgets('renders Create account heading', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('renders FIRST and LAST name labels on step 1', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Labels are uppercased via label.toUpperCase()
      expect(find.text('FIRST'), findsOneWidget);
      expect(find.text('LAST'), findsOneWidget);
    });
  });

  // ── 4. Account suspended screen ───────────────────────────────────────────

  group('AccountSuspendedScreen', () {
    testWidgets('renders block icon and heading', (tester) async {
      final app = await makeTestApp(const AccountSuspendedScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
      expect(find.text('Account Suspended'), findsOneWidget);
    });

    testWidgets('renders the Logout button', (tester) async {
      final app = await makeTestApp(const AccountSuspendedScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('Logout'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  // ── 5. Admin dashboard screen ─────────────────────────────────────────────

  group('AdminDashboardScreen', () {
    testWidgets(
      'shows "No gym assigned." when gymId is null',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authStateProvider.overrideWith((_) => const Stream.empty()),
              currentUserModelProvider.overrideWith((_) => const Stream.empty()),
              currentGymIdProvider.overrideWith((_) => null),
              currentUserRoleProvider.overrideWith((_) => 'player'),
            ],
            child: _localizedApp(const AdminDashboardScreen()),
          ),
        );
        await tester.pump();

        expect(find.text('No gym assigned.'), findsOneWidget);
      },
    );

    testWidgets(
      'shows FAB when role is privileged (coach) and gymId is set',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authStateProvider.overrideWith((_) => const Stream.empty()),
              currentUserModelProvider.overrideWith((_) => const Stream.empty()),
              currentGymIdProvider.overrideWith((_) => 'gym_test'),
              currentUserRoleProvider.overrideWith((_) => 'coach'),
              // Stub Firestore streams — no real network calls
              gymMembersStreamProvider.overrideWith(
                (_) => const Stream.empty(),
              ),
              gymInvitationsStreamProvider.overrideWith(
                (_) => const Stream.empty(),
              ),
            ],
            child: _localizedApp(const AdminDashboardScreen()),
          ),
        );
        await tester.pump();

        // coach is in AppRole.privileged → FAB must be present
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );
  });
}

// ─── Shared widget wrapper ────────────────────────────────────────────────────

/// Wraps [child] in Sizer + MaterialApp with English locale and all
/// required localization delegates.  Used when the caller controls the
/// [ProviderScope] directly (e.g. to set fine-grained overrides).
Widget _localizedApp(Widget child) {
  return Sizer(
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
  );
}
