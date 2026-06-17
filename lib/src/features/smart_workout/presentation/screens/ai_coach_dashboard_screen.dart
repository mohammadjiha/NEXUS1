import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../models/routine_model.dart';
import '../../providers/routines_provider.dart';
import '../../providers/workout_history_provider.dart';
import '../widgets/routine_edit_bottom_sheet.dart';

class AiCoachDashboardScreen extends ConsumerStatefulWidget {
  const AiCoachDashboardScreen({super.key});

  @override
  ConsumerState<AiCoachDashboardScreen> createState() =>
      _AiCoachDashboardScreenState();
}

class _AiCoachDashboardScreenState
    extends ConsumerState<AiCoachDashboardScreen> {
  String _getCategoryForDay(int weekday) {
    switch (weekday) {
      case 1:
        return 'Chest';
      case 2:
        return 'Back';
      case 3:
        return 'Rest';
      case 4:
        return 'Legs';
      case 5:
        return 'Shoulders';
      case 6:
        return 'Rest';
      case 7:
        return 'Full Body';
      default:
        return 'Rest';
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    String dayName = days[now.weekday - 1];
    String monthName = months[now.month - 1];
    return '$dayName, $monthName ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(msRoutinesProvider);
    final firstName = ref.watch(currentUserFirstNameProvider);
    final initials = ref.watch(currentUserInitialsProvider);
    final todayWeekday = DateTime.now().weekday;
    final todayCategory = _getCategoryForDay(todayWeekday);
    final tomorrowCategory = _getCategoryForDay((todayWeekday % 7) + 1);

    final history = ref.watch(workoutHistoryProvider);
    final now = DateTime.now();
    CompletedSession? completedSessionToday;
    if (history.isNotEmpty) {
      final last = history.first;
      if (last.timestampIso != null) {
        try {
          final t = DateTime.parse(last.timestampIso!).toLocal();
          if (DateTime.now().difference(t).inHours < 16 &&
              t.day == DateTime.now().day) {
            completedSessionToday = last;
          }
        } catch (_) {}
      }
      if (completedSessionToday == null) {
        final str1 = DateFormat('MMM d').format(DateTime.now());
        if (last.date == str1) {
          completedSessionToday = last;
        }
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(context, firstName: firstName, initials: initials),
              if (todayCategory == 'Rest')
                _buildTodayRestCard(context)
              else
                routinesAsync.when(
                  data: (routines) {
                    if (routines.isEmpty) return const SizedBox();
                    if (completedSessionToday != null) {
                      return _buildTodayCompletedCard(
                        context,
                        completedSessionToday,
                      );
                    }
                    final routine = routines.firstWhere(
                      (r) => r.category == todayCategory,
                      orElse: () => routines.first,
                    );
                    final recoveryScore = ref.watch(
                      recoveryScoreProvider(routine.category),
                    );
                    return _buildTodayHeroCard(
                      context,
                      ref,
                      routine,
                      recoveryScore,
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 10.w, color: const Color(0xFFFF3B30)),
                        SizedBox(height: 1.h),
                        Text(
                          '${'error'.tr(context)}: $err',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
                        ),
                        SizedBox(height: 2.h),
                        ElevatedButton.icon(
                          onPressed: () => ref.refresh(msRoutinesProvider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C1E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text('retry'.tr(context), style: TextStyle(fontSize: 13.sp)),
                        ),
                      ],
                    ),
                  ),
                ),
              if (tomorrowCategory == 'Rest') _buildRestCard(context),
              _buildWeekView(context),
              _buildRecentSessions(context, history),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting(
    BuildContext context, {
    String? firstName,
    String initials = '?',
  }) {
    final greeting = firstName != null
        ? '${'good_morning'.tr(context)}, $firstName ??'
        : '${'good_morning'.tr(context)} ??';
    return Padding(
      padding: EdgeInsets.fromLTRB(4.8.w, 2.h, 4.8.w, 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getFormattedDate(),
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 0.4.h),
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1C1C1E),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 9.w,
                height: 9.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: const Color(0xFF1C1C1E),
                      size: 16.sp,
                    ),
                    PositionedDirectional(
                      top: 1.5.w,
                      end: 1.5.w,
                      child: Container(
                        width: 2.w,
                        height: 2.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 2.w),
              Container(
                width: 9.w,
                height: 9.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayRestCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(4.8.w),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(5.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 1.5.w,
                height: 1.5.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 1.5.w),
              Text(
                'today_recovery'.tr(context),
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'rest_day'.tr(context),
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'active_recovery_desc'.tr(context),
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4.w),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_walk_rounded,
                  color: const Color(0xFF007AFF),
                  size: 24.sp,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'suggested_activity'.tr(context),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'light_walk_15_20'.tr(context),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCompletedCard(
    BuildContext context,
    CompletedSession session,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.h),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(5.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 1.5.w,
                height: 1.5.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 1.5.w),
              Text(
                'today_workout_completed'.tr(context),
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            '${session.routineName} \u2705',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'crushed_workout_desc'.tr(context),
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            children: [
              _buildMiniStat('⌚', '${session.durationMinutes}m'),
              SizedBox(width: 3.w),
              _buildMiniStat(
                '💪',
                '${session.completedSets}/${session.totalSets} ${'sets'.tr(context)}',
              ),
              SizedBox(width: 3.w),
              _buildMiniStat('🔥', '~${session.completedSets * 15} kcal'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 12.sp)),
          SizedBox(width: 1.5.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayHeroCard(
    BuildContext context,
    WidgetRef ref,
    RoutineModel routine,
    int recoveryScore,
  ) {
    int totalSets = routine.exercises.fold(0, (sum, ex) => sum + ex.sets);
    int estTime = totalSets * 3;

    return GestureDetector(
      onTap: () {
        // Go to active session later
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(5.5.w),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                PositionedDirectional(
                  end: -5.w,
                  top: -5.w,
                  child: Container(
                    width: 28.w,
                    height: 28.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 1.5.w,
                                height: 1.5.w,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34C759),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 1.5.w),
                              Text(
                                'today_ai_coach_plan'.tr(context),
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.5.w,
                              vertical: 1.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF34C759,
                              ).withValues(alpha: 0.15),
                              border: Border.all(
                                color: const Color(
                                  0xFF34C759,
                                ).withValues(alpha: 0.3),
                              ),
                              borderRadius: BorderRadius.circular(3.w),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$recoveryScore%',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF34C759),
                                    height: 1,
                                  ),
                                ),
                                SizedBox(height: 0.3.h),
                                Text(
                                  'recovery'.tr(context).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(
                                      0xFF34C759,
                                    ).withValues(alpha: 0.7),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Container(
                                  width: 8.w,
                                  height: 0.4.h,
                                  margin: EdgeInsets.only(top: 0.5.h),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF34C759,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(1.w),
                                  ),
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Container(
                                    width: (recoveryScore / 100) * 8.w,
                                    height: 0.4.h,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF34C759),
                                      borderRadius: BorderRadius.circular(1.w),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${routine.routineName} 🔥',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.6,
                        ),
                      ),
                      SizedBox(height: 0.4.h),
                      Text(
                        routine.description,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Wrap(
                        spacing: 1.5.w,
                        children: [
                          routine.category,
                        ].map((m) => _buildMuscleChip(m)).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                ),
              ),
              child: Row(
                children: [
                  _buildStatBlock(
                    '${routine.exercises.length}',
                    'exercises'.tr(context).toUpperCase(),
                  ),
                  _buildStatBlock(
                    '$estTime ${'min'.tr(context)}',
                    'est_time'.tr(context).toUpperCase(),
                  ),
                  _buildStatBlock('~480', 'calories'.tr(context).toUpperCase()),
                  _buildStatBlock(
                    '$totalSets',
                    'sets'.tr(context).toUpperCase(),
                    noBorder: true,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(5.5.w),
                  bottomRight: Radius.circular(5.5.w),
                ),
              ),
              child: Column(
                children: [
                  ...routine.exercises
                      .take(3)
                      .map(
                        (ex) => _buildPreviewEx(
                          true,
                          ex.name,
                          '${ex.sets}×${ex.reps}',
                        ),
                      ),
                  if (routine.exercises.length > 3)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: 4.w,
                        top: 1.h,
                        bottom: 2.h,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          '+${routine.exercises.length - 3} ${'more_exercises'.tr(context)}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            context.push('/active-session', extra: routine);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C1E),
                            padding: EdgeInsets.symmetric(vertical: 1.8.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3.5.w),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                              SizedBox(width: 1.w),
                              Text(
                                'start_workout'.tr(context),
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      GestureDetector(
                        onTap: () {
                          RoutineEditBottomSheet.show(context, ref, routine);
                        },
                        child: Container(
                          width: 13.w,
                          height: 13.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(3.5.w),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: const Color(0xFF1C1C1E),
                            size: 16.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleChip(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildStatBlock(String val, String lbl, {bool noBorder = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.5.h),
        decoration: BoxDecoration(
          border: noBorder
              ? null
              : Border(
                  right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 0.4.h),
            Text(
              lbl,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.35),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewEx(bool isDone, String name, String sets) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        children: [
          Container(
            width: 2.w,
            height: 2.w,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          Text(
            sets,
            style: TextStyle(fontSize: 11.sp, color: const Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }

  Widget _buildRestCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5.5.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(4.w),
            ),
            alignment: Alignment.center,
            child: Text('🧘', style: TextStyle(fontSize: 20.sp)),
          ),
          SizedBox(width: 3.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'tomorrow_rest_day'.tr(context),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'active_recovery_light_walk'.tr(context),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF8E8E93),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekView(BuildContext context) {
    final now = DateTime.now();
    final offsetFromSaturday = (now.weekday + 1) % 7;
    final startOfWeek = now.subtract(Duration(days: offsetFromSaturday));

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'this_week'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              Text(
                'full_plan'.tr(context),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final d = startOfWeek.add(Duration(days: i));
              final dayStr = d.day.toString();
              const daysShort = [
                'MON',
                'TUE',
                'WED',
                'THU',
                'FRI',
                'SAT',
                'SUN',
              ];
              final label = daysShort[d.weekday - 1];
              final type = _getCategoryForDay(d.weekday);
              final isToday =
                  d.day == now.day &&
                  d.month == now.month &&
                  d.year == now.year;
              final isDone = d.isBefore(now) && !isToday && type != 'Rest';

              return _buildWvDay(
                label,
                dayStr,
                type == 'Shoulders' ? 'Shouldr' : type,
                isDone,
                isToday,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWvDay(
    String l,
    String n,
    String type,
    bool isDone,
    bool isToday,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFF1C1C1E) : Colors.transparent,
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Column(
        children: [
          Text(
            l,
            style: TextStyle(
              fontSize: 8.sp,
              fontWeight: FontWeight.w800,
              color: isToday
                  ? Colors.white.withValues(alpha: 0.4)
                  : const Color(0xFF8E8E93),
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            n,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w900,
              color: isToday ? Colors.white : const Color(0xFF3A3A3C),
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            type,
            style: TextStyle(
              fontSize: 7.5.sp,
              fontWeight: FontWeight.w800,
              color: isToday
                  ? Colors.white.withValues(alpha: 0.5)
                  : const Color(0xFF8E8E93),
            ),
          ),
          SizedBox(height: 0.5.h),
          Container(
            width: 1.w,
            height: 1.w,
            decoration: BoxDecoration(
              color: isToday || isDone
                  ? const Color(0xFF34C759)
                  : const Color(0xFFD1D1D6),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessions(BuildContext context, List<CompletedSession> history) {
    // Show the 5 most recent sessions (newest first — history is already sorted)
    final recent = history.take(5).toList();

    return Padding(
      padding: EdgeInsets.only(top: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.8.w),
            child: Text(
              'recent_sessions'.tr(context),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          SizedBox(height: 1.5.h),
          if (recent.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.8.w),
              child: Text(
                'no_sessions_yet'.tr(context),
                style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 4.8.w),
              child: Row(
                children: recent.map((session) {
                  // Format duration: "58m" or "1h 5m"
                  final mins = session.durationMinutes;
                  final durationLabel = mins >= 60
                      ? '${mins ~/ 60}h ${mins % 60}m'
                      : '${mins}m';
                  final meta = '$durationLabel · ${session.completedSets}/${session.totalSets} sets';
                  return _buildRecentCard(
                    session.dayName.toUpperCase(),
                    session.routineName,
                    meta,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentCard(String day, String title, String meta) {
    return Container(
      width: 35.w,
      margin: EdgeInsetsDirectional.only(end: 3.w),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93),
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: 0.6.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 0.4.h),
          Text(
            meta,
            style: TextStyle(
              fontSize: 11.sp,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }
}
