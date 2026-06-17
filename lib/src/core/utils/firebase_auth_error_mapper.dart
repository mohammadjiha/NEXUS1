// lib/src/core/utils/firebase_auth_error_mapper.dart
//
// Maps FirebaseAuthException error codes to app localization keys,
// producing user-friendly messages in the current locale (AR / EN).
//
// Usage
// ─────
//   Text(FirebaseAuthErrorMapper.toMessage(context, error))
//
// All returned strings go through app_localizations so Arabic / English
// is picked automatically — no manual locale checks needed.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../../../core/localization/app_localizations.dart';

abstract final class FirebaseAuthErrorMapper {
  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a localized, user-friendly error message for any Firebase auth
  /// error.  Falls back to [auth_unexpected_error] for unrecognised codes.
  static String toMessage(BuildContext context, Object error) {
    final key = _toKey(error);
    return key.tr(context);
  }

  /// Returns just the localization key — useful when you want to store the
  /// key in state and translate later in the widget layer.
  static String toKey(Object error) => _toKey(error);

  // ── Private helpers ────────────────────────────────────────────────────────

  static String _toKey(Object error) {
    final code = _extractCode(error);
    return _codeToKey(code);
  }

  /// Pulls the error code out of a [FirebaseAuthException] or a raw string.
  static String _extractCode(Object error) {
    if (error is FirebaseAuthException) return error.code;
    final str = error.toString().toLowerCase();
    // Fallback: scrape the code from the exception toString()
    if (str.contains('firebase_auth/')) {
      final start = str.indexOf('firebase_auth/') + 'firebase_auth/'.length;
      final end = str.indexOf(']', start);
      if (end > start) return str.substring(start, end).trim();
    }
    return str; // treat the whole string as the "code" for contains checks
  }

  static String _codeToKey(String code) {
    switch (code) {
      // ── Email / password ──────────────────────────────────────────────────
      case 'email-already-in-use':
      case 'account-exists-with-different-credential':
        return 'auth_email_in_use';

      case 'invalid-email':
        return 'auth_invalid_email';

      case 'weak-password':
        return 'auth_weak_password';

      case 'wrong-password':
      case 'user-not-found':
      case 'INVALID_LOGIN_CREDENTIALS':
        // Never reveal which one is wrong — prevents email enumeration.
        return 'auth_incorrect_creds';

      case 'user-disabled':
        return 'auth_disabled_account';

      case 'too-many-requests':
        return 'auth_too_many_attempts';

      // ── Credential / token ────────────────────────────────────────────────
      case 'invalid-credential':
      case 'credential-already-in-use':
      case 'token-expired':
      case 'invalid-user-token':
        return 'auth_invalid_credential';

      case 'operation-not-allowed':
        return 'auth_operation_not_allowed';

      // ── Gym status ────────────────────────────────────────────────────────
      case 'gym-inactive':
        return 'auth_gym_inactive';

      // ── Network ───────────────────────────────────────────────────────────
      case 'network-request-failed':
        return 'auth_network_error';

      default:
        // For non-FirebaseAuthException errors that hit this mapper via string
        if (code.contains('network') || code.contains('unavailable')) {
          return 'auth_network_error';
        }
        if (code.contains('invalid-login') || code.contains('invalid_login')) {
          return 'auth_incorrect_creds';
        }
        return 'auth_unexpected_error';
    }
  }
}
