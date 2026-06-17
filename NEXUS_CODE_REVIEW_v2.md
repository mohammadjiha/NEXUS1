# Nexus Flutter App — Comprehensive Code Review

**Reviewer:** Senior Mobile Application Architect / Flutter Security Specialist  
**Date:** 2026-06-12  
**Project:** Nexus — Fitness & Gym Management App  
**Stack:** Flutter 3.x, Riverpod 3.x, GoRouter 17.x, Firebase (Auth, Firestore, Storage, Remote Config), Gemini AI  
**Files Reviewed:** 55+ Dart source files across all feature modules

---

## Executive Summary

Nexus is a well-structured fitness application with a clean feature-first architecture and good use of Riverpod and GoRouter patterns. The UI is polished, localization is thorough, and the AI features (AI coach, food scanner, InBody analysis) are innovative.

However, several **critical and high-severity issues** must be resolved before production release. The most alarming findings are:

1. **Firebase API keys hardcoded in version-controlled source** (firebase_options.dart)
2. **Duplicate `authStateProvider` declarations** creating a silent Riverpod conflict
3. **DevicePreview's `appBuilder` left active in production builds**, leaking debug tooling overhead
4. **No pagination on community Firestore streams** — unbounded reads will scale catastrophically
5. **Client-side-only role checks** with no Firestore security rules enforcement visible in code
6. Multiple god-files exceeding 1,600 lines with severe SOLID violations
7. Side effects (`addPostFrameCallback` calling `context.go()`) executed inside `build()` methods

**Overall Score: 5.5 / 10**

The architecture skeleton is sound, but production-safety, scalability, and security gaps require immediate attention.

---

## 1. Security Vulnerabilities

### 1.1 Hardcoded Firebase API Keys in Source Control

| Severity | File | Line |
|---|---|---|
| **CRITICAL** | `lib/firebase_options.dart` | 28–68 |

**Problem:** Firebase API keys, app IDs, iOS bundle IDs, and OAuth client IDs for web, Android, and iOS are all committed in plain text to `firebase_options.dart`. This file is almost always committed to source control. Anyone with repo access can extract these credentials. While Firebase web API keys are designed to be public when protected by Firestore security rules, the **iOS client ID (`iosClientId`) and the OAuth serverClientId in `auth_repository.dart`** are more sensitive. More critically, if Firestore security rules are permissive (a common mistake), this fully exposes the database.

Additionally, `auth_repository.dart` line 17–18 hardcodes the Google OAuth Web Client ID:
```dart
// auth_repository.dart
const _kGoogleWebClientId =
    '266704213953-26b9088f9s27ues94pobpf2mes4otogv.apps.googleusercontent.com';
```
The TODO comment says "move to --dart-define before public release" but this is not done.

**Fix:**
```dart
// Step 1: Add to .gitignore
// firebase_options.dart  (regenerate from CI/CD)
// google-services.json
// GoogleService-Info.plist

// Step 2: Use --dart-define for sensitive IDs
// In auth_repository.dart:
const _kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);

// Step 3: Move firebase_options.dart to a CI-generated artifact, not source control.
// Use: flutterfire configure --project=nexus-90e55 as a CI step.
```

**Action Required:** Rotate all Firebase API keys immediately. Enable Firebase App Check. Audit and tighten Firestore security rules.

---

### 1.2 Duplicate `authStateProvider` — Silent Riverpod Conflict

| Severity | Files | Lines |
|---|---|---|
| **CRITICAL** | `lib/src/features/auth/data/auth_repository.dart:31` and `lib/src/features/coach/providers/notifications_provider.dart:41` | Both declare `final authStateProvider = StreamProvider<User?>` |

**Problem:** Two top-level `authStateProvider` declarations exist in different files. Dart does not error on this at compile time because they are in different libraries. Whichever is imported first in a given file's import chain wins. Code in `notifications_provider.dart` that calls `ref.watch(authStateProvider)` may be watching a *different* provider instance than code importing from `auth_repository.dart`. This creates subtle, hard-to-reproduce bugs where auth state changes do not propagate as expected, and Riverpod's dependency graph becomes inconsistent.

**Fix:**
```dart
// 1. Delete the duplicate in notifications_provider.dart
// Remove lines 41-43 from notifications_provider.dart

// 2. Add the correct import:
import '../../auth/data/auth_repository.dart'; // use the canonical provider

// 3. In notifications_provider.dart, use the imported one:
final notificationsProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final user = ref.watch(authStateProvider).value; // from auth_repository
  // ...
});
```

---

### 1.3 DevicePreview Active in Production Builds

| Severity | File | Lines |
|---|---|---|
| **HIGH** | `lib/main.dart` | 85–88 |

