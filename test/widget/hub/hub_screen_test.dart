// test/widget/hub/hub_screen_test.dart
//
// Widget tests for HubScreen — the feature discovery grid.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/hub/presentation/screens/hub_screen.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('HubScreen', () {
    testWidgets('renders without crashing', (tester) async {
      final app = await makeTestApp(const HubScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(HubScreen), findsOneWidget);
    });

    testWidgets('shows a Scaffold', (tester) async {
      final app = await makeTestApp(const HubScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows scrollable content', (tester) async {
      final app = await makeTestApp(const HubScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('does not throw during build', (tester) async {
      final app = await makeTestApp(const HubScreen());
      await tester.pumpWidget(app);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
