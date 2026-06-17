import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../models/routine_model.dart';
import '../../providers/routines_provider.dart';

class RoutineOverviewScreen extends ConsumerWidget {
  final RoutineModel routine;

  const RoutineOverviewScreen({super.key, required this.routine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch the provider so if an exercise is swapped, this screen updates instantly
    final asyncRoutines = ref.watch(msRoutinesProvider);
    final updatedRoutine = asyncRoutines.maybeWhen(
      data: (routines) =>
          routines.firstWhere((r) => r.id == routine.id, orElse: () => routine),
      orElse: () => routine,
    );

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
          'swap_exercises'.tr(context),
          style: TextStyle(
            fontSize: 20.sp, // Increased from 16.sp
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: EdgeInsets.all(4.w),
          itemCount: updatedRoutine.exercises.length,
          itemBuilder: (context, index) {
            final exercise = updatedRoutine.exercises[index];
            return Container(
              margin: EdgeInsets.only(bottom: 2.h),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.w),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: const Color(0xFF1C1C1E),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: TextStyle(
                            fontSize: 16.sp, // Increased from 14.sp
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          '${exercise.sets} ${'sets'.tr(context).toLowerCase()} x ${exercise.reps}',
                          style: TextStyle(
                            fontSize: 13.sp, // Increased from 12.sp
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 2.w),
                  GestureDetector(
                    onTap: () {
                      context.push(
                        '/exercise_selection',
                        extra: {
                          'routine': updatedRoutine,
                          'exerciseIndex': index,
                        },
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      child: Text(
                        'swap'.tr(context),
                        style: TextStyle(
                          fontSize: 13.sp, // Increased from 11.sp
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