**Problem:** `DevicePreview.appBuilder` is called unconditionally in the `builder` of `MaterialApp.router`, even though the `DevicePreview` wrapper itself is commented out. This means the DevicePreview overlay infrastructure is still injected into every production build, adding unnecessary overhead (extra widget rebuilds, overlay layers, initialization code). The `device_preview` package itself is also a `dependencies:` entry — it should be in `dev_dependencies`.

```dart
// main.dart — CURRENT (problematic)
builder: (context, child) {
  return GestureDetector(
    // ...
    child: DevicePreview.appBuilder(   // ← runs even in prod
      context,
      child ?? const SizedBox.shrink(),
    ),
  );
},
```

**Fix:**
```dart
// Move device_preview to dev_dependencies in pubspec.yaml

// In main.dart:
builder: (context, child) {
  return GestureDetector(
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    behavior: HitTestBehavior.translucent,
    child: Directionality(
      textDirection: appLocale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: child ?? const SizedBox.shrink(),
    ),
  );
},
```

---

### 1.4 Client-Side-Only Role Enforcement

| Severity | Files |
|---|---|
| **HIGH** | `app_router.dart`, `admin_dashboard_screen.dart`, `profile_screen.dart`, `player_dashboard_screen.dart` |

**Problem:** Role-based access control is enforced only in the Flutter client. The GoRouter `redirect` checks `_authNotifier.role` (sourced from SharedPreferences + Firestore snapshot), and feature visibility is toggled via `role == 'coach' || role == 'admin' || ...`. A malicious user who tampers with the local SharedPreferences value `user_role` could potentially bypass route guards, because the router reads the cached role on startup before the Firestore snapshot arrives. Critical admin operations like `inviteMember`, `revokeInvitation`, `updateMemberRole`, and `updateMemberStatus` call Firestore directly from the client.

**Fix:**
```dart
// 1. In Firestore Security Rules (firestore.rules), enforce server-side:
//    Example:
//    match /gyms/{gymId}/members/{userId} {
//      allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role
//                   in ['admin', 'owner', 'gym_admin']
//                   && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.gymId == gymId;
//    }

// 2. In the router, always verify from Firestore, not SharedPreferences:
//    The current code reads _role from globalSharedPrefs at startup — valid for UX
//    but must never be the sole security gate.

// 3. Use Firebase App Check to block non-app clients from hitting the project.
```

---

### 1.5 Sensitive Health Data Stored Unencrypted in SharedPreferences

| Severity | Files |
|---|---|
| **HIGH** | `lib/src/features/profile/providers/body_metrics_provider.dart`, `lib/src/features/coaching/providers/ai_coach_plan_provider.dart`, `lib/src/features/coaching/data/chat_repository.dart` |

**Problem:** Health metrics (weight, body fat, muscle mass, BMR, visceral fat, metabolic age), AI nutrition plans, and chat message caches are stored in plaintext SharedPreferences under keys like `local_body_metrics_<uid>`, `ai_coach_plan_<date>`, and `chat_messages_<chatId>`. On Android, SharedPreferences maps to an XML file in the app's data directory. On a rooted device or via ADB backup on unprotected apps, this data is trivially accessible. Health data has regulatory implications (HIPAA, GDPR) depending on jurisdiction.

**Fix:**
```dart
// Use flutter_secure_storage for sensitive fields, or
// use the encrypt package to AES-encrypt before writing to SharedPreferences.

// pubspec.yaml:
//   flutter_secure_storage: ^9.0.0

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _secureStorage = const FlutterSecureStorage();

// For body metrics:
await _secureStorage.write(
  key: 'local_body_metrics_${user.uid}',
  value: jsonEncode(normalizedMetrics.toJson()),
);
final localData = await _secureStorage.read(key: 'local_body_metrics_${user.uid}');
```

---

### 1.6 Google Logo Loaded from External Network Without Cache

| Severity | File | Line |
|---|---|---|
| **MEDIUM** | `lib/src/features/auth/presentation/screens/login_screen.dart` | 446 |

**Problem:** The Google sign-in button loads the Google logo from `https://img.icons8.com/color/48/000000/google-logo.png` at runtime with `Image.network()`. This creates a network dependency for a core UI element, fails offline, and leaks app usage data (page views) to a third-party CDN. The same issue exists in `signup_screen.dart`.

**Fix:**
```dart
// Add google_logo.png to assets/images/ and update pubspec.yaml assets
// Then in login_screen.dart:
icon: Image.asset(
  'assets/images/google_logo.png',
  width: 5.w,
  height: 5.w,
),
```

---

## 2. Architecture & Code Quality

### 2.1 God Files — Extreme Bloat Violating Single Responsibility

