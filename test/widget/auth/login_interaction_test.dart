// test/widget/auth/login_interaction_test.dart
//
// Interaction-level widget tests for LoginScreen.
// Tests that key UI behaviours work correctly (tap, type, validation).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/auth/presentation/screens/login_screen.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('LoginScreen — interactions', () {
    testWidgets('password visibility toggle shows/hides password',
        (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Default: password hidden — eye-off outlined icon
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // Tap toggle
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      // Now should show eye icon (password visible)
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('typing in email field reflects text', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Email field is the first TextFormField
      final emailField = find.byType(TextFormField).first;
      expect(emailField, findsOneWidget);

      await tester.enterText(emailField, 'user@nexus.app');
      await tester.pump();

      expect(find.text('user@nexus.app'), findsOneWidget);
    });

    testWidgets('typing in password field reflects text', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Password field is the second TextFormField
      final passField = find.byType(TextFormField).last;
      expect(passField, findsOneWidget);

      await tester.enterText(passField, 'secret123');
      await tester.pump();

      // Text is present in the widget tree even when obscured
      expect(find.text('secret123'), findsOneWidget);
    });

    testWidgets('Sign In button is present and tappable', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Sign In button uses 'auth_sign_in' key → 'Sign In →'
      final signInBtn = find.text('Sign In →');
      expect(signInBtn, findsOneWidget);

      // Tap — should not throw (will fail silently without network)
      await tester.tap(signInBtn);
      await tester.pump();
    });

    testWidgets('has exactly two TextFormFields (email + password)',
        (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const LoginScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });
}
