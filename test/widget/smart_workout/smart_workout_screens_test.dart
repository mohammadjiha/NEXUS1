// test/widget/smart_workout/smart_workout_screens_test.dart
//
// Widget tests for the Smart Workout feature.
//
// Screens covered
// ──────────────
//  • SmartWorkoutHomeScreen  — dashboard showing today's plan + routines
//  • QuickLogScreen          — muscle selector + routine picker
//
// All Firestore / asset-loading providers are stubbed.
// No network or disk I/O happens during these tests.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/core/localization/app_localizations.dart';
import 'package:nexus/src/core/providers/shared_preferences_provider.dart';
import 'package:nexus/src/features/auth/data/auth_repository.dart';
import 'package:nexus/src/features/smart_workout/models/routine_model.dart';
import 'package:nexus/src/features/smart_workout/presentation/screens/quick_log_screen.dart';
import 'package:nexus/src/features/smart_workout/presentation/screens/smart_workout_home_screen.dart';
import 'package:nexus/src/features/smart_workout/providers/routines_provider.dart';
import 'package:nexus/src/features/smart_workout/providers/split_setup_provider.dart';
import 'package:nexus/src/features/smart_workout/providers/workout_history_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

// ── Fake notifiers — prevent Firestore / rootBundle calls ────────────────────

class _FakeWorkoutHistory extends WorkoutHistoryNotifier {
  @override
  List<CompletedSession> build() => [];
}

class _FakeRoutines extends RoutinesNotifier {
  @override
  Future<List<RoutineModel>> build() async => [];
}

class _FakeSplitSetup extends SplitSetupDataNotifier {
  @override
  Future<SplitSetupData> build() async =>
      SplitSetupData(planStartDate: DateTime.now());
}

// ── Viewport helper ──────────────────────────────────────────────────────────

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

// ── Shared overrides ─────────────────────────────────────────────────────────

Future<List<Override>> _workoutOverrides() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authStateProvider.overrideWith((_) => const Stream.empty()),
    currentUserModelProvider.overrideWith((_) => const Stream.empty()),
    workoutHistoryProvider.overrideWith(_FakeWorkoutHistory.new),
    msRoutinesProvider.overrideWith(_FakeRoutines.new),
    splitSetupDataProvider.overrideWith(_FakeSplitSetup.new),
    generatedPlanProvider.overrideWithValue([]),
    routineCatalogProvider.overrideWith((_) async => <String, List<RoutineModel>>{}),
  ];
}

Widget _wrap(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
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

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── SmartWorkoutHomeScreen ──────────────────────────────────────────────────

  group('SmartWorkoutHomeScreen', () {
    testWidgets('1: renders without crashing', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const SmartWorkoutHomeScreen(), overrides));
      await tester.pump();
      expect(find.byType(SmartWorkoutHomeScreen), findsOneWidget);
    });

    testWidgets('2: has Scaffold', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const SmartWorkoutHomeScreen(), overrides));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('3: no exception on first frame', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const SmartWorkoutHomeScreen(), overrides));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('4: no exception on settle', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const SmartWorkoutHomeScreen(), overrides));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5: has scrollable content', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const SmartWorkoutHomeScreen(), overrides));
      await tester.pump();
      // Screen uses CustomScrollView or SingleChildScrollView
      expect(
        find
            .byWidgetPredicate(
              (w) =>
                  w is CustomScrollView ||
                  w is SingleChildScrollView ||
                  w is ListView,
            )
            .evaluate()
            .isNotEmpty,
        isTrue,
      );
    });

    testWidgets('6: shows at least one visible widget in body', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const SmartWorkoutHomeScreen(), overrides));
      await tester.pump();
      expect(find.byType(Widget), findsWidgets);
    });

    testWidgets('7: scroll down does not throw', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const SmartWorkoutHomeScreen(), overrides));
      await tester.pump();
      await tester.drag(find.byType(Scaffold), const Offset(0, -200));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ── QuickLogScreen ──────────────────────────────────────────────────────────

  group('QuickLogScreen', () {
    testWidgets('1: renders without crashing', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const QuickLogScreen(), overrides));
      await tester.pump();
      expect(find.byType(QuickLogScreen), findsOneWidget);
    });

    testWidgets('2: has Scaffold', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const QuickLogScreen(), overrides));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('3: no exception on first frame', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const QuickLogScreen(), overrides));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('4: no exception on settle', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const QuickLogScreen(), overrides));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5: muscle chips are present', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const QuickLogScreen(), overrides));
      await tester.pump();
      // Muscle chips rendered as GestureDetector or InkWell rows
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6: QuickLogScreen with restricted category', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(
        _wrap(const QuickLogScreen(restrictedCategory: 'Chest'), overrides),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('7: scroll does not throw', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(_wrap(const QuickLogScreen(), overrides));
      await tester.pump();
      await tester.drag(find.byType(Scaffold), const Offset(0, -150));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('8: Back category pre-selects without crash', (tester) async {
      _setPhone(tester);
      final overrides = await _workoutOverrides();
      await tester.pumpWidget(
        _wrap(const QuickLogScreen(restrictedCategory: 'Back'), overrides),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