| Severity | File | Lines |
|---|---|---|
| **HIGH** | `community_screen.dart` | 1,743 |
| **HIGH** | `coach_monitoring_screen.dart` | 1,667 |
| **HIGH** | `active_session_screen.dart` | 1,602 |
| **HIGH** | `build_my_own_screen.dart` | 1,596 |
| **HIGH** | `profile_screen.dart` | 1,578 |
| **HIGH** | `coach_add_player_screen.dart` | 1,562 |
| **HIGH** | `player_dashboard_screen.dart` | 1,511 |
| **HIGH** | `signup_screen.dart` | 1,461 |
| **HIGH** | `coach_player_detail_screen.dart` | 1,426 |
| **HIGH** | `split_setup_wizard_screen.dart` | 1,364 |
| **HIGH** | `admin_dashboard_screen.dart` | 1,228 |

**Problem:** 11 files exceed 1,000 lines, with the largest at 1,743 lines. These files contain business logic, UI composition, state management, and network calls all mixed together. This makes testing impossible without running the full widget tree, increases compile times, causes massive merge conflicts, and is a maintenance nightmare.

**Fix (example — community_screen.dart):**
```dart
// Split into focused files:
// community_feed_tab.dart        — posts list + stream
// community_challenges_tab.dart  — challenge cards
// community_leaderboard_tab.dart — leaderboard list
// community_post_card.dart       — individual post widget
// community_create_post_sheet.dart — bottom sheet
// community_screen.dart          — thin orchestrator (< 100 lines)

// General rule: each file = one widget or one provider, max ~300 lines.
```

---

### 2.2 Side Effects Inside `build()` Method

| Severity | File | Lines |
|---|---|---|
| **HIGH** | `lib/src/features/player/presentation/screens/player_dashboard_screen.dart` | 92–99 |

**Problem:** `WidgetsBinding.instance.addPostFrameCallback` is called directly inside `build()`, scheduling navigation side effects on every rebuild. This means `context.go('/account_suspended')` can be triggered multiple times if the widget rebuilds before the navigation completes.

```dart
// player_dashboard_screen.dart — CURRENT (problematic)
Widget build(BuildContext context, WidgetRef ref) {
  // ...
  WidgetsBinding.instance.addPostFrameCallback((_) {   // ← inside build()!
    if (userModel != null && !userModel.isActive) {
      context.go('/account_suspended');
    }
  });
```

**Fix:**
```dart
// Use ref.listen instead — it fires only on state changes, not every rebuild:
ref.listen<AsyncValue<UserModel?>>(currentUserModelProvider, (previous, next) {
  final model = next.asData?.value;
  if (model != null && !model.isActive && context.mounted) {
    context.go('/account_suspended');
  }
});
// Remove the addPostFrameCallback block from build()
```

---

### 2.3 Role String Duplication — Magic Strings Throughout Codebase

| Severity | Files |
|---|---|
| **MEDIUM** | `app_router.dart`, `login_screen.dart`, `admin_dashboard_screen.dart`, `profile_screen.dart`, `player_dashboard_screen.dart` |

**Problem:** The role check `role == 'coach' || role == 'admin' || role == 'owner' || role == 'gym_admin'` is copy-pasted in at least 8 locations. Adding a new privileged role requires modifying 8+ files. A typo in one location creates a silent security gap.

**Fix:**
```dart
// Create lib/src/core/utils/role_utils.dart:
class AppRole {
  static const player = 'player';
  static const coach = 'coach';
  static const admin = 'admin';
  static const owner = 'owner';
  static const gymAdmin = 'gym_admin';

  static const privileged = {coach, admin, owner, gymAdmin};

  static bool isPrivileged(String? role) => privileged.contains(role);
}

// Usage everywhere:
if (AppRole.isPrivileged(role)) { /* ... */ }
```

---

### 2.4 `profileUserProvider` — FutureProvider with Multiple `ref.watch` Calls Doing Firestore Fetch

| Severity | File |
|---|---|
| **MEDIUM** | `lib/src/features/profile/providers/profile_provider.dart` |

**Problem:** `profileUserProvider` is a `FutureProvider` that `ref.watch`es `authStateProvider`, `currentUserFirstNameProvider`, `currentUserInitialsProvider`, `bodyMetricsProvider`, `goalSelectionProvider`, `workoutHistoryProvider`, `exerciseHistoryProvider`, and `currentUserModelProvider` — and then performs a Firestore `.get()` call to resolve the gym name. Every time any of these providers changes state, the entire FutureProvider re-runs and re-fetches Firestore. This is extremely expensive.

**Fix:**
```dart
// Convert to a StreamProvider or use select() to narrow dependencies.
// Extract the Firestore gym-name lookup into its own cached provider:

final gymNameProvider = FutureProvider.family<String, String>((ref, gymId) async {
  final doc = await FirebaseFirestore.instance.collection('gyms').doc(gymId).get();
  return doc.data()?['name'] as String? ?? gymId;
});

// In profileUserProvider, only watch the truly needed upstream providers.
```

---

