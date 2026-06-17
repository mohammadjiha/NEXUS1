// test/widget/community/community_screen_test.dart
//
// Widget tests for CommunityScreen.
// All Firestore family streams are replaced with stubs — no network.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/localization/app_localizations.dart';
import 'package:nexus/src/features/auth/data/auth_repository.dart';
import 'package:nexus/src/features/community/data/repositories/community_repository.dart';
import 'package:nexus/src/features/community/presentation/screens/community_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

Widget _buildApp({String role = 'player', String? gymId}) {
  SharedPreferences.setMockInitialValues({});

  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((_) => const Stream.empty()),
      currentUserModelProvider.overrideWith((_) => const Stream.empty()),
      currentGymIdProvider.overrideWith((_) => gymId),
      currentUserRoleProvider.overrideWith((_) => role),
      // Family stream stubs — no Firestore calls
      postsStreamProvider.overrideWith((ref, arg) => const Stream.empty()),
      challengesStreamProvider.overrideWith((ref, arg) => const Stream.empty()),
      leaderboardStreamProvider.overrideWith((ref, arg) => const Stream.empty()),
    ],
    child: Sizer(
      builder: (_, __, ___) => const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ar')],
        home: CommunityScreen(),
      ),
    ),
  );
}

void main() {
  group('CommunityScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(CommunityScreen), findsOneWidget);
    });

    testWidgets('shows FloatingActionButton', (tester) async {
      await tester.pumpWidget(_buildApp(gymId: 'gym_001'));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('shows Scaffold body without error', (tester) async {
      await tester.pumpWidget(_buildApp(gymId: 'gym_001'));
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('does not throw on first frame', (tester) async {
      await tester.pumpWidget(_buildApp(gymId: 'gym_001'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('coach sees FAB without restriction', (tester) async {
      await tester.pumpWidget(_buildApp(role: 'coach', gymId: 'gym_001'));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
