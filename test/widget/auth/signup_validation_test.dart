// test/widget/auth/signup_validation_test.dart
//
// Additional validation tests for SignupScreen.
// Complements signup_interaction_test.dart with structural & state checks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/auth/presentation/screens/signup_screen.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('SignupScreen — validation & structure', () {
    testWidgets('renders without crashing', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(SignupScreen), findsOneWidget);
    });

    testWidgets('does not throw during build', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('contains at least one TextFormField on step 1', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(TextFormField), findsAtLeastNWidgets(1));
    });

    testWidgets('has at least one ElevatedButton', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(ElevatedButton), findsAtLeastNWidgets(1));
    });

    testWidgets('entering text into both name fields is reflected',
        (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      final firstField = find.byType(TextFormField).first;
      final lastField  = find.byType(TextFormField).at(1);

      await tester.enterText(firstField, 'Zaid');
      await tester.enterText(lastField, 'Omar');
      await tester.pump();

      expect(find.text('Zaid'), findsOneWidget);
      expect(find.text('Omar'), findsOneWidget);
    });

    testWidgets('first name field can be cleared and re-entered', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      final firstField = find.byType(TextFormField).first;

      await tester.enterText(firstField, 'Ahmad');
      await tester.pump();
      expect(find.text('Ahmad'), findsOneWidget);

      await tester.enterText(firstField, 'Khalid');
      await tester.pump();
      expect(find.text('Khalid'), findsOneWidget);
      expect(find.text('Ahmad'), findsNothing);
    });

    testWidgets('tapping Continue without data does not push a new route',
        (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      final continueBtn = find.widgetWithText(ElevatedButton, 'Continue →');
      if (continueBtn.evaluate().isEmpty) return;

      await tester.tap(continueBtn);
      await tester.pump();

      // Still on SignupScreen — no navigation occurred.
      expect(find.byType(SignupScreen), findsOneWidget);
    });

    testWidgets('screen has Scaffold at root', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('displays Google and Apple sign-in options', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const SignupScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // Social buttons show "Google" and "Apple" text (from localization keys).
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
    });
  });
}