### 2.5 `_AuthChangeNotifier` is a Global Singleton Never Disposed

| Severity | File | Line |
|---|---|---|
| **MEDIUM** | `lib/src/core/router/app_router.dart` | 78 |

**Problem:** `final _authNotifier = _AuthChangeNotifier()` creates a module-level singleton. The `_AuthChangeNotifier` holds active `StreamSubscription`s to both Firebase Auth state changes and a Firestore user document snapshot. Because it is module-level, it is never disposed, and the Firestore real-time listener `_roleSub` to `users/{uid}` runs indefinitely — even when the user is on screens that don't need role data.

**Fix:**
```dart
// Make it a Riverpod provider so the framework manages its lifecycle:
final authChangeNotifierProvider = ChangeNotifierProvider<_AuthChangeNotifier>((ref) {
  final notifier = _AuthChangeNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

// Then in the GoRouter instantiation, use ref.watch(authChangeNotifierProvider)
// inside a provider that creates the router.
```

---

## 3. Performance & Speed

### 3.1 `IndexedStack` Eagerly Builds All Dashboard Tabs

| Severity | File | Line |
|---|---|---|
| **HIGH** | `lib/src/features/player/presentation/screens/player_dashboard_screen.dart` | 107–115 |

**Problem:** Both `PlayerDashboardScreen` and `CoachDashboardScreen` use `IndexedStack` with 5 children: `_buildDashboardView`, `AiCoachFlowCoordinator`, `HubScreen`, `NutritionFlowCoordinator`, `CommunityScreen`. `IndexedStack` builds **all children immediately** and keeps them all in memory. This means on app launch, the AI coach flow, the community Firestore stream, the nutrition screen, the hub, and the main dashboard are all constructed simultaneously. This causes severe startup jank and unnecessary resource consumption.

**Fix:**
```dart
// Option A: Lazy-initialize with null-coalescing cache:
final List<Widget?> _cachedScreens = List.filled(5, null);

Widget _getScreen(int index) {
  return _cachedScreens[index] ??= switch (index) {
    0 => _buildDashboardView(...),
    1 => const AiCoachFlowCoordinator(),
    2 => const HubScreen(),
    3 => const NutritionFlowCoordinator(),
    4 => const CommunityScreen(),
    _ => const SizedBox.shrink(),
  };
}

// In build():
body: _getScreen(ref.watch(bottomNavIndexProvider)),

// Option B: Use PageView with physics: const NeverScrollableScrollPhysics()
// and lazy page building — Flutter only builds visible pages.
```

---

### 3.2 `FutureProvider` for Exercises Reloads JSON on Every Rebuild

| Severity | File |
|---|---|
| **MEDIUM** | `lib/src/features/gym/data/exercises_repository.dart` |

**Problem:** `allExercisesProvider` is a bare `FutureProvider` (not `.autoDispose`, not `.family`) that calls `rootBundle.loadString('assets/data/all_exercises.json')` and JSON-decodes it every time the provider is re-created. Because it has no `keepAlive` and no `autoDispose`, it rebuilds on every provider container refresh. The exercises JSON file is large (it contains all muscle groups and exercises).

**Fix:**
```dart
// Use keepAlive to cache the result for the app's lifetime:
final allExercisesProvider = FutureProvider<List<MuscleGroupModel>>((ref) async {
  ref.keepAlive(); // Never dispose — exercises are static data
  final repository = ref.watch(exercisesRepositoryProvider);
  return repository.loadExercises();
});
```

---

### 3.3 `build_my_own_screen.dart` Uses `ListView` Instead of `ListView.builder`

| Severity | File | Lines |
|---|---|---|
| **MEDIUM** | `lib/src/features/nutrition/presentation/screens/build_my_own_screen.dart` | 754, 902, 1191 |

**Problem:** Three `ListView(children: [...])` instances are used inside `build_my_own_screen.dart`. Since this file is 1,596 lines, these lists likely contain a significant number of items (meal cards, food items, macro sliders). `ListView` with a `children` list eagerly builds all children at once. On a meal plan with many items this causes frame drops.

**Fix:**
```dart
// Replace ListView with ListView.builder for any dynamic list:
ListView.builder(
  itemCount: meals.length,
  itemBuilder: (context, index) {
    return _buildMealCard(meals[index]);
  },
),
```

---

### 3.4 Camera Resolution Set to `high` During ML Kit Pose Detection

| Severity | File | Line |
|---|---|---|
| **MEDIUM** | `lib/src/features/coaching/presentation/screens/ai_coach_live_screen.dart` | 60 |

**Problem:** The camera is initialized with `ResolutionPreset.high` for the pose detection image stream. ML Kit's pose detection doesn't require high resolution — `medium` (typically 640x480) achieves the same accuracy with dramatically less memory bandwidth and CPU consumption. High resolution camera frames are large buffers that must be transferred to ML Kit on every frame.

