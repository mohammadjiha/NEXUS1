// test/unit/utils/app_constants_test.dart
//
// Unit tests for AppDurations, AppLimits, AppRoutes constants.
//
// These tests guard against accidental changes to timing constants and route
// strings that would silently break animations, debounce logic, or navigation.

import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/core/constants/app_constants.dart';

void main() {
  // ── AppDurations ──────────────────────────────────────────────────────────

  group('AppDurations', () {
    test('standard is 300 ms', () {
      expect(AppDurations.standard, equals(const Duration(milliseconds: 300)));
    });

    test('fast is 200 ms', () {
      expect(AppDurations.fast, equals(const Duration(milliseconds: 200)));
    });

    test('veryFast is 150 ms', () {
      expect(AppDurations.veryFast, equals(const Duration(milliseconds: 150)));
    });

    test('scroll is 500 ms', () {
      expect(AppDurations.scroll, equals(const Duration(milliseconds: 500)));
    });

    test('searchDebounce is 400 ms', () {
      expect(
        AppDurations.searchDebounce,
        equals(const Duration(milliseconds: 400)),
      );
    });

    test('loaderSpin is 700 ms', () {
      expect(
        AppDurations.loaderSpin,
        equals(const Duration(milliseconds: 700)),
      );
    });

    test('trophy is 800 ms', () {
      expect(AppDurations.trophy, equals(const Duration(milliseconds: 800)));
    });

    test('shortDelay is 1 s', () {
      expect(AppDurations.shortDelay, equals(const Duration(seconds: 1)));
    });

    test('trophyAutoDismiss is 3 s', () {
      expect(
        AppDurations.trophyAutoDismiss,
        equals(const Duration(seconds: 3)),
      );
    });

    test('emailResendCooldown is 45 s', () {
      expect(
        AppDurations.emailResendCooldown,
        equals(const Duration(seconds: 45)),
      );
    });

    test('warningAutoDismiss is 4 s', () {
      expect(
        AppDurations.warningAutoDismiss,
        equals(const Duration(seconds: 4)),
      );
    });

    test('coldStartRouteDelay is 600 ms', () {
      expect(
        AppDurations.coldStartRouteDelay,
        equals(const Duration(milliseconds: 600)),
      );
    });

    test('aiStepDelay is 500 ms', () {
      expect(
        AppDurations.aiStepDelay,
        equals(const Duration(milliseconds: 500)),
      );
    });

    // Relative ordering: fast animations should be shorter than slow ones.
    test('veryFast < fast < standard < scroll', () {
      expect(
        AppDurations.veryFast < AppDurations.fast &&
            AppDurations.fast < AppDurations.standard &&
            AppDurations.standard < AppDurations.scroll,
        isTrue,
      );
    });

    test('shortDelay < trophyAutoDismiss < warningAutoDismiss', () {
      expect(
        AppDurations.shortDelay < AppDurations.trophyAutoDismiss &&
            AppDurations.trophyAutoDismiss < AppDurations.warningAutoDismiss,
        isTrue,
      );
    });

    test('emailResendCooldown is longer than any UI animation', () {
      expect(
        AppDurations.emailResendCooldown > AppDurations.warningAutoDismiss,
        isTrue,
      );
    });
  });

  // ── AppLimits ─────────────────────────────────────────────────────────────

  group('AppLimits', () {
    test('notifications limit is 50', () {
      expect(AppLimits.notifications, equals(50));
    });

    test('foodSearch limit is 10', () {
      expect(AppLimits.foodSearch, equals(10));
    });

    test('leaderboard limit is 20', () {
      expect(AppLimits.leaderboard, equals(20));
    });

    test('communityPosts limit is 20', () {
      expect(AppLimits.communityPosts, equals(20));
    });

    test('challenges limit is 20', () {
      expect(AppLimits.challenges, equals(20));
    });

    // Sanity: all limits should be positive integers.
    test('all limits are positive', () {
      expect(AppLimits.notifications, greaterThan(0));
      expect(AppLimits.foodSearch, greaterThan(0));
      expect(AppLimits.leaderboard, greaterThan(0));
      expect(AppLimits.communityPosts, greaterThan(0));
      expect(AppLimits.challenges, greaterThan(0));
    });

    // foodSearch is deliberately smaller (autocomplete results) than leaderboard.
    test('foodSearch limit is less than leaderboard limit', () {
      expect(AppLimits.foodSearch, lessThan(AppLimits.leaderboard));
    });
  });

  // ── AppRoutes ─────────────────────────────────────────────────────────────

  group('AppRoutes', () {
    test('splash starts with "/"', () {
      expect(AppRoutes.splash, startsWith('/'));
    });

    test('login is "/login"', () {
      expect(AppRoutes.login, equals('/login'));
    });

    test('signup is "/signup"', () {
      expect(AppRoutes.signup, equals('/signup'));
    });

    test('dashboard is "/dashboard"', () {
      expect(AppRoutes.dashboard, equals('/dashboard'));
    });

    test('coachDash is "/coach_dashboard"', () {
      expect(AppRoutes.coachDash, equals('/coach_dashboard'));
    });

    test('admin is "/admin"', () {
      expect(AppRoutes.admin, equals('/admin'));
    });

    test('all routes are non-empty strings starting with "/"', () {
      final routes = [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.dashboard,
        AppRoutes.coachDash,
        AppRoutes.admin,
        AppRoutes.profile,
        AppRoutes.settings,
        AppRoutes.quickLog,
        AppRoutes.activeSession,
        AppRoutes.exercises,
        AppRoutes.coachNotifs,
        AppRoutes.coachMonitor,
        AppRoutes.members,
      ];
      for (final r in routes) {
        expect(r, isNotEmpty, reason: 'route should not be empty');
        expect(r, startsWith('/'), reason: '$r should start with /');
      }
    });

    test('all routes are unique', () {
      final routes = [
        AppRoutes.splash,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.dashboard,
        AppRoutes.coachDash,
        AppRoutes.admin,
        AppRoutes.profile,
        AppRoutes.settings,
        AppRoutes.quickLog,
        AppRoutes.activeSession,
        AppRoutes.exercises,
        AppRoutes.coachNotifs,
        AppRoutes.coachMonitor,
        AppRoutes.members,
      ];
      expect(routes.toSet().length, equals(routes.length));
    });

    test('login and signup are different routes', () {
      expect(AppRoutes.login, isNot(equals(AppRoutes.signup)));
    });

    test('player dashboard and coach dashboard are different routes', () {
      expect(AppRoutes.dashboard, isNot(equals(AppRoutes.coachDash)));
    });
  });
}
