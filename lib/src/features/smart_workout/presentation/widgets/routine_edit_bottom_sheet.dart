import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../models/routine_model.dart';
import '../../providers/routines_provider.dart';
import '../../providers/split_setup_provider.dart';
import '../../providers/workout_history_provider.dart';

class RoutineEditBottomSheet extends StatelessWidget {
  final VoidCallback onAdjustTime;
  final VoidCallback onAdjustIntensity;
  final VoidCallback onChangeMuscle;
  final VoidCallback onSwapExercises;

  const RoutineEditBottomSheet({
    super.key,
    required this.onAdjustTime,
    required this.onAdjustIntensity,
    required this.onChangeMuscle,
    required this.onSwapExercises,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    RoutineModel routine,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoutineEditBottomSheet(
        onAdjustTime: () {
          Navigator.pop(context);
          _showTimeSheet(context, ref, routine);
        },
        onAdjustIntensity: () {
          Navigator.pop(context);
          _showIntensitySheet(context, ref, routine);
        },
        onChangeMuscle: () {
          Navigator.pop(context);
          _showMuscleSheet(context, ref, routine);
        },
        onSwapExercises: () {
          Navigator.pop(context);
          context.push('/routine_overview', extra: routine);
        },
      ),
    );
  }

  static void _showTimeSheet(
    BuildContext context,
    WidgetRef ref,
    RoutineModel routine,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 2.h),
              Text(
                'short_on_time'.tr(context),
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 0.5.h),
              Text(
                'No problem — we\'ve got you.',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: 3.h),
              ListTile(
                leading: Icon(
                  Icons.flash_on_rounded,
                  color: const Color(0xFFFFCC00),
                  size: 28.sp,
                ),
                title: Text(
                  'quick_30'.tr(context),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'three_exercises_full_intensity'.tr(context),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(msRoutinesProvider.notifier)
                      .quick30Routine(routine.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('trimmed_to_3_core_exercises'.tr(context)),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.track_changes_rounded,
                  color: const Color(0xFF34C759),
                  size: 24.sp,
                ),
                title: Text(
                  'focused_45'.tr(context),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ), // Increased from 15.sp
                subtitle: Text(
                  'same_workout_less_rest'.tr(context),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF8E8E93),
                  ),
                ), // Increased from 11.sp
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(msRoutinesProvider.notifier)
                      .focused45Routine(routine.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('rest_times_reduced'.tr(context))),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.calendar_month_rounded,
                  color: const Color(0xFF007AFF),
                  size: 24.sp,
                ),
                title: Text(
                  'reschedule_workout'.tr(context),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ), // Increased from 15.sp
                subtitle: Text(
                  'move_today_rest_day'.tr(context),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF8E8E93),
                  ),
                ), // Increased from 11.sp
                onTap: () {
                  Navigator.pop(context);
                  _showRescheduleSheet(context, ref);
                },
              ),
              SizedBox(height: 3.h),
            ],
          ),
        );
      },
    );
  }

  static void _showRescheduleSheet(BuildContext context, WidgetRef ref) {
    final setupData =
        ref.read(splitSetupDataProvider).value ?? SplitSetupData();
    final trainingDays = setupData.trainingDays;
    final allDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final todayName = DateFormat('EEE').format(DateTime.now()).toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 2.h),
              Text(
                'reschedule_workout'.tr(context),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 0.5.h),
              Text(
                'swap_today_rest_day'.tr(context),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: 2.h),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allDays.length,
                itemBuilder: (context, index) {
                  final day = allDays[index];
                  final isToday = day == todayName;
                  final isTraining = trainingDays.contains(day);
                  final isAvailable = !isTraining && !isToday;

                  String subtitleText = 'available_rest_day'.tr(context);
                  Color subtitleColor = Colors.green.shade700;

                  if (isToday) {
                    subtitleText = 'today_current_workout'.tr(context);
                    subtitleColor = Colors.blue;
                  } else if (isTraining) {
                    subtitleText = 'already_workout_day'.tr(context);
                    subtitleColor = Colors.red.shade700;
                  }

                  return ListTile(
                    enabled: isAvailable,
                    leading: Icon(
                      isAvailable
                          ? Icons.check_circle_outline
                          : (isToday ? Icons.today : Icons.cancel_outlined),
                      color: isAvailable
                          ? Colors.green
                          : (isToday ? Colors.blue : Colors.red),
                    ),
                    title: Text(
                      day,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.black : Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      subtitleText,
                      style: TextStyle(
                        color: subtitleColor,
                        fontWeight: isAvailable
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      final generatedPlan = ref.read(generatedPlanProvider);
                      final setupDataData = ref
                          .read(splitSetupDataProvider)
                          .value;
                      final planStartDateData =
                          setupDataData?.planStartDate ?? DateTime.now();
                      final nowData = DateTime.now();
                      final diffData =
                          DateTime(nowData.year, nowData.month, nowData.day)
                              .difference(
                                DateTime(
                                  planStartDateData.year,
                                  planStartDateData.month,
                                  planStartDateData.day,
                                ),
                              )
                              .inDays;
                      final indexData = diffData >= 0 ? (diffData % 7) : 0;

                      if (generatedPlan.isNotEmpty) {
                        final todayPlan = generatedPlan[indexData];

                        WorkoutDay? targetPlan;
                        for (int i = 1; i < 7; i++) {
                          final checkIndex = (indexData + i) % 7;
                          final d = generatedPlan[checkIndex];
                          if (d.dayName == day) {
                            targetPlan = d;
                            break;
                          }
                        }
                        targetPlan ??= todayPlan;
                        if (todayPlan.fullDate != null &&
                            targetPlan.fullDate != null &&
                            targetPlan.dayName == day) {
                          ref
                              .read(splitSetupDataProvider.notifier)
                              .addSwap(
                                todayPlan.fullDate!,
                                targetPlan.fullDate!,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Swapped! Today is now a Rest Day, and $day is a Workout Day.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
              SizedBox(height: 2.h),
            ],
          ),
        );
      },
    );
  }

  static void _showIntensitySheet(
    BuildContext context,
    WidgetRef ref,
    RoutineModel routine,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 2.h),
              Text(
                'adjust_intensity'.tr(context),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 1.h),
              _buildIntensityTile(
                context,
                ref,
                routine,
                'easy',
                '🪫 Easy Mode',
                'Trim sets, lighter weight, more rest',
              ),
              _buildIntensityTile(
                context,
                ref,
                routine,
                'lighter',
                '🔋 Lighter',
                'Slightly lighter, no exercises removed',
              ),
              _buildIntensityTile(
                context,
                ref,
                routine,
                'normal',
                '⚡ As Planned (Default)',
                'Original workout exactly as planned',
              ),
              _buildIntensityTile(
                context,
                ref,
                routine,
                'harder',
                '🔥 Push Harder',
                'Heavier weight, shorter rest, Rest-Pause',
              ),
              _buildIntensityTile(
                context,
                ref,
                routine,
                'beast',
                '💀 Beast Mode',
                'Drop sets, Supersets, pure intensity!',
              ),
              SizedBox(height: 2.h),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildIntensityTile(
    BuildContext context,
    WidgetRef ref,
    RoutineModel routine,
    String level,
    String title,
    String subtitle,
  ) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
      ), // Increased from 15.sp
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
      ), // Increased from 11.sp
      onTap: () {
        Navigator.pop(context);
        ref
            .read(msRoutinesProvider.notifier)
            .adjustIntensityLevel(routine.id, level);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'intensity_set_to'.tr(context)} $title!')),
        );
      },
    );
  }

  static void _showMuscleSheet(
    BuildContext context,
    WidgetRef ref,
    RoutineModel currentRoutine,
  ) {
    final muscles = ['Chest', 'Back', 'Legs', 'Arms', 'Core', 'Shoulders'];
    final history = ref.read(workoutHistoryProvider);

    List<Map<String, dynamic>> muscleData = [];

    for (var m in muscles) {
      if (m == currentRoutine.category) continue;
      final score = ref.read(recoveryScoreProvider(m));
      if (score < 40) continue;

      final mHistory = history.where((h) => h.category == m).toList();
      String lastTrained = 'never'.tr(context);
      DateTime? lastDate;
      if (mHistory.isNotEmpty && mHistory.first.timestampIso != null) {
        lastDate = DateTime.parse(mHistory.first.timestampIso!);
        final days = DateTime.now().difference(lastDate).inDays;
        lastTrained = days == 0
            ? 'today'.tr(context)
            : (days == 1
                  ? 'yesterday'.tr(context)
                  : '$days ${'days_ago'.tr(context)}');
      }

      muscleData.add({
        'name': m,
        'score': score,
        'lastTrained': lastTrained,
        'lastDate': lastDate,
      });
    }

    // Sort: Score Descending, then Last Date Ascending
    muscleData.sort((a, b) {
      int scoreCmp = (b['score'] as int).compareTo(a['score'] as int);
      if (scoreCmp != 0) return scoreCmp;
      DateTime? dateA = a['lastDate'] as DateTime?;
      DateTime? dateB = b['lastDate'] as DateTime?;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return -1;
      if (dateB == null) return 1;
      return dateA.compareTo(dateB);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 2.h),
              Text(
                'change_target_muscle'.tr(context),
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 1.h),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: muscleData.length,
                  itemBuilder: (context, index) {
                    final data = muscleData[index];
                    final name = data['name'] as String;
                    final score = data['score'] as int;
                    final lastTrained = data['lastTrained'] as String;

                    Color statusColor = Colors.red;
                    String statusText = 'Too Soon ⚠️';
                    if (score >= 80) {
                      statusColor = Colors.green;
                      statusText = 'Ready ✓';
                    } else if (score >= 60) {
                      statusColor = Colors.orange;
                      statusText = 'OK';
                    }

                    return ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 0.5.h),
                          LinearProgressIndicator(
                            value: score / 100,
                            backgroundColor: Colors.grey.shade200,
                            color: statusColor,
                            minHeight: 6,
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            'Last trained: $lastTrained',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showSwapConfirmationDialog(
                          context,
                          ref,
                          currentRoutine,
                          name,
                          lastTrained,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _showSwapConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    RoutineModel currentRoutine,
    String newMuscle,
    String lastTrainedText,
  ) {
    final newRoutine = ref
        .read(msRoutinesProvider.notifier)
        .previewMuscleSwap(currentRoutine, newMuscle);
    if (newRoutine == null) return;

    final oldExNames =
        currentRoutine.exercises.map((e) => e.name).take(3).join(', ') +
        (currentRoutine.exercises.length > 3 ? '...' : '');
    final newExNames =
        newRoutine.exercises.map((e) => e.name).take(3).join(', ') +
        (newRoutine.exercises.length > 3 ? '...' : '');

    // Estimate duration
    final duration =
        newRoutine.exercises.fold(
          0,
          (sum, e) => sum + (e.sets * (e.restTime + 45)),
        ) ~/
        60;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'confirm_switch'.tr(context),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changed: ${currentRoutine.category} → $newMuscle',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 1.h),
            Text(
              '${'removed'.tr(context)}: $oldExNames',
              style: TextStyle(color: Colors.red.shade700),
            ),
            SizedBox(height: 0.5.h),
            Text(
              '${'added'.tr(context)}: $newExNames',
              style: TextStyle(color: Colors.green.shade700),
            ),
            SizedBox(height: 1.h),
            Text(
              '${'duration_approx'.tr(context)} $duration ${'min_same'.tr(context)}',
            ),
            SizedBox(height: 1.h),
            Text(
              'Last trained $newMuscle: $lastTrainedText — perfect timing 🎯',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'keep_original'.tr(context),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(context);
              final generatedPlan = ref.read(generatedPlanProvider);
              final setupDataData = ref.read(splitSetupDataProvider).value;
              final planStartDateData =
                  setupDataData?.planStartDate ?? DateTime.now();
              final nowData = DateTime.now();
              final diffData =
                  DateTime(nowData.year, nowData.month, nowData.day)
                      .difference(
                        DateTime(
                          planStartDateData.year,
                          planStartDateData.month,
                          planStartDateData.day,
                        ),
                      )
                      .inDays;
              final indexData = diffData >= 0 ? (diffData % 7) : 0;
              final todayStr = DateTime.now().toIso8601String().split('T')[0];

              WorkoutDay? futureDay;
              for (int i = 1; i < 7; i++) {
                final checkIndex = (indexData + i) % 7;
                final d = generatedPlan[checkIndex];
                if (d.categories.contains(newMuscle) && d.fullDate != null) {
                  futureDay = d;
                  break;
                }
              }
              futureDay ??= WorkoutDay(
                dayName: '',
                date: '',
                title: '',
                categories: [],
              );

              if (futureDay.dayName.isNotEmpty && futureDay.fullDate != null) {
                // Swap the days!
                ref
                    .read(splitSetupDataProvider.notifier)
                    .addSwap(todayStr, futureDay.fullDate!);
                // We don't overwrite the routine, because the generatedPlan will pull the right routine automatically!
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${'swapped_schedule_today'.tr(context)} $newMuscle, ${'previous_workout_moved'.tr(context)} ${futureDay.dayName}.',
                    ),
                  ),
                );
              } else {
                // Fallback: If muscle not found in future, just overwrite current routine
                ref
                    .read(msRoutinesProvider.notifier)
                    .updateRoutine(currentRoutine.id, newRoutine);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${'switched_to'.tr(context)} $newMuscle!'),
                  ),
                );
              }
            },
            child: Text(
              'confirm_switch'.tr(context),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      padding: EdgeInsetsDirectional.only(
        start: 5.w,
        end: 5.w,
        top: 2.h,
        bottom: 4.h + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 12.w,
              height: 0.6.h,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(1.w),
              ),
            ),
          ),
          SizedBox(height: 3.h),

          Text(
            'customize_routine'.tr(context),
            style: TextStyle(
              fontSize: 22.sp, // Increased from 18.sp
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'tell_ai_adjust_workout'.tr(context),
            style: TextStyle(
              fontSize: 14.sp, // Increased from 12.sp
              color: const Color(0xFF8E8E93),
              height: 1.4,
            ),
          ),
          SizedBox(height: 3.h),

          _buildOptionTile(
            context,
            icon: Icons.timer_outlined,
            title: 'short_on_time'.tr(context),
            subtitle: 'trim_workout_not_skip'.tr(context),
            onTap: onAdjustTime,
          ),
          _buildOptionTile(
            context,
            icon: Icons.battery_charging_full_outlined,
            title: 'adjust_intensity'.tr(context),
            subtitle: 'make_easier_or_harder_today'.tr(context),
            onTap: onAdjustIntensity,
          ),
          _buildOptionTile(
            context,
            icon: Icons.track_changes_outlined,
            title: 'change_target_muscle'.tr(context),
            subtitle: 'train_different_muscle_group'.tr(context),
            onTap: onChangeMuscle,
          ),
          _buildOptionTile(
            context,
            icon: Icons.swap_calls_rounded,
            title: 'swap_reorder_exercises'.tr(context),
            subtitle: 'change_exercises_based_equipment'.tr(context),
            onTap: onSwapExercises,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF5F5F7))),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Icon(icon, color: const Color(0xFF1C1C1E), size: 18.sp),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp, // Increased from 14.sp
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp, // Increased from 11.sp
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFFC7C7CC),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}