**Fix:**
```dart
_cameraController = CameraController(
  targetCamera,
  ResolutionPreset.medium, // sufficient for ML Kit pose detection
  enableAudio: false,
  imageFormatGroup: Platform.isAndroid
      ? ImageFormatGroup.nv21
      : ImageFormatGroup.bgra8888,
);
```

---

### 3.5 `recoveryScoreProvider` Called With Argument Inside `build()` for Dashboard Preview

| Severity | File | Line |
|---|---|---|
| **LOW** | `lib/src/features/player/presentation/screens/player_dashboard_screen.dart` | ~295 |

**Problem:** `ref.watch(recoveryScoreProvider('Chest'))` is called inside the `build()` method of `PlayerDashboardScreen` just to populate the AI coach preview card text. This registers a watch on a family provider, re-running the build every time the recovery score for "Chest" changes. The coach card text is purely cosmetic and doesn't need live updates.

**Fix:**
```dart
// Use ref.read for one-time values in static UI elements:
final chestRecovery = ref.read(recoveryScoreProvider('Chest'));
```

---

## 4. Battery & Resource Management

### 4.1 Signup Screen Timer — Clock Updating Every Second

| Severity | File | Line |
|---|---|---|
| **MEDIUM** | `lib/src/features/auth/presentation/screens/signup_screen.dart` | 135 |

**Problem:** A `Timer.periodic(const Duration(seconds: 1), ...)` is started in `initState()` to update `_now = DateTime.now()` and call `setState()` every second — used to display a live clock on one of the signup steps. This causes a full widget rebuild of the entire 1,461-line `SignupScreen` every second the user is on this screen. The Timer is correctly cancelled in `dispose()`, but the rebuild cost is significant.

**Fix:**
```dart
// Option A: Only update the clock widget, not the whole screen.
// Extract the clock display into its own StatefulWidget:
class _LiveClock extends StatefulWidget { ... }
// Its setState only rebuilds the small clock widget, not the parent.

// Option B: Remove the live clock entirely — it adds no fitness value.
```

---

### 4.2 Community Leaderboard — Unbounded Firestore Stream Fetching All Gym Users

| Severity | File | Lines |
|---|---|---|
| **HIGH** | `lib/src/features/community/data/repositories/community_repository.dart` | 124–155 |

**Problem:** `getLeaderboardStream` fetches **all users** in a gym with `where('gymId', isEqualTo: gymId).snapshots()` — no `.limit()` applied. For a gym with 1,000 members, this downloads 1,000 Firestore documents on every real-time update. Additionally, the Dart-side `.where((user) => user.role == 'player')` and `.sort()` are applied after fetching all documents. This is a scalability disaster — cost, latency, and memory all grow linearly with gym size.

**Fix:**
```dart
Stream<List<UserModel>> getLeaderboardStream(String gymId, {int limit = 50}) {
  return _firestore
      .collection('users')
      .where('gymId', isEqualTo: gymId)
      .where('role', isEqualTo: 'player') // filter server-side
      .orderBy('trophies', descending: true) // order server-side
      .limit(limit) // paginate
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['uid'] ??= doc.id;
            return UserModel.fromMap(data);
          })
          .toList());
}
```
Also add a Firestore composite index on `(gymId, role, trophies DESC)`.

---

### 4.3 Community Posts — No Pagination on Firestore Stream

| Severity | File | Lines |
|---|---|---|
| **HIGH** | `lib/src/features/community/data/repositories/community_repository.dart` | 16–28 |

**Problem:** `getPostsStream(gymId)` fetches **all community posts** for a gym in a single real-time Firestore stream with no `.limit()`. As a gym accumulates posts over months, every new post notification will re-download the entire collection. With images referenced in posts, this also means large amounts of metadata are re-processed on every update.

**Fix:**
```dart
Stream<List<Post>> getPostsStream(String gymId, {int limit = 20}) {
  return _firestore
      .collection('communityPosts')
      .where('gymId', isEqualTo: gymId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList());
}
// Implement cursor-based pagination (startAfterDocument) for "load more".
```

---

### 4.4 PoseDetector Not Closed on Camera Flip

| Severity | File | Lines |
|---|---|---|
| **MEDIUM** | `lib/src/features/coaching/presentation/screens/ai_coach_live_screen.dart` | 163–175 |

**Problem:** When `_flipCamera()` is called, `_cameraController!.dispose()` is awaited, but `_poseDetector` is not closed before `_initializeCamera()` is called again. The ML Kit `PoseDetector` holds native resources. While `_poseDetector.close()` is correctly called in `dispose()`, flipping the camera mid-session leaves the existing detector running alongside a new camera initialization.

