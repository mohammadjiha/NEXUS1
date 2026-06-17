// lib/src/core/services/notification_service.dart
//
// FCM push-notification handler for Nexus.
//
// Responsibilities
// ─────────────────
// 1. Register a background handler so FCM can wake the app.
// 2. Show a local notification banner when a push arrives while the app is
//    in the foreground (FCM itself does NOT show a banner in this case).
// 3. Route the user to the correct screen when they tap a notification —
//    whether the app was in foreground, background, or terminated.
//
// Deep-link convention
// ────────────────────
// Every FCM message sent by the Nexus backend (Cloud Functions) must include
// a `data` payload with a `route` key that holds a valid GoRouter path, e.g.:
//
//   data: { "route": "/dashboard", "type": "feedback" }
//
// Usage
// ─────
// Call once in main() AFTER Firebase.initializeApp():
//
//   await NotificationService.init();

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_constants.dart';
import '../router/app_router.dart';

// ── Background handler (must be top-level / @pragma) ─────────────────────────
//
// Executed in an isolate when a data-only FCM message arrives while the app is
// in the background.  Firebase SDK is available here but Flutter plugins
// (navigation, Riverpod, etc.) are NOT — keep it minimal.

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Nothing extra needed: the FCM SDK automatically shows the notification
  // banner from the RemoteMessage.notification payload on Android/iOS.
}

// ── Notification channel constants ───────────────────────────────────────────

const _kChannelId = 'nexus_push_channel';
const _kChannelName = 'Nexus Notifications';
const _kChannelDesc = 'Coach feedback, reminders, and workout updates';

// ── Service ───────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final _local = FlutterLocalNotificationsPlugin();

  /// Initialise FCM listeners and the local-notification plugin.
  ///
  /// Must be called once in main() after [Firebase.initializeApp].
  static Future<void> init() async {
    // Background handler — registered before any stream listen.
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Local notification plugin — used to show banners in the foreground.
    await _initLocalPlugin();

    // Android notification channel (no-op on iOS).
    await _ensureAndroidChannel();

    // ── FCM foreground ────────────────────────────────────────────────────────
    // When the app is open and a push arrives the FCM SDK does NOT display a
    // banner — we show one ourselves via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // ── Background → app open via notification tap ────────────────────────────
    FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);

    // ── Terminated → app launched via notification tap ────────────────────────
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Small delay so GoRouter has time to finish bootstrapping.
      Future.delayed(AppDurations.coldStartRouteDelay, () {
        _routeFromMessage(initial);
      });
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  static Future<void> _initLocalPlugin() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false, // requested separately at sign-in
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        // User tapped the local banner shown while the app was in foreground.
        final route = response.payload;
        if (route != null && route.isNotEmpty) {
          appRouter.go(route);
        }
      },
    );
  }

  static Future<void> _ensureAndroidChannel() async {
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _kChannelId,
            _kChannelName,
            description: _kChannelDesc,
            importance: Importance.high,
          ),
        );
  }

  /// Called when an FCM message arrives while the app is in the foreground.
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return; // data-only message — nothing to display

    final route = _extractRoute(message);

    await _local.show(
      // Unique ID: hash the message ID so collisions are unlikely.
      id: message.messageId.hashCode,
      title: notif.title,
      body: notif.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          _kChannelName,
          channelDescription: _kChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: notif.body != null
              ? BigTextStyleInformation(notif.body!)
              : null,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // Payload carries the route so we can navigate when the banner is tapped.
      payload: route,
    );
  }

  /// Navigates to the route embedded in the FCM message's data payload.
  static void _routeFromMessage(RemoteMessage message) {
    final route = _extractRoute(message);
    appRouter.go(route);
  }

  // ── Route allowlist ────────────────────────────────────────────────────────
  //
  // Only FCM messages whose `data.route` matches a value in this set may
  // trigger in-app navigation.  Any unknown value falls back to /dashboard.
  //
  // Security rationale (pentest finding N-03): if the FCM server key or a
  // Cloud Function is compromised, an attacker could craft a message with an
  // arbitrary route.  GoRouter's own redirect logic still blocks unauthorised
  // screens, but this allowlist adds defence-in-depth before GoRouter runs.
  static const _kAllowedRoutes = <String>{
    '/dashboard',
    '/coach_dashboard',
    '/profile',
    '/quick-log',
    '/active-session',
    '/exercise_selection',
    '/coach_notifications',
    '/coach_monitoring',
  };

  /// Extracts the GoRouter path from `message.data['route']`, validates it
  /// against [_kAllowedRoutes], and falls back to `/dashboard` for any unknown
  /// or absent value.
  static String _extractRoute(RemoteMessage message) {
    final raw = message.data['route'];
    if (raw is String && _kAllowedRoutes.contains(raw)) return raw;
    return '/dashboard'; // safe default for unknown / injected routes
  }
}
