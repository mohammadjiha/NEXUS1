import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../main.dart' as app_main;
import '../../core/utils/role_utils.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/auth/presentation/screens/forgot_phone_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_gym_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/verify_phone_2fa_screen.dart';
import '../../features/coach/presentation/screens/coach_dashboard_screen.dart';
import '../../features/coach/presentation/screens/coach_monitoring_screen.dart';
import '../../features/coach/presentation/screens/coach_notifications_view.dart';
import '../../features/coach/presentation/screens/coach_player_detail_screen.dart';
import '../../features/coach/presentation/screens/members_management_screen.dart';
import '../../features/gym/models/exercise_model.dart';
import '../../features/gym/presentation/screens/exercise_details_screen.dart';
import '../../features/onboarding/views/onboarding_view.dart';
import '../../features/onboarding/views/user_goal_onboarding_screen.dart';
import '../../features/payment/presentation/screens/payment_screen.dart';
import '../../features/plan/presentation/screens/favorites_screen.dart';
import '../../features/player/presentation/screens/player_dashboard_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profile_settings_screen.dart';
import '../../features/smart_workout/models/routine_model.dart';
import '../../features/smart_workout/presentation/screens/active_session_screen.dart';
import '../../features/smart_workout/presentation/screens/exercise_selection_screen.dart';
import '../../features/smart_workout/presentation/screens/quick_log_screen.dart';
import '../../features/smart_workout/presentation/screens/routine_overview_screen.dart';
import '../../features/super_admin/presentation/screens/super_admin_dashboard_screen.dart';
import '../../features/user/models/user_model.dart';
import '../../features/user/presentation/screens/account_frozen_screen.dart';
import '../../features/user/presentation/screens/account_suspended_screen.dart';
import '../../features/user/presentation/screens/gym_inactive_screen.dart';