**Fix:**
```dart
Future<void> _flipCamera() async {
  if (_isRecording || _cameraController == null) return;
  setState(() {
    _isBusy = true;
    _cameraDirection = _cameraDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
  });

  await _cameraController!.stopImageStream(); // stop stream before dispose
  await _cameraController!.dispose();
  // _poseDetector can be reused — no need to close and reopen it here
  await _initializeCamera();
  setState(() => _isBusy = false);
}
```

---

### 4.5 `bodyMetricsProvider` Calls `SharedPreferences.getInstance()` in Multiple Locations

| Severity | File |
|---|---|
| **LOW** | `lib/src/features/profile/providers/body_metrics_provider.dart` |

**Problem:** `SharedPreferences.getInstance()` is called in `_loadData()`, `_syncFromFirebase()`, and `_saveData()` — three separate async calls to the SharedPreferences singleton on every metrics operation. While `getInstance()` is cached by the plugin after the first call, each invocation is still an async bridge call. The project already injects `sharedPreferencesProvider` through Riverpod at the app level — use it.

**Fix:**
```dart
class BodyMetricsNotifier extends AsyncNotifier<BodyMetrics> {
  @override
  Future<BodyMetrics> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return BodyMetrics();
    final prefs = ref.watch(sharedPreferencesProvider); // inject once
    return _loadData(user.uid, prefs);
  }

  Future<BodyMetrics> _loadData(String uid, SharedPreferences prefs) async {
    // use prefs directly — no getInstance() needed
    final localData = prefs.getString('local_body_metrics_$uid');
    // ...
  }
}
```

---

## 5. Responsiveness & UX

### 5.1 Missing Retry Mechanism on All AI-Generated Content

| Severity | Files |
|---|---|
| **HIGH** | `ai_coach_plan_provider.dart`, `ai_food_provider.dart`, `ai_coach_provider.dart` |

**Problem:** All AI-powered features (nutrition plan generation, food scanning, video analysis) present an error state if the Gemini API call fails, but provide no retry button or automatic retry with backoff. Network failures are common on mobile (switching between WiFi and cellular, tunnels, brief outages). Users who encounter a Gemini error are stuck until they navigate away and return.

**Fix:**
```dart
// In the error UI of ai_coach_plan_screen.dart:
error: (err, stack) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('Failed to generate plan', style: TextStyle(fontSize: 16.sp)),
      SizedBox(height: 2.h),
      ElevatedButton.icon(
        onPressed: () => ref.refresh(aiCoachPlanProvider), // Riverpod refresh
        icon: const Icon(Icons.refresh),
        label: const Text('Try Again'),
      ),
    ],
  ),
),

// For AsyncNotifier-based providers:
ElevatedButton(
  onPressed: () => ref.read(aiCoachPlanProvider.notifier).refreshPlan(),
  child: const Text('Retry'),
),
```

---

### 5.2 `build_my_own_screen.dart` — `SharedPreferences.getInstance()` Called Inline in `build()` Callbacks

| Severity | File | Lines |
|---|---|---|
| **MEDIUM** | `lib/src/features/nutrition/presentation/screens/build_my_own_screen.dart` | 75, 120, 169, 540 |

**Problem:** Multiple async functions called directly from UI tap handlers use `SharedPreferences.getInstance()` inline inside `onTap` callbacks that are constructed during `build()`. Each of these involves an async round-trip initiated synchronously from a gesture handler. While this doesn't crash, it creates unnecessary latency and bypasses the established `sharedPreferencesProvider` injection pattern.

**Fix:**
```dart
// In the state class, inject SharedPreferences via Riverpod:
// Override in initState or pass through build context:
late SharedPreferences _prefs;

@override
void initState() {
  super.initState();
  SharedPreferences.getInstance().then((p) => _prefs = p);
}
// Or better: use ref.read(sharedPreferencesProvider) if it's a ConsumerStatefulWidget.
```

---

### 5.3 Community Screen Search Button — Non-Functional Placeholder

| Severity | File | Line |
|---|---|---|
| **LOW** | `lib/src/features/community/presentation/screens/community_screen.dart` | ~80 |

**Problem:** The search and notifications icon buttons in the community top bar are built with `_buildIconButton(Icons.search_rounded)` — they have no `onTap` handler, making them completely non-functional. Users tapping these icons get no feedback, which is confusing UX.

**Fix:**
```dart
GestureDetector(
  onTap: () => _showSearchSheet(context),  // implement or show "coming soon" snackbar
  child: _buildIconButton(Icons.search_rounded),
),
```

---

### 5.4 Wearables "Sync Now" Shows Hardcoded Stale Time

| Severity | File | Lines |
|---|---|---|
| **LOW** | `lib/src/features/wearables/presentation/screens/wearables_dashboard_screen.dart` | ~50 |

**Problem:** The "Sync Now" button in the Wearables dashboard shows a SnackBar with the hardcoded string `'sync_now_last_synced_2_min'` (resolved to "Last synced 2 minutes ago"). This is a static string — the actual last sync time is never computed or displayed. This misleads users.

