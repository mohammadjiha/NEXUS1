// test/widget/coach/coach_dashboard_test.dart
//
// Widget tests for CoachDashboardScreen.
// Requires privileged role override — uses GoRouter stub.
//
// Note: CoachDashboardScreen uses a CUSTOM bottom nav bar (not
// BottomNavigationBar). It renders Icons.home_rounded, Icons.people_alt_rounded,
// Icons.chat_bubble_rounded via GestureDetector rows — we find them by icon.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus/core/localization/app_localizations.dart';
import 'package:nexus/src/core/providers/shared_preferences_provider.dart';
import 'package:nexus/src/features/auth/data/auth_repository.dart';
import 'package:nexus/src/features/coach/data/coach_repository.dart';
import 'package:nexus/src/features/coach/presentation/screens/coach_dashboard_screen.dart';
import 'package:nexus/src/features/user/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../helpers/test_helpers.dart';

// Minimal router so GoRouter navigation in tests doesn't throw
final _testRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const CoachDashboardScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (_, __) => const Scaffold(body: Text('player')),
    ),
  ],
);

UserModel _fakeCoach({String role = 'coach', String? gymId}) => UserModel(
      uid: 'coach_uid',
      email: 'coach@nexus.app',
      firstName: 'Coach',
      lastName: 'Test',
      role: role,
      gymId: gymId,
      emailVerified: true,
      createdAt: DateTime(2024),
    );

Widget _wrapApp(SharedPreferences prefs,
    {String role = 'coach', String? gymId}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((_) => const Stream.empty()),
      currentUserModelProvider.overrideWith(
        (_) => Stream.value(_fakeCoach(role: role, gymId: gymId)),
      ),
      currentGymIdProvider.overrideWith((_) => gymId),
      currentUserRoleProvider.overrideWith((_) => role),
      // Stub Firestore stream inside CoachHomeView/PlayersView/MessagesView
      coachMembersProvider.overrideWith((_) => const Stream.empty()),
    ],
    child: Sizer(
      builder: (_, __, ___) => MaterialApp.router(
        routerConfig: _testRouter,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
      ),
    ),
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('CoachDashboardScreen', () {
    testWidgets('renders without crashing for coach role', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(_wrapApp(prefs, gymId: 'gym_001'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows home nav icon (custom nav bar)', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(_wrapApp(prefs, gymId: 'gym_001'));
      // The custom nav bar renders unconditionally on the first frame.
      // A single pump is sufficient — no stream settlement needed.
      await tester.pump();

      // Custom nav bar renders Icons.home_rounded as first tab
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    });

    testWidgets('does not crash for owner role', (tester) async {
      setPhoneViewport(tester);
      await tester.pumpWidget(_wrapApp(prefs, role: 'owner', gymId: 'gym_002'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}

