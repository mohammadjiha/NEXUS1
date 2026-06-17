// test/widget/auth/signup_interaction_test.dart
//
// Interaction tests for SignupScreen — step navigation, field validation.
//
// Notes on the signup screen UI:
//   • Field labels are uppercased: 'auth_first_name' → 'FIRST', 'LAST'
//   • Field hints (inside the TextFormField): 'Ahmad', 'Hassan'
//   • The continue button text is 'auth_continue' → 'Continue →' on step 1

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/auth/presentation/screens/signup_screen.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('SignupScreen — interactions', () {
    testWidgets('renders step 1 with FIRST / LAST name labels', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Labels are uppercased via label.toUpperCase()
      expect(find.text('FIRST'), findsOneWidget);
      expect(find.text('LAST'), findsOneWidget);
    });

    testWidgets('can type into First and Last name fields', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Fields: first = index 0, last = index 1 in the step-1 form
      final firstField = find.byType(TextFormField).first;
      final lastField  = find.byType(TextFormField).at(1);

      await tester.enterText(firstField, 'Oday');
      await tester.enterText(lastField, 'Hindy');
      await tester.pump();

      expect(find.text('Oday'), findsOneWidget);
      expect(find.text('Hindy'), findsOneWidget);
    });

    testWidgets('Create account heading is visible', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('Continue button is present on step 1', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Step 1 button uses 'auth_continue' → 'Continue →'
      expect(
        find.widgetWithText(ElevatedButton, 'Continue →'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Continue without fields stays on step 1',
        (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue →'));
      await tester.pump();

      // Should still be on step 1 — create account heading still visible
      expect(find.text('Create account'), findsOneWidget);
    });
  });
}