/// يستمع لتغييرات حالة المصادقة ويُخطر GoRouter بإعادة التقييم
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    try {
      _role = app_main.globalSharedPrefs.getString('user_role');
    } catch (_) {}

    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        // ── Stamp lastLogin once per app session (covers session restores) ──
        if (!_sessionLastLoginDone) {
          _sessionLastLoginDone = true;
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lastLogin': FieldValue.serverTimestamp()})
              .ignore(); // fire-and-forget — never blocks the router
        }

        _roleSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
              final data = doc.data();
              final newRole       = data?['role'] as String?;
              final newTempFlag   = data?['temporaryPasswordSet'] as bool? ?? false;
              final newGymId      = (data?['gymId'] as String?)?.trim();
              final newSuspended  = data?['isActive'] == false;
              final newFrozen     = data?['isFrozen'] as bool? ?? false;

              // ── Start watching gym doc when gymId is known/changed ─────────
              if (newGymId != null &&
                  newGymId.isNotEmpty &&
                  newGymId != _currentGymId) {
                _currentGymId = newGymId;
                _gymSub?.cancel();
                _gymSub = FirebaseFirestore.instance
                    .collection('gyms')
                    .doc(newGymId)
                    .snapshots()
                    .listen((gymDoc) {
                      final isActive = gymDoc.data()?['isActive'];
                      final nowInactive = isActive == false;
                      if (nowInactive != _gymInactive) {
                        _gymInactive = nowInactive;
                        notifyListeners();
                      }
                    });
              }

              bool changed = false;

              if (_role != newRole) {
                _role = newRole;
                if (newRole != null) {
                  try {
                    app_main.globalSharedPrefs.setString('user_role', newRole);
                  } catch (_) {}
                }
                changed = true;
              }

              if (_temporaryPasswordSet != newTempFlag) {
                _temporaryPasswordSet = newTempFlag;
                changed = true;
              }

              // ── 2FA: check for phone on first Firestore snapshot after login
              if (_freshLoginPending) {
                _freshLoginPending = false;
                final phone = data?['phone'] as String?;
                if (phone != null && phone.trim().isNotEmpty) {
                  _needsPhone2FA = true;
                  changed = true;
                }
              }

              // ── Suspend / Freeze — only apply to player role ──────────────
              final isPlayerRole = newRole?.toLowerCase() == 'player';
              if (isPlayerRole) {
                if (newSuspended != _userSuspended) {
                  _userSuspended = newSuspended;
                  changed = true;
                }
                if (newFrozen != _userFrozen) {
                  _userFrozen = newFrozen;
                  changed = true;
                }
              }

              if (changed) notifyListeners();
            });
        notifyListeners();
      } else {
        _roleSub?.cancel();
        _gymSub?.cancel();
        _gymSub = null;
        _currentGymId = null;
        _sessionLastLoginDone = false; // reset so next sign-in stamps again
        if (_role != null ||
            _temporaryPasswordSet ||
            _needsPhone2FA ||
            _freshLoginPending ||
            _gymInactive) {
          _role = null;
          _temporaryPasswordSet = false;
          _needsPhone2FA = false;
          _freshLoginPending = false;
          _gymInactive   = false;
          _userSuspended = false;
          _userFrozen    = false;
          try {
            app_main.globalSharedPrefs.remove('user_role');
          } catch (_) {}
          notifyListeners();
        }
      }
    });
  }

  late final StreamSubscription<User?> _sub;
  StreamSubscription<DocumentSnapshot>? _roleSub;
  StreamSubscription<DocumentSnapshot>? _gymSub;
  String? _role;
  String? _currentGymId;
  bool _temporaryPasswordSet = false;
  bool _gymInactive    = false;
  bool _userSuspended  = false;
  bool _userFrozen     = false;

  /// Tracks whether we have already stamped lastLogin for this app session.
  /// Prevents repeated writes when the Firestore snapshot stream re-fires.
  bool _sessionLastLoginDone = false;

  // ── 2FA state ────────────────────────────────────────────────────────────
  /// Set to true just before signIn() is called so the auth-state listener
  /// knows this is a fresh login requiring phone verification.
  bool _freshLoginPending = false;

  /// True after a successful login when the user still needs to pass the 2FA
  /// OTP step. Cleared by [markPhone2FADone].
  bool _needsPhone2FA = false;

  bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;
  String? get role => _role;
  bool get needsPhone2FA => _needsPhone2FA;
  bool get gymInactive   => _gymInactive;
  bool get userSuspended => _userSuspended;
  bool get userFrozen    => _userFrozen;

  /// Call this immediately before signIn() to arm the 2FA trigger.
  void prepareFreshLogin() {
    _freshLoginPending = true;
  }

  /// Called by VerifyPhone2FAScreen after OTP is confirmed.
  void markPhone2FADone() {
    _needsPhone2FA = false;
    notifyListeners();
  }

  /// Called immediately after ChangePasswordScreen clears the temporary
  /// password flag so GoRouter does not bounce back to /change_password while
  /// the Firestore snapshot is still catching up.
  void markPasswordChangeDone() {
    if (_temporaryPasswordSet) {
      _temporaryPasswordSet = false;
      notifyListeners();
    }
  }

  /// True while the signed-in player still has the coach-assigned temp password.
  bool get mustChangePassword => _temporaryPasswordSet;

  @override
  void dispose() {
    _sub.cancel();
    _roleSub?.cancel();
    _gymSub?.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthChangeNotifier();

// ── Package-level 2FA helpers (used by LoginScreen & VerifyPhone2FAScreen) ──

/// Arm the 2FA trigger — call this immediately before signIn().
void prepareLogin2FA() => _authNotifier.prepareFreshLogin();

/// True when a fresh login is waiting for phone OTP confirmation.
bool get isLogin2FAPending => _authNotifier.needsPhone2FA;

/// Mark 2FA as complete — router will then allow navigation to dashboard.
void completeLogin2FA() => _authNotifier.markPhone2FADone();

/// Mark the required password change as complete before navigating to OTP.
void completeRequiredPasswordChange() => _authNotifier.markPasswordChangeDone();

/// Current role from the auth notifier (used by VerifyPhone2FAScreen).
String? getAuthRole() => _authNotifier.role;

/// المسارات المحمية — تتطلب تسجيل الدخول
const _protectedPaths = {'/dashboard', '/coach_dashboard'};

/// المسارات التي يجب تجاوزها إذا كان المستخدم مسجّلاً
const _authPaths = {'/onboarding', '/onboarding_gym', '/login', '/signup'};

CustomTransitionPage<T> _buildPageWithFastFade<T>(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/onboarding',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final isAuthenticated = _authNotifier.isAuthenticated;
    final loc = state.matchedLocation;
    final mustChangePassword = _authNotifier.mustChangePassword;

    // ── 0. Gym inactive — redirect to inactive screen ─────────────────────────
    if (isAuthenticated && _authNotifier.gymInactive && loc != '/gym_inactive') {
      return '/gym_inactive';
    }

    // ── 0a. Player suspended ────────────────────────────────────────────────────
    if (isAuthenticated && _authNotifier.userSuspended &&
        loc != '/account_suspended') {
      return '/account_suspended';
    }

    // ── 0b. Player frozen ──────────────────────────────────────────────────────
    if (isAuthenticated && _authNotifier.userFrozen &&
        loc != '/account_frozen') {
      return '/account_frozen';
    }

    // ── 1. Force password change — blocks all routes until completed ──────────
    // If the signed-in player still has a coach-assigned temporary password,
    // redirect every route except /change_password to that screen.
    if (isAuthenticated && mustChangePassword && loc != '/change_password') {
      return '/change_password';
    }

    // ── 1.5. Force 2FA phone verification after login ─────────────────────────
    // Admin / owner / gymAdmin bypass 2FA — they go straight to the dashboard.
    if (isAuthenticated && _authNotifier.needsPhone2FA && loc != '/phone_2fa') {
      final role2fa = _authNotifier.role?.toLowerCase();
      final isAdminRole = role2fa == AppRole.admin ||
          role2fa == AppRole.owner ||
          role2fa == AppRole.gymAdmin;
      if (!isAdminRole) return '/phone_2fa';
    }

    // ── 2. Unauthenticated trying to access a protected path ─────────────────
    if (!isAuthenticated && _protectedPaths.contains(loc)) {
      return '/onboarding';
    }

    // ── 3. Authenticated (password OK) on an auth/onboarding path ────────────
    if (isAuthenticated && !mustChangePassword && _authPaths.contains(loc)) {
      final role = _authNotifier.role?.toLowerCase();
      if (role == null) return null; // Wait for role snapshot

      if (AppRole.isSuperAdmin(role)) return '/super_admin';
      if (role == AppRole.admin || role == AppRole.owner || role == AppRole.gymAdmin) {
        return '/admin';
      }
      return AppRole.isPrivileged(role) ? '/coach_dashboard' : '/dashboard';
    }

    if (isAuthenticated && loc == '/dashboard') {
      final role = _authNotifier.role?.toLowerCase();
      if (AppRole.isSuperAdmin(role)) return '/super_admin';
      if (role == AppRole.admin || role == AppRole.owner || role == AppRole.gymAdmin) {
        return '/admin';
      }
      if (AppRole.isPrivileged(role)) {
        return '/coach_dashboard';
      }
    }

    return null; // no redirect needed
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const OnboardingView()),
    ),
    GoRoute(
      path: '/account_suspended',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const AccountSuspendedScreen()),
    ),
    GoRoute(
      path: '/account_frozen',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const AccountFrozenScreen()),
    ),
    GoRoute(
      path: '/gym_inactive',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const GymInactiveScreen()),
    ),
    GoRoute(
      path: '/change_password',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const ChangePasswordScreen()),
    ),
    GoRoute(
      path: '/onboarding_goal',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const UserGoalOnboardingScreen()),
    ),
    GoRoute(
      path: '/onboarding_gym',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const OnboardingGymScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _buildPageWithFastFade(
        state,
        LoginScreen(initialEmail: state.uri.queryParameters['email']),
      ),
    ),
    GoRoute(
      path: '/forgot_phone',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const ForgotPhoneScreen()),
    ),
    GoRoute(
      path: '/phone_2fa',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const VerifyPhone2FAScreen()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const SignupScreen()),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const PlayerDashboardScreen()),
    ),
    GoRoute(
      path: '/coach_dashboard',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const CoachDashboardScreen()),
    ),
    GoRoute(
      path: '/admin',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const AdminDashboardScreen()),
    ),
    GoRoute(
      path: '/super_admin',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const SuperAdminDashboardScreen()),
    ),
    GoRoute(
      path: '/coach_player_detail',
      pageBuilder: (context, state) {
        final extra = state.extra;
        if (extra is UserModel) {
          return _buildPageWithFastFade(
            state,
            CoachPlayerDetailScreen(player: extra),
          );
        }
        final playerName = extra as String? ?? 'Player';
        return _buildPageWithFastFade(
          state,
          CoachPlayerDetailScreen(playerName: playerName),
        );
      },
    ),
    GoRoute(
      path: '/quick-log',
      pageBuilder: (context, state) => _buildPageWithFastFade(
        state,
        QuickLogScreen(restrictedCategory: state.extra as String?),
      ),
    ),
    GoRoute(
      path: '/exercise_details',
      pageBuilder: (context, state) {
        final exercise = state.extra as ExerciseModel;
        return _buildPageWithFastFade(
          state,
          ExerciseDetailsScreen(exercise: exercise),
        );
      },
    ),
    GoRoute(
      path: '/active-session',
      pageBuilder: (context, state) {
        if (state.extra is Map<String, dynamic>) {
          final extra = state.extra as Map<String, dynamic>;
          final routine = extra['routine'] as RoutineModel;
          final isViewOnly = extra['isViewOnly'] as bool? ?? false;
          final scheduledDay = extra['scheduledDay'] as String?;
          return _buildPageWithFastFade(
            state,
            ActiveSessionScreen(
              routine: routine,
              isViewOnly: isViewOnly,
              scheduledDay: scheduledDay,
            ),
          );
        } else {
          final routine = state.extra as RoutineModel;
          return _buildPageWithFastFade(
            state,
            ActiveSessionScreen(routine: routine),
          );
        }
      },
    ),
    GoRoute(
      path: '/routine_overview',
      pageBuilder: (context, state) => _buildPageWithFastFade(
        state,
        RoutineOverviewScreen(routine: state.extra as RoutineModel),
      ),
    ),
    GoRoute(
      path: '/exercise_selection',
      pageBuilder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return _buildPageWithFastFade(
          state,
          ExerciseSelectionScreen(
            routine: data['routine'] as RoutineModel,
            exerciseIndex: data['exerciseIndex'] as int,
          ),
        );
      },
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const ProfileScreen()),
    ),
    GoRoute(
      path: '/favorites',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const FavoritesScreen()),
    ),
    GoRoute(
      path: '/profile_settings',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const ProfileSettingsScreen()),
    ),
    GoRoute(
      path: '/payment',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const PaymentScreen()),
    ),
    GoRoute(
      path: '/members_management',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const MembersManagementScreen()),
    ),
    GoRoute(
      path: '/coach_notifications',
      pageBuilder: (context, state) =>
          _buildPageWithFastFade(state, const CoachNotificationsView()),
    ),
    GoRoute(
      path: '/coach_monitoring',
      pageBuilder: (context, state) {
        final player = state.extra as UserModel?;
        return _buildPageWithFastFade(
          state,
          CoachMonitoringScreen(player: player),
        );
      },
    ),
  ],
);