**Fix:**
```dart
// Track last sync time in a StateProvider:
final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

// In the sync button:
onPressed: () async {
  await ref.read(heartRateProvider.future); // trigger refresh
  ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();
},

// In the SnackBar:
final lastSync = ref.read(lastSyncTimeProvider);
final msg = lastSync == null 
    ? 'Syncing...' 
    : 'Last synced ${timeago.format(lastSync)}';
ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
```

---

## 6. Additional Issues (Medium / Low Severity)

### 6.1 `ai_coach_chat_screen.dart` — Chat Messages Stored Only In-Memory

| Severity | File |
|---|---|
| **MEDIUM** | `lib/src/features/coaching/presentation/screens/ai_coach_chat_screen.dart` |

The AI chat session (`_chatSession`) and message list (`_messages`) are stored in widget state. Navigating away and back resets the chat to zero, and users lose their entire conversation. Contrast this with `HumanCoachChatScreen` which has Firestore-backed persistence. The AI chat should persist at minimum to SharedPreferences or Firestore.

---

### 6.2 `notifications_provider.dart` — Notifications Stream Without `.limit()`

| Severity | File |
|---|---|
| **MEDIUM** | `lib/src/features/coach/providers/notifications_provider.dart` |

The `notificationsProvider` stream fetches all notifications for the user without a `.limit()`. Over time, a user could accumulate hundreds of notifications, all streamed in real-time. Add `.limit(50)` and implement "load more" or "mark all read & archive" to bound the query.

---

### 6.3 `currentGymIdProvider` / `currentUserRoleProvider` — Redundant Firestore Reads

| Severity | File |
|---|---|
| **MEDIUM** | `lib/src/features/admin/providers/admin_provider.dart` |

`currentGymIdProvider` and `currentUserRoleProvider` each independently call `repo.getUser(user.uid)` — two Firestore reads for the same document. They should both derive from `currentUserModelProvider` which already fetches and streams this data.

```dart
// Instead of:
final userModel = await repo.getUser(user.uid);
return userModel?.gymId;

// Use:
final userModel = ref.watch(currentUserModelProvider).asData?.value;
return userModel?.gymId;
```

---

### 6.4 AI Prompt Injection — Unvalidated User Context Interpolated Into Prompts

| Severity | File |
|---|---|
| **MEDIUM** | `lib/src/features/coaching/services/ai_coach_service.dart` |

User-controlled data (username, workout names, goal strings) is interpolated directly into Gemini prompts via string interpolation (`$name`, `$userContext`, `${routine.category}`). While the fitness domain narrows the attack surface, a user whose `displayName` contains adversarial text (e.g., `IGNORE PREVIOUS INSTRUCTIONS and...`) could influence AI responses. Input sanitization or prompt delimiters should be used.

```dart
// Wrap user data in structured delimiters:
String contextStr = '''
<user_data>
Name: ${_sanitize(name)}
Goal: ${_sanitize(metrics.goal)}
</user_data>
''';

String _sanitize(String input) => input.replaceAll('<', '').replaceAll('>', '').trim();
```

---

### 6.5 `flutter_blue_plus` Imported But No Bluetooth Usage Found

| Severity | File |
|---|---|
| **LOW** | `pubspec.yaml` |

`flutter_blue_plus: ^1.14.0` is listed as a dependency but no Bluetooth scanning, device connection, or BLE characteristic reads were found in any Dart source file. Unused dependencies bloat APK/IPA size and can trigger unnecessary permission requests on Android.

**Fix:** Remove `flutter_blue_plus` from `pubspec.yaml` unless Bluetooth features are actively planned for the next release cycle.

---

### 6.6 `device_preview` in `dependencies` Instead of `dev_dependencies`

| Severity | File |
|---|---|
| **LOW** | `pubspec.yaml` |

`device_preview: ^1.3.1` is in `dependencies`, meaning it is bundled into production release builds. This package includes significant debug tooling (device frame rendering, toolbar overlays, screenshot functionality). Move it to `dev_dependencies`.

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  device_preview: ^1.3.1  # ← move here
```

---

### 6.7 `SharedPreferences.getInstance()` Called in `ai_coach_plan_provider` Ignoring Injected Prefs

| Severity | File | Lines |
|---|---|---|
| **LOW** | `lib/src/features/coaching/providers/ai_coach_plan_provider.dart` | 23, 199 |

Same pattern as body_metrics_provider — the provider calls `SharedPreferences.getInstance()` directly instead of using the already-initialized `sharedPreferencesProvider` injected at app startup.

---

### 6.8 Error Messages Leak Raw Exception Strings to User

| Severity | Files |
|---|---|
| **LOW** | `human_coach_chat_screen.dart`, `ai_coach_provider.dart`, multiple screens |

Several catch blocks display `e.toString()` directly in SnackBars or error widgets. Raw exception strings can contain internal Firebase project paths, Firestore collection names, or stack traces, which leak implementation details and are confusing to end users.

```dart
// Instead of:
Text('${'failed_to_send_message'.tr(context)}: $e')

