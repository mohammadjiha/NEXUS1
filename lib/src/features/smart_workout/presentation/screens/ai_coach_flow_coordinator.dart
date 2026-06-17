import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../providers/split_setup_provider.dart';
import 'smart_workout_home_screen.dart';
import 'split_setup_wizard_screen.dart';

class AiCoachFlowCoordinator extends ConsumerWidget {
  const AiCoachFlowCoordinator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(splitSetupStatusProvider);

    return statusAsync.when(
      data: (isSetupComplete) {
        if (isSetupComplete) {
          return const SmartWorkoutHomeScreen();
        } else {
          return const SplitSetupWizardScreen();
        }
      },
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF5F5F7),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: Center(
          child: Text(
            '${'error_prefix'.tr(context)} $err',
            style: TextStyle(color: Colors.red, fontSize: 14.sp),
          ),
        ),
      ),
    );
  }
}
