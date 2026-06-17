import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remoteConfigProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});

class RemoteConfigService {
  // Lazily initialized — not called until init() runs
  FirebaseRemoteConfig? _remoteConfig;

  Future<void> init() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? const Duration()
              : const Duration(hours: 1),
        ),
      );

      await _remoteConfig!.setDefaults({
        'onboarding_title_1': 'Enter your Gym Code',
        'onboarding_subtitle_1':
            'If your gym uses NEXUS, enter the code provided by your gym manager.',
        'onboarding_title_2': "What's your role?",
        'onboarding_subtitle_2':
            'This helps us personalize your NEXUS experience from day one.',
        'role_player_title': 'Player / Member',
        'role_player_subtitle': 'I want to track my workouts and nutrition',
        'role_coach_title': 'Coach / Personal Trainer',
        'role_coach_subtitle': 'I want to manage my clients and plans',
        'role_admin_title': 'Gym Owner / Admin',
        'role_admin_subtitle': 'I want to manage my gym facility',
        'gemini_api_key': '',
        'gemini_model': 'gemini-2.5-flash',
      });

      await _remoteConfig!.fetchAndActivate();
      debugPrint('Remote Config initialized successfully');
    } catch (e) {
      debugPrint('Remote Config init failed — using defaults: $e');
      _remoteConfig = null;
    }
  }

  // Safe getters — return empty/false/0 if Remote Config unavailable
  String getString(String key) => _remoteConfig?.getString(key) ?? '';
  bool getBool(String key) => _remoteConfig?.getBool(key) ?? false;
  double getDouble(String key) => _remoteConfig?.getDouble(key) ?? 0.0;
  int getInt(String key) => _remoteConfig?.getInt(key) ?? 0;
}
