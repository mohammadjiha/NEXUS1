import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../models/routine_model.dart';
import '../../providers/routines_provider.dart';
import '../../providers/workout_history_provider.dart';
import '../../services/exercise_substitution_service.dart';

class ExerciseSelectionScreen extends ConsumerWidget {
  final RoutineModel routine;
  final int exerciseIndex;

  const ExerciseSelectionScreen({
    super.key,
    required this.routine,
    required this.exerciseIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originalExercise = routine.exercises[exerciseIndex];
    final substitutionInfo = ExerciseSubstitutionService.getAlternatives(
      originalExercise.name,
    );
    final history = ref.watch(workoutHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: const Color(0xFF1C1C1E),
            size: 18.sp,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'swap_exercise'.tr(context),
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Original Exercise Info
            Container(
              padding: EdgeInsets.all(5.w),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: const Color(0xFF8E8E93),
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'original'.tr(context),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: const Color(0xFF8E8E93),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 0.3.h),
                        Text(
                          originalExercise.name,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        if (substitutionInfo != null) ...[
                          SizedBox(height: 0.3.h),
                          Text(
                            substitutionInfo.targetPortion,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: const Color(0xFF007AFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Alternatives List
            Expanded(
              child:
                  substitutionInfo == null ||
                      substitutionInfo.alternatives.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(5.w),
                        child: Text(
                          'no_direct_alternatives'.tr(context),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(4.w),
                      itemCount: substitutionInfo.alternatives.length,
                      itemBuilder: (context, index) {
                        final alt = substitutionInfo.alternatives[index];

                        // History check
                        String historyText = '';
                        double suggestedWeight = 10.0; // Base default weight

                        // Look for history of the *original* exercise to base the 80% on.
                        // Since we don't have exercise-level history yet, we use the routine's current weight.
                        suggestedWeight = originalExercise.weight * 0.8;

                        // Medal icon based on level
                        String medal = alt.level == 'M1'
                            ? '🥇'
                            : (alt.level == 'M2' ? '🥈' : '🥉');
                        Color badgeColor = alt.level == 'M1'
                            ? const Color(0xFFFFD700)
                            : (alt.level == 'M2'
                                  ? const Color(0xFFC0C0C0)
                                  : const Color(0xFFCD7F32));

                        return Container(
                          margin: EdgeInsets.only(bottom: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4.w),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(4.w),
                            onTap: () {
                              final newRoutineEx = originalExercise.copyWith(
                                name: alt.name,
                              );
                              final newExercises = [...routine.exercises];
                              newExercises[exerciseIndex] = newRoutineEx;

                              final newRoutine = routine.copyWith(
                                exercises: newExercises,
                              );
                              ref
                                  .read(msRoutinesProvider.notifier)
                                  .updateRoutine(routine.id, newRoutine);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${'swapped_to'.tr(context)} ${alt.name}!',
                                  ),
                                ),
                              );
                              context.pop(); // Pop selection screen
                              context.pop(); // Pop overview screen
                            },
                            child: Padding(
                              padding: EdgeInsets.all(4.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  medal,
                                                  style: TextStyle(
                                                    fontSize: 16.sp,
                                                  ),
                                                ),
                                                SizedBox(width: 2.w),
                                                Text(
                                                  '${alt.level} Alternative',
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.w700,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 1.h),
                                            Text(
                                              alt.name,
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF1C1C1E),
                                              ),
                                            ),
                                            SizedBox(height: 0.3.h),
                                            Text(
                                              substitutionInfo.targetPortion,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: const Color(0xFF007AFF),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 1.h),
                                            Text(
                                              alt.subtitle,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: const Color(0xFF8E8E93),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.swap_horiz_rounded,
                                        color: const Color(0xFFC7C7CC),
                                        size: 24.sp,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2.h),
                                  const Divider(
                                    color: Color(0xFFF5F5F7),
                                    height: 1,
                                  ),
                                  SizedBox(height: 1.5.h),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 2.5.w,
                                          vertical: 0.8.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F5F7),
                                          borderRadius: BorderRadius.circular(
                                            1.5.w,
                                          ),
                                        ),
                                        child: Text(
                                          '${'suggested'.tr(context)} ${suggestedWeight.toStringAsFixed(1)}${'kg'.tr(context)}',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                      ),
                                      if (historyText.isNotEmpty) ...[
                                        SizedBox(width: 2.w),
                                        Expanded(
                                          child: Text(
                                            historyText,
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              color: const Color(0xFF34C759),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (substitutionInfo != null &&
                substitutionInfo.alternatives.length < 3 &&
                substitutionInfo.alternatives.isNotEmpty)
              Container(
                padding: EdgeInsets.all(4.w),
                color: Colors.white,
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: const Color(0xFF8E8E93),
                      size: 16.sp,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'Only ${substitutionInfo.alternatives.length} alternative(s) target the exact same muscle portion — showing best match.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: const Color(0xFF8E8E93),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
