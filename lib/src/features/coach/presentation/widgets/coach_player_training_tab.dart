import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../smart_workout/models/routine_model.dart';
import '../../../smart_workout/providers/split_setup_provider.dart';
import '../../../user/models/user_model.dart';
import '../../providers/coach_monitoring_provider.dart';

class CoachPlayerTrainingTab extends ConsumerWidget {
  final UserModel player;

  const CoachPlayerTrainingTab({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generatedPlanAsync = ref.watch(
      playerGeneratedPlanProvider(player.uid),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title or Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 2.h),
          child: Text(
            'coach_dynamic_training_plan'.tr(context),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
        ),

        generatedPlanAsync.when(
          data: (plan) {
            if (plan.isEmpty) {
              return Center(
                child: Text('coach_no_active_training_plan'.tr(context)),
              );
            }

            // Find today (we'll just take the first day in the generated plan which is today by logic)
            final today = plan.first;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (today.isRest)
                  _buildRestDayCard(context)
                else if (today.assignedRoutineId != null)
                  _buildTodayRoutine(
                    context,
                    ref,
                    today.assignedRoutineId!,
                    today.title,
                  ),

                SizedBox(height: 3.h),
                _buildUpcomingStrip(context, plan),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
            ),
          ),
          error: (err, stack) => Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Text(
                '${'error'.tr(context)}: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRestDayCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(6.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'today'.tr(context).toUpperCase(),
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'rest_day'.tr(context),
            style: TextStyle(
              fontSize: 21.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            'coach_player_resting_today'.tr(context),
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayRoutine(
    BuildContext context,
    WidgetRef ref,
    String routineId,
    String dayTitle,
  ) {
    // Use player-specific routines (includes their modified weights) — real-time stream
    final routinesAsync = ref.watch(playerRoutinesProvider(player.uid));
    return routinesAsync.when(
      data: (routines) {
        RoutineModel? routine;
        try {
          routine = routines.firstWhere((r) => r.id == routineId);
        } catch (_) {
          routine = routines.isNotEmpty ? routines.first : null;
        }

        if (routine == null) return const SizedBox();

        int totalSets = routine.exercises.fold(0, (sum, ex) => sum + ex.sets);
        int estTime = totalSets * 3;

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4.4.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6.w),
            border: Border.all(color: const Color(0xFFE5E5EA)),
          ),
          child: Column(
            children: [
              // Head
              Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(6.w),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY · $dayTitle',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      routine.routineName,
                      style: TextStyle(
                        fontSize: 21.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      routine.description,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              // Body (Stats)
              Padding(
                padding: EdgeInsets.all(5.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      Icons.schedule,
                      '$estTime ${'min'.tr(context)}',
                    ),
                    _buildStatItem(
                      Icons.fitness_center,
                      '${routine.exercises.length} ${'exercises'.tr(context)}',
                    ),
                    _buildStatItem(
                      Icons.local_fire_department,
                      '${(estTime * 6.5).round()} kcal',
                    ),
                  ],
                ),
              ),
              // Exercises list preview
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFF0F0F5))),
                ),
                child: Column(
                  children: routine.exercises
                      .take(3)
                      .map(
                        (ex) => Padding(
                          padding: EdgeInsets.only(bottom: 1.5.h),
                          child: Row(
                            children: [
                              Container(
                                width: 10.w,
                                height: 10.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F7),
                                  borderRadius: BorderRadius.circular(2.w),
                                ),
                                child: Icon(
                                  Icons.fitness_center,
                                  size: 14.sp,
                                  color: const Color(0xFF8E8E93),
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex.name,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                    Text(
                                      '${ex.sets} ${'sets'.tr(context).toLowerCase()} x ${ex.reps}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildStatItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF1C1C1E), size: 18.sp),
        SizedBox(height: 0.5.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingStrip(BuildContext context, List<WorkoutDay> plan) {
    if (plan.length <= 1) return const SizedBox();

    // Drop today
    final upcoming = plan.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.4.w),
          child: Text(
            'coach_upcoming_schedule'.tr(context),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
        SizedBox(height: 1.5.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 4.4.w),
          child: Row(
            children: upcoming.map((day) {
              return Container(
                width: 35.w,
                margin: EdgeInsetsDirectional.only(end: 3.w),
                padding: EdgeInsets.all(3.5.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4.w),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.dayName,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      day.title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.h),
                    Icon(
                      day.isRest
                          ? Icons.weekend_rounded
                          : Icons.fitness_center_rounded,
                      size: 16.sp,
                      color: day.isRest
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF007AFF),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
