import 'dart:io';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'core/localization/app_localizations.dart';
import 'core/providers/locale_provider.dart';
import 'firebase_options.dart';
import 'src/core/providers/shared_preferences_provider.dart';
import 'src/core/router/app_router.dart';
import 'src/core/security/certificate_pinning.dart';
import 'src/core/services/notification_service.dart';
import 'src/core/services/remote_config_service.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/theme/theme_provider.dart';
import 'src/core/widgets/app_error_boundary.dart';
import 'src/features/nutrition/services/alarm_service.dart';

late final SharedPreferences globalSharedPrefs;

void main() async {
  // ── SSL / TLS certificate pinning ─────────────────────────────────────────
  // Pins Dart-layer HTTP calls (Gemini API, any future http/dio calls) to
  // Google Trust Services root CAs.  Firebase native-SDK traffic is already
  // pinned by the Firebase SDK itself and is unaffected by this override.
  // Bypassed automatically in debug mode to allow Charles / Proxyman proxies.
  HttpOverrides.global = NexusCertificatePinning();

  WidgetsFlutterBinding.ensureInitialized();

  RemoteConfigService? initializedRemoteConfig;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── Crashlytics + Error boundaries ──────────────────────────────────────
    // Forward all Flutter framework errors to Crashlytics and swap the ugly
    // red debug screen for the app's own AppErrorScreen.
    configureGlobalErrorHandling();

    // ── Push notifications ───────────────────────────────────────────────────
    // Sets up FCM foreground/background/terminated listeners and deep-link
    // routing.  Must run after Firebase.initializeApp.
    await NotificationService.init();

    // Catch asynchronous errors that escape the Flutter zone (e.g. Isolates).
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // ── App Check ────────────────────────────────────────────────────────────
    // Blocks unauthorized clients from accessing Firebase APIs.
    // Debug mode: App Check is skipped entirely — the debug token must be
    // manually registered in Firebase Console per-device, which breaks Phone
    // Auth on un-registered devices.  Production enforces Play Integrity /
    // App Attest normally.
    if (!kDebugMode) {
      await FirebaseAppCheck.instance.activate(
        appleProvider: AppleProvider.appAttestWithDeviceCheckFallback,
      );
    }

    initializedRemoteConfig = RemoteConfigService();
    await initializedRemoteConfig.init();
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }

  final sharedPrefs = await SharedPreferences.getInstance();
  globalSharedPrefs = sharedPrefs;
  await AlarmService().init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        if (initializedRemoteConfig != null)
          remoteConfigProvider.overrideWithValue(initializedRemoteConfig),
      ],
      child: const NexusApp(),
    ),
  );
}

class NexusApp extends ConsumerWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp.router(
          title: 'NEXUS',
          themeMode: themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          locale: appLocale,
          supportedLocales: const [Locale('en', ''), Locale('ar', '')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Directionality(
                textDirection: appLocale.languageCode == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: AppErrorBoundary(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
