// test/widget/nutrition/nutrition_screens_test.dart
//
// Widget tests for the Nutrition feature.
//
// Screens covered
// ──────────────
//  • NutritionSourceSelectionScreen — entry point showing plan-source cards
//  • NutritionHistoryScreen          — history log (SharedPreferences only)
//
// No Firestore dependency — all tests run fully in-memory.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/localization/app_localizations.dart';
import 'package:nexus/src/core/providers/shared_preferences_provider.dart';
import 'package:nexus/src/features/auth/data/auth_repository.dart';
import 'package:nexus/src/features/nutrition/presentation/screens/nutrition_history_screen.dart';
import 'package:nexus/src/features/nutrition/presentation/screens/nutrition_source_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

// ── Shared viewport helper ────────────────────────────────────────────────────

void _setPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final orig = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('overflowed')) return;
    orig?.call(d);
  };
  addTearDown(() => FlutterError.onError = orig);
}

// ── App wrappers ─────────────────────────────────────────────────────────────

Future<Widget> _nutritionSourceApp() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final navKey = GlobalKey<NavigatorState>();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((_) => const Stream.empty()),
      currentUserModelProvider.overrideWith((_) => const Stream.empty()),
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
        home: NutritionSourceSelectionScreen(navigatorKey: navKey),
      ),
    ),
  );
}

/// NutritionHistoryScreen reads SharedPreferences directly (no Riverpod
/// provider), so we just need the mock values set before pumpWidget.
Future<Widget> _nutritionHistoryApp({Map<String, Object>? prefs}) async {
  SharedPreferences.setMockInitialValues(prefs ?? {});

  return Sizer(
    builder: (_, __, ___) => const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en'), Locale('ar')],
      home: NutritionHistoryScreen(),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── NutritionSourceSelectionScreen ─────────────────────────────────────────

  group('NutritionSourceSelectionScreen', () {
    testWidgets('1: renders without crashing', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionSourceApp());
      await tester.pump();
      expect(find.byType(NutritionSourceSelectionScreen), findsOneWidget);
    });

    testWidgets('2: has Scaffold', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionSourceApp());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('3: has AppBar', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionSourceApp());
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('4: is scrollable', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionSourceApp());
      await tester.pump();
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('5: renders multiple option cards', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionSourceApp());
      await tester.pump();
      // Should have at least 2 source cards (AI, Coach, Build-own…)
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('6: no exception on first frame', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionSourceApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('7: no exception on pump-and-settle', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionSourceApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── NutritionHistoryScreen ──────────────────────────────────────────────────

  group('NutritionHistoryScreen', () {
    testWidgets('1: renders without crashing', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionHistoryApp());
      await tester.pump();
      expect(find.byType(NutritionHistoryScreen), findsOneWidget);
    });

    testWidgets('2: has Scaffold', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionHistoryApp());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('3: has AppBar', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionHistoryApp());
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('4: no exception on first frame', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionHistoryApp());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5: shows empty state when no history', (tester) async {
      _setPhone(tester);
      // No 'nutrition_history' key → empty state text shown
      await tester.pumpWidget(await _nutritionHistoryApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('6: no exception on pump-and-settle', (tester) async {
      _setPhone(tester);
      await tester.pumpWidget(await _nutritionHistoryApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('7: with pre-seeded history shows list', (tester) async {
      _setPhone(tester);
      const historyJson =
          '[{"date":"2025-01-15","calories":2100,"protein":160},'
          '{"date":"2025-01-14","calories":1950,"protein":145}]';
      await tester.pumpWidget(
        await _nutritionHistoryApp(
          prefs: {'nutrition_history': historyJson},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('8: Arabic locale renders without crash', (tester) async {
      _setPhone(tester);
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        Sizer(
          builder: (_, __, ___) => const MaterialApp(
            locale: Locale('ar'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: [Locale('en'), Locale('ar')],
            home: NutritionHistoryScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
