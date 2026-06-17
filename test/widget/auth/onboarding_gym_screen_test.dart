// test/widget/auth/onboarding_gym_screen_test.dart
//
// Widget tests for OnboardingGymScreen — gym-code entry form.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/auth/presentation/screens/onboarding_gym_screen.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('OnboardingGymScreen', () {
    testWidgets('renders without crashing', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const OnboardingGymScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a text field for gym code', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const OnboardingGymScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(TextField).first, findsOneWidget);
    });

    testWidgets('shows a continue/next button', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const OnboardingGymScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('tapping continue with empty field shows snackbar',
        (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const OnboardingGymScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pumpAndSettle();

      // SnackBar appears when gym code is empty
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('can type a gym code into the text field', (tester) async {
      setPhoneViewport(tester);
      final app = await makeTestApp(const OnboardingGymScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      // The gym code field has FilteringTextInputFormatter.digitsOnly,
      // so only the numeric portion of the input is kept.
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();

      expect(find.text('123456'), findsOneWidget);
    });
  });
}