// Use a mapping function:
Text(_friendlyError(e, context))

String _friendlyError(Object e, BuildContext ctx) {
  final s = e.toString();
  if (s.contains('network')) return 'network_error'.tr(ctx);
  if (s.contains('permission-denied')) return 'permission_denied'.tr(ctx);
  return 'error_generic'.tr(ctx);
}
```

---

## 7. Prioritized Fix List

Ordered by severity and impact:

| Priority | Severity | Issue | Effort |
|---|---|---|---|
| 1 | CRITICAL | Rotate Firebase API keys; move to CI-generated firebase_options.dart; enable App Check | High |
| 2 | CRITICAL | Fix duplicate `authStateProvider` in `notifications_provider.dart` | Low |
| 3 | CRITICAL | Remove `DevicePreview.appBuilder` from production build path; move to `dev_dependencies` | Low |
| 4 | HIGH | Add Firestore security rules for all write operations (enforce server-side role checks) | High |
| 5 | HIGH | Add pagination (`.limit()`) to community posts, leaderboard, notifications Firestore streams | Medium |
| 6 | HIGH | Replace `IndexedStack` with lazy initialization pattern in both dashboard screens | Medium |
| 7 | HIGH | Move sensitive health data from plain SharedPreferences to `flutter_secure_storage` | Medium |
| 8 | HIGH | Extract god files (community_screen, active_session_screen, build_my_own_screen, player_dashboard) into focused widget files | High |
| 9 | HIGH | Move side effect navigation out of `build()` into `ref.listen` | Low |
| 10 | HIGH | Create `AppRole` utility class to eliminate magic role string duplication | Low |
| 11 | MEDIUM | Add retry buttons to all AI content screens | Low |
| 12 | MEDIUM | Replace `ListView` with `ListView.builder` in build_my_own_screen.dart | Low |
| 13 | MEDIUM | Add input sanitization to Gemini prompt interpolation | Low |
| 14 | MEDIUM | Persist AI chat messages across sessions | Medium |
| 15 | MEDIUM | Downgrade camera resolution from `high` to `medium` in AI coach live screen | Low |
| 16 | MEDIUM | Consolidate `SharedPreferences.getInstance()` calls to use injected `sharedPreferencesProvider` | Low |
| 17 | MEDIUM | Fix community search/notifications buttons to be functional or show "coming soon" | Low |
| 18 | MEDIUM | Add server-side filtering to leaderboard and notifications Firestore queries | Low |
| 19 | LOW | Remove unused `flutter_blue_plus` dependency | Low |
| 20 | LOW | Fix hardcoded "last synced 2 min" string in wearables dashboard | Low |
| 21 | LOW | Replace `Image.network` for Google logo with local asset | Low |
| 22 | LOW | Wrap AI prompt context with sanitization delimiters | Low |
| 23 | LOW | `_AuthChangeNotifier` — convert module-level singleton to Riverpod-managed provider | Medium |
| 24 | LOW | Remove `clockTimer` from SignupScreen or extract clock to child widget | Low |

---

## Appendix: Positive Findings

The following patterns are well-implemented and worth preserving:

- **Proper `dispose()` coverage**: All `TextEditingController`, `PageController`, `ScrollController`, `Timer`, and `AnimationController` instances inspected have matching `dispose()` or `cancel()` calls.
- **`autoDispose` on stream providers**: Community repository stream providers (`postsStreamProvider`, `commentsStreamProvider`, etc.) all use `.autoDispose`, preventing memory leaks when navigating away.
- **`ref.onDispose` in `activeSessionTimerProvider`**: The workout session timer correctly cancels itself using `ref.onDispose`.
- **Nonce + SHA-256 for Apple Sign-In**: Cryptographically correct Apple Sign-In implementation using `_generateNonce()` and `_sha256ofString()`.
- **Sizer package usage**: The project consistently uses `sizer` (`h`, `w`, `sp`) instead of hardcoded pixel values, ensuring responsive layouts.
- **Firestore batch writes and transactions**: `AdminRepository.inviteMember` and `CommunityRepository.toggleLike` correctly use batch writes and transactions to maintain data consistency.
- **`gymAllowsEmail` server-side validation**: Auth repository calls `_userRepo.gymAllowsEmail` before linking users to gyms — a real server-side check.
- **Localization**: Full Arabic/English localization with RTL support is thorough and well-implemented.
- **GoRouter redirect guards**: Auth routing with Firestore role resolution is correct in concept, with cache priming from SharedPreferences for fast startup.

