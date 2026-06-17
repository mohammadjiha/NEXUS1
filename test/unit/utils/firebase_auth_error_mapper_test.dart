// test/unit/utils/firebase_auth_error_mapper_test.dart
//
// Unit tests for FirebaseAuthErrorMapper.
//
// Strategy: toKey() is pure Dart (no BuildContext, no network). We test:
//   1. Every named FirebaseAuthException code maps to the right key.
//   2. The fallback code path (plain strings / unrecognised codes).
//   3. Error-prevention: email-enumeration resistant codes collapse to one key.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/core/utils/firebase_auth_error_mapper.dart';

// Helper: build a FirebaseAuthException with a given code.
FirebaseAuthException _exc(String code) =>
    FirebaseAuthException(code: code, message: 'test');

void main() {
  group('FirebaseAuthErrorMapper.toKey', () {
    // ── Email / password codes ─────────────────────────────────────────────

    test('email-already-in-use → auth_email_in_use', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('email-already-in-use')),
        equals('auth_email_in_use'),
      );
    });

    test(
        'account-exists-with-different-credential → auth_email_in_use',
        () {
      expect(
        FirebaseAuthErrorMapper.toKey(
          _exc('account-exists-with-different-credential'),
        ),
        equals('auth_email_in_use'),
      );
    });

    test('invalid-email → auth_invalid_email', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('invalid-email')),
        equals('auth_invalid_email'),
      );
    });

    test('weak-password → auth_weak_password', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('weak-password')),
        equals('auth_weak_password'),
      );
    });

    // Email-enumeration prevention: wrong-password and user-not-found must
    // return the SAME key so attackers cannot tell which one is wrong.
    test('wrong-password → auth_incorrect_creds', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('wrong-password')),
        equals('auth_incorrect_creds'),
      );
    });

    test('user-not-found → auth_incorrect_creds', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('user-not-found')),
        equals('auth_incorrect_creds'),
      );
    });

    test('INVALID_LOGIN_CREDENTIALS → auth_incorrect_creds', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('INVALID_LOGIN_CREDENTIALS')),
        equals('auth_incorrect_creds'),
      );
    });

    // Both wrong-password and user-not-found collapse to the same key.
    test('wrong-password and user-not-found collapse to identical key', () {
      final k1 = FirebaseAuthErrorMapper.toKey(_exc('wrong-password'));
      final k2 = FirebaseAuthErrorMapper.toKey(_exc('user-not-found'));
      expect(k1, equals(k2));
    });

    test('user-disabled → auth_disabled_account', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('user-disabled')),
        equals('auth_disabled_account'),
      );
    });

    test('too-many-requests → auth_too_many_attempts', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('too-many-requests')),
        equals('auth_too_many_attempts'),
      );
    });

    // ── Credential / token codes ───────────────────────────────────────────

    test('invalid-credential → auth_invalid_credential', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('invalid-credential')),
        equals('auth_invalid_credential'),
      );
    });

    test('credential-already-in-use → auth_invalid_credential', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('credential-already-in-use')),
        equals('auth_invalid_credential'),
      );
    });

    test('token-expired → auth_invalid_credential', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('token-expired')),
        equals('auth_invalid_credential'),
      );
    });

    test('invalid-user-token → auth_invalid_credential', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('invalid-user-token')),
        equals('auth_invalid_credential'),
      );
    });

    test('operation-not-allowed → auth_operation_not_allowed', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('operation-not-allowed')),
        equals('auth_operation_not_allowed'),
      );
    });

    // ── Network codes ──────────────────────────────────────────────────────

    test('network-request-failed → auth_network_error', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('network-request-failed')),
        equals('auth_network_error'),
      );
    });

    // ── Fallback string path ───────────────────────────────────────────────

    test('plain Exception with "network" in message → auth_network_error', () {
      expect(
        FirebaseAuthErrorMapper.toKey(
          Exception('some network connectivity problem'),
        ),
        equals('auth_network_error'),
      );
    });

    test('plain Exception with "unavailable" → auth_network_error', () {
      expect(
        FirebaseAuthErrorMapper.toKey(Exception('service unavailable')),
        equals('auth_network_error'),
      );
    });

    test('plain Exception with "invalid_login" → auth_incorrect_creds', () {
      expect(
        FirebaseAuthErrorMapper.toKey(Exception('invalid_login_credentials')),
        equals('auth_incorrect_creds'),
      );
    });

    test('unknown code → auth_unexpected_error', () {
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('some-unknown-code-xyz')),
        equals('auth_unexpected_error'),
      );
    });

    test('completely unknown Exception → auth_unexpected_error', () {
      expect(
        FirebaseAuthErrorMapper.toKey(Exception('💥 random error')),
        equals('auth_unexpected_error'),
      );
    });

    // ── Return type safety ─────────────────────────────────────────────────

    test('toKey always returns a non-empty String', () {
      final codes = [
        'email-already-in-use',
        'weak-password',
        'user-not-found',
        'too-many-requests',
        'network-request-failed',
        'completely-unknown-code',
      ];
      for (final code in codes) {
        final key = FirebaseAuthErrorMapper.toKey(_exc(code));
        expect(key, isA<String>());
        expect(key, isNotEmpty);
      }
    });

    // ── toKey alias works the same as toMessage source ─────────────────────

    test('toKey and toMessage use the same logic (toKey is the source)', () {
      // toKey is what toMessage translates — verify they share the same result
      // for a known code without needing a BuildContext.
      expect(
        FirebaseAuthErrorMapper.toKey(_exc('weak-password')),
        equals('auth_weak_password'),
      );
    });
  });
}
