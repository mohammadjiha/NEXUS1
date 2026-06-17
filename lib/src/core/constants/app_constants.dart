// lib/src/core/constants/app_constants.dart
//
// Single source of truth for magic numbers used across the Nexus app.
// Import this file instead of scattering literal durations / limits everywhere.

/// Animation and transition durations.
abstract final class AppDurations {
  /// Standard page / widget transition — 300 ms.
  static const standard = Duration(milliseconds: 300);

  /// Fast in/out animation — 200 ms.
  static const fast = Duration(milliseconds: 200);

  /// Very fast micro-interaction — 150 ms.
  static const veryFast = Duration(milliseconds: 150);

  /// Scroll-to animation — 500 ms.
  static const scroll = Duration(milliseconds: 500);

  /// Debounce delay for search inputs — 400 ms.
  static const searchDebounce = Duration(milliseconds: 400);

  /// Spinning dumbbell loader rotation — 700 ms.
  static const loaderSpin = Duration(milliseconds: 700);

  /// Trophy / celebration animation — 800 ms.
  static const trophy = Duration(milliseconds: 800);

  /// Short delay for async UX feedback — 1 s.
  static const shortDelay = Duration(seconds: 1);

  /// Trophy dialog auto-dismiss — 3 s.
  static const trophyAutoDismiss = Duration(seconds: 3);

  /// Email resend cooldown — 45 s.
  static const emailResendCooldown = Duration(seconds: 45);

  /// Warning banner auto-hide — 4 s.
  static const warningAutoDismiss = Duration(seconds: 4);

  /// Delay before deep-link routing after cold start — 600 ms.
  /// Gives GoRouter time to finish bootstrapping before we call go().
  static const coldStartRouteDelay = Duration(milliseconds: 600);

  /// AI analysis mock-step delay — 500 ms.
  static const aiStepDelay = Duration(milliseconds: 500);
}

/// Firestore query limits — prevent unbounded reads.
abstract final class AppLimits {
  /// Maximum notifications fetched per user session.
  static const notifications = 50;

  /// Maximum food search results returned per query.
  static const foodSearch = 10;

  /// Maximum leaderboard entries shown.
  static const leaderboard = 20;

  /// Maximum community posts per fetch.
  static const communityPosts = 20;

  /// Maximum challenges per fetch.
  static const challenges = 20;
}

/// GoRouter route paths — single source of truth for navigation.
abstract final class AppRoutes {
  static const splash = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const dashboard = '/dashboard';
  static const coachDash = '/coach_dashboard';
  static const admin = '/admin';
  static const profile = '/profile';
  static const settings = '/profile_settings';
  static const quickLog = '/quick-log';
  static const activeSession = '/active-session';
  static const exercises = '/exercise_selection';
  static const coachNotifs = '/coach_notifications';
  static const coachMonitor = '/coach_monitoring';
  static const members = '/members_management';
}
