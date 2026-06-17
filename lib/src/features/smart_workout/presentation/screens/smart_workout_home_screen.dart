import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/subscription_action.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../models/routine_model.dart';
import '../../providers/routines_provider.dart';
import '../../providers/split_setup_provider.dart';
import '../../providers/workout_history_provider.dart';
import '../widgets/routine_edit_bottom_sheet.dart';

class SmartWorkoutHomeScreen extends ConsumerWidget {
  const SmartWorkoutHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(workoutHistoryProvider);
    CompletedSession? completedSessionToday;
    if (history.isNotEmpty) {
      final last = history.first;
      if (last.timestampIso != null) {
        try {
          final t = DateTime.parse(last.timestampIso!).toLocal();
          final now = DateTime.now();
          if (t.year == now.year && t.month == now.month && t.day == now.day) {
            completedSessionToday = last;
          }
        } catch (_) {}
      }
    }

    final routinesAsync = ref.watch(msRoutinesProvider);
    final generatedPlan = ref.watch(generatedPlanProvider);
    
    final setupData = ref.watch(splitSetupDataProvider).value;
    final planStartDate = setupData?.planStartDate ?? DateTime.now();
    final now = DateTime.now();
    final differenceInDays = DateTime(now.year, now.month, now.day)
        .difference(DateTime(planStartDate.year, planStartDate.month, planStartDate.day))
        .inDays;
    final todayIndex = differenceInDays >= 0 ? (differenceInDays % 7) : 0;
    
    final today = generatedPlan.isNotEmpty ? generatedPlan[todayIndex] : null;
    final routineId = today?.assignedRoutineId;
    
    // Find the current routine to pass its category to the provider
    final routine = routinesAsync.maybeWhen(
      data: (routines) => routineId != null 
          ? routines.firstWhere((r) => r.id == routineId, orElse: () => routines.first)
          : null,
      orElse: () => null,
    );
    
    final recoveryScore = ref.watch(recoveryScoreProvider(routine?.category ?? 'General'));
    final userModel = ref.watch(currentUserModelProvider).asData?.value;
    final firstName = userModel?.firstName ?? ref.watch(currentUserFirstNameProvider);
    final initials = ref.watch(currentUserInitialsProvider);

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final createdAt = userModel?.createdAt ?? DateTime.now();
    
    // Custom formatted date
    final joinedDateStr = DateFormat('MMM d').format(createdAt).toUpperCase();
    final memberSinceStr = isArabic ? 'تاريخ التسجيل: $joinedDateStr' : 'MEMBER SINCE $joinedDateStr';

    // Dynamic greeting
    final hour = DateTime.now().hour;
    String greetingText = isArabic 
        ? (hour < 12 ? 'صباح الخير' : 'مساء الخير')
        : (hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening'));
        
    if (firstName != null && firstName.isNotEmpty) {
      greetingText = '$greetingText, $firstName 👋';
    } else {
      greetingText = '$greetingText 👋';
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
              // Greeting
              Padding(
                padding: EdgeInsetsDirectional.only(start: 4.4.w, end: 4.4.w, top: 2.h, bottom: 2.5.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(memberSinceStr, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93), letterSpacing: 0.5)),
                          SizedBox(height: 0.4.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(greetingText, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.5)),
                          ),
                        ],
                      ),
                    ),
                      Row(
                      children: [
                        // Edit Plan
                        GestureDetector(
                          onTap: () {
                            final setupData = ref.read(splitSetupDataProvider).value;
                            if (setupData != null && setupData.planStartDate != null) {
                              final startDate = setupData.planStartDate!;
                              final startOfPlan = DateTime(startDate.year, startDate.month, startDate.day);
                              final endOfPlan = startOfPlan.add(const Duration(days: 7));
                              final now = DateTime.now();
                              
                              if (now.isAfter(startOfPlan.subtract(const Duration(days: 1))) && now.isBefore(endOfPlan)) {
                                final history = ref.read(workoutHistoryProvider);
                                final hasCompletedSession = history.any((session) {
                                  if (session.timestampIso == null) return false;
                                  try {
                                    final sessionDate = DateTime.parse(session.timestampIso!);
                                    return sessionDate.isAfter(startOfPlan.subtract(const Duration(seconds: 1)));
                                  } catch (_) {
                                    return false;
                                  }
                                });
                                
                                if (hasCompletedSession) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('already_started_week'.tr(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      backgroundColor: const Color(0xFF1C1C1E),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      margin: EdgeInsets.all(4.w),
                                    ),
                                  );
                                  return;
                                }
                              }
                            }
                            ref.read(splitSetupStatusProvider.notifier).resetSetup();
                          },
                          child: Container(
                            width: 11.w, height: 11.w,
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5E5EA))),
                            child: Icon(Icons.tune_rounded, color: const Color(0xFF1C1C1E), size: 20.sp),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              // Today Card
              routinesAsync.when(
                data: (routines) {
                  if (routines.isEmpty) return const SizedBox();
                  if (completedSessionToday != null) return _buildTodayCompletedCard(completedSessionToday, context);
                  
                  final setupDataData = ref.read(splitSetupDataProvider).value;
                  final planStartDateData = setupDataData?.planStartDate ?? DateTime.now();
                  final nowData = DateTime.now();
                  final diffData = DateTime(nowData.year, nowData.month, nowData.day)
                      .difference(DateTime(planStartDateData.year, planStartDateData.month, planStartDateData.day))
                      .inDays;
                  final indexData = diffData >= 0 ? (diffData % 7) : 0;
                  final today = generatedPlan.isNotEmpty ? generatedPlan[indexData] : null;
                  
                  if (today == null || today.isRest || today.assignedRoutineId == null) {
                    return _buildRestDayCard(context);
                  }

                  final setupData = ref.read(splitSetupDataProvider).value;
                  if (setupData?.splitType == 'custom') {
                    final restrictedCat = today.categories.isNotEmpty ? today.categories.first : 'Chest';
                    return _buildCustomSplitQuickLog(restrictedCat, context);
                  }

                  final routine = routines.firstWhere((r) => r.id == routineId, orElse: () => routines.first);
                  return _buildTodayCard(context, ref, routine, recoveryScore);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text("${'error_loading_routines'.tr(context)}: $err")),
              ),

              SizedBox(height: 2.h),

              // Upcoming Strip
              _buildUpcomingStrip(ref, context),

              SizedBox(height: 2.h),

              // History Strip
              _buildHistoryStrip(ref, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestDayCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(6.w),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('today_ai_coach_plan'.tr(context), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha:0.4), letterSpacing: 0.7)),
                SizedBox(height: 1.h),
                Text('rest_day'.tr(context), style: TextStyle(fontSize: 21.sp, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
                SizedBox(height: 0.5.h),
                Text('rest_day_desc'.tr(context), style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha:0.4))),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.08), borderRadius: BorderRadius.circular(4.w)),
            child: Icon(Icons.nightlight_round, color: const Color(0xFF34C759), size: 24.sp),
          )
        ],
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context, WidgetRef ref, RoutineModel routine, int recoveryScore) {
    int totalSets = routine.exercises.fold(0, (sum, ex) => sum + ex.sets);
    int estTime = totalSets * 3; // Approx 3 mins per set including rest
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          // Card Head (Black area)
          Container(
            padding: EdgeInsetsDirectional.only(start: 5.w, end: 5.w, top: 4.h, bottom: 3.5.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('today_ai_coach_plan'.tr(context), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha:0.4), letterSpacing: 0.7)),
                          SizedBox(height: 1.h),
                          Text(routine.routineName, style: TextStyle(fontSize: 21.sp, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
                          SizedBox(height: 0.5.h),
                          Text(routine.description, style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha:0.4))),
                        ],
                      ),
                    ),
                    SizedBox(width: 4.w),
                    // Recovery Badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.5.h),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.08), borderRadius: BorderRadius.circular(3.w)),
                      child: Column(
                        children: [
                          Text('$recoveryScore%', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF34C759))),
                          SizedBox(height: 0.3.h),
                          Text('recovery'.tr(context), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF34C759).withValues(alpha:0.6), letterSpacing: 0.3)),
                          SizedBox(height: 1.h),
                          Container(
                            width: 10.w, height: 4,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.15), borderRadius: BorderRadius.circular(2)),
                            alignment: AlignmentDirectional.centerStart,
                            child: Container(width: (recoveryScore / 100) * 10.w, height: 4, decoration: BoxDecoration(color: const Color(0xFF34C759), borderRadius: BorderRadius.circular(2))),
                          )
                        ],
                      ),
                    )
                  ],
                ),
                SizedBox(height: 1.h),
                // Muscles Strip
                Wrap(
                  spacing: 2.w,
                  children: [routine.category].map((m) => Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.1), borderRadius: BorderRadius.circular(5.w)),
                    child: Text(m, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha:0.75))),
                  )).toList(),
                ),
                SizedBox(height: 3.h),
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStat(routine.exercises.length.toString(), 'exercises'.tr(context)),
                    _buildStat('$estTime ${'min'.tr(context)}', 'est_time'.tr(context)),
                    _buildStat('~480', 'calories'.tr(context)),
                    _buildStat(totalSets.toString(), 'sets'.tr(context)),
                  ],
                )
              ],
            ),
          ),
          
          // Card Body (Exercises)
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...routine.exercises.take(3).map((ex) => Padding(
                  padding: EdgeInsets.only(bottom: 1.5.h),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                      SizedBox(width: 2.5.w),
                                  Expanded(
                                    child: Text(
                                      ex.name, 
                                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E)),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 2.w),
                                  Text('${ex.sets}${'sets_label'.tr(context)} × ${ex.reps}', style: TextStyle(fontSize: 15.sp, color: const Color(0xFF8E8E93))),
                    ],
                  ),
                )),
                if (routine.exercises.length > 3)
                  GestureDetector(
                    onTap: () => _showRoutineDetails(context, routine),
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(start: 4.w, bottom: 2.h),
                      child: Text('+${routine.exercises.length - 3} ${'more_exercises'.tr(context)}', style: TextStyle(fontSize: 15.sp, color: const Color(0xFF007AFF), fontWeight: FontWeight.w600)),
                    ),
                  ),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          runIfSubscriptionActive(ref, context, () {
                            final setupData = ref.read(splitSetupDataProvider).value;
                            if (setupData?.splitType == 'custom') {
                              context.push('/quick-log', extra: routine.category);
                            } else {
                              context.push('/active-session', extra: routine);
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 1.8.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(3.5.w),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18.sp),
                              SizedBox(width: 2.w),
                              Text('start_workout'.tr(context), style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    GestureDetector(
                      onTap: () {
                        RoutineEditBottomSheet.show(context, ref, routine);
                      },
                      child: Container(
                        width: 13.w, height: 13.w,
                        decoration: BoxDecoration(color: const Color(0xFFF5F5F7), border: Border.all(color: const Color(0xFFE5E5EA)), borderRadius: BorderRadius.circular(3.5.w)),
                        child: Icon(Icons.edit_outlined, color: const Color(0xFF3A3A3C), size: 16.sp),
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStat(String val, String lbl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800, color: Colors.white)),
        SizedBox(height: 0.3.h),
        Text(lbl, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha:0.4), letterSpacing: 0.3)),
      ],
    );
  }

  Widget _buildCustomSplitQuickLog(String restrictedCategory, BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/quick-log', extra: restrictedCategory),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.4.w),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFD1D1D6), strokeAlign: BorderSide.strokeAlignOutside),
        ),
        child: Row(
          children: [
            Container(
              width: 11.w, height: 11.w,
              decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(2.5.w)),
              child: Icon(Icons.add_rounded, color: const Color(0xFF007AFF), size: 20.sp),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${'quick_log_dash'.tr(context)} $restrictedCategory', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E))),
                  SizedBox(height: 0.3.h),
                  Text('choose_routine_today'.tr(context), style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93))),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: const Color(0xFFD1D1D6), size: 14.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLog(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Need BuildContext, we are inside a widget that has it but we should pass it or use ConsumerWidget context
      },
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: () => context.push('/quick-log'),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.4.w),
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4.w),
                border: Border.all(color: const Color(0xFFD1D1D6), strokeAlign: BorderSide.strokeAlignOutside),
              ),
              child: Row(
                children: [
                  Container(
                    width: 11.w, height: 11.w,
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(2.5.w)),
                    child: Icon(Icons.add_rounded, color: const Color(0xFF007AFF), size: 20.sp),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('quick_log_free_session'.tr(context), style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E))),
                        SizedBox(height: 0.3.h),
                        Text('train_what_you_want'.tr(context), style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: const Color(0xFFC7C7CC), size: 18.sp),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildHistoryStrip(WidgetRef ref, BuildContext context) {
    final history = ref.watch(workoutHistoryProvider);

    final now = DateTime.now();
    final offsetFromSaturday = (now.weekday + 1) % 7;
    final startOfWeek = now.subtract(Duration(days: offsetFromSaturday));
    final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final List<CompletedSession> filteredHistory = [];
    final Set<String> seenRoutines = {};

    for (final item in history) {
      if (item.timestampIso != null) {
        final sDate = DateTime.parse(item.timestampIso!);
        final sDay = DateTime(sDate.year, sDate.month, sDate.day);
        
        // Include only sessions from the current week
        if (!sDay.isBefore(startOfWeekDate)) {
          // Deduplicate by routine name
          if (!seenRoutines.contains(item.routineName)) {
            filteredHistory.add(item);
            seenRoutines.add(item.routineName);
          }
        }
      }
    }

    if (filteredHistory.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.4.w),
        child: Text('no_recent_sessions'.tr(context), style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.4.w),
          child: Text('recent_sessions'.tr(context), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93), letterSpacing: 0.5)),
        ),
        SizedBox(height: 1.5.h),
        SizedBox(
          height: 17.5.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.4.w),
            itemCount: filteredHistory.length,
            itemBuilder: (context, index) {
              final item = filteredHistory[index];
              return Container(
                margin: EdgeInsetsDirectional.only(end: 3.w),
                padding: EdgeInsets.all(4.w),
                width: 40.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4.w),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.dayName} ${item.date.split(' ')[1]}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93), letterSpacing: 0.4)),
                    SizedBox(height: 1.h),
                    Text(item.routineName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), height: 1.2)),
                    SizedBox(height: 0.8.h),
                    Text('${item.durationMinutes} ${'min'.tr(context)} · ${item.completedSets} ${'sets'.tr(context).toLowerCase()}', style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93))),
                    const Spacer(),
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildUpcomingStrip(WidgetRef ref, BuildContext context) {
    final generatedPlan = ref.watch(generatedPlanProvider);
    final routinesAsync = ref.watch(msRoutinesProvider);
    
    // Get future training days (exclude today and rest days)
    final futureDays = generatedPlan.skip(1).where((d) => !d.isRest && d.assignedRoutineId != null).toList();

    if (futureDays.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.4.w),
          child: Text('upcoming_sessions'.tr(context), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93), letterSpacing: 0.5)),
        ),
        SizedBox(height: 1.5.h),
        SizedBox(
          height: 17.5.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.4.w),
            itemCount: futureDays.length,
            itemBuilder: (context, index) {
              final day = futureDays[index];
              return routinesAsync.when(
                data: (routines) {
                  final routine = routines.firstWhere(
                    (r) => r.id == day.assignedRoutineId,
                    orElse: () => routines.first
                  );
                  
                  int totalSets = routine.exercises.fold(0, (sum, ex) => sum + ex.sets);
                  int estTime = totalSets * 3;
                  
                  return GestureDetector(
                    onTap: () {
                      context.push('/active-session', extra: {
                        'routine': routine,
                        'isViewOnly': true,
                        'scheduledDay': day.dayName
                      });
                    },
                    child: Container(
                      margin: EdgeInsetsDirectional.only(end: 3.w),
                      padding: EdgeInsets.all(4.w),
                      width: 40.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4.w),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${day.dayName} ${day.date.split(' ').last}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93), letterSpacing: 0.4)),
                          SizedBox(height: 1.h),
                          Text(routine.routineName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), height: 1.2)),
                          SizedBox(height: 0.8.h),
                          Text('$estTime ${'min'.tr(context)} · $totalSets ${'sets'.tr(context).toLowerCase()}', style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93))),
                          const Spacer(),
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle)),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              );
            },
          ),
        )
      ],
    );
  }

  void _showRoutineDetails(BuildContext context, RoutineModel routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildRoutineDetailsSheet(context, routine),
    );
  }

  Widget _buildRoutineDetailsSheet(BuildContext context, RoutineModel routine) {
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(routine.category, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha:0.5), letterSpacing: 0.5)),
                      SizedBox(height: 0.5.h),
                      Text(routine.routineName, style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 16.sp),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(5.w),
              itemCount: routine.exercises.length,
              itemBuilder: (ctx, idx) {
                final ex = routine.exercises[idx];
                return Padding(
                  padding: EdgeInsets.only(bottom: 2.h),
                  child: Row(
                    children: [
                      Container(
                        width: 11.w, height: 11.w,
                        decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(3.w)),
                        alignment: Alignment.center,
                        child: Text('${idx + 1}', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
                      ),
                      SizedBox(width: 3.5.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ex.name, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
                            SizedBox(height: 0.3.h),
                            Text('${ex.sets} ${'sets_label'.tr(context)} × ${ex.reps}', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93))),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTodayCompletedCard(CompletedSession session, BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(6.w),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 1.8.w, height: 1.8.w, decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle)),
              SizedBox(width: 2.w),
              Text('today_workout_completed'.tr(context), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha:0.5), letterSpacing: 0.8)),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(session.routineName, style: TextStyle(fontSize: 23.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.6, height: 1.1)),
              ),
              SizedBox(width: 2.w),
              Text('✅', style: TextStyle(fontSize: 22.sp)),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text('crushed_workout_desc'.tr(context), style: TextStyle(fontSize: 14.5.sp, color: Colors.white.withValues(alpha:0.7), height: 1.4)),
          SizedBox(height: 3.5.h),
          Row(
            children: [
              Expanded(child: _buildMiniStat('⌚', '${session.durationMinutes}m')),
              SizedBox(width: 2.5.w),
              Expanded(child: _buildMiniStat('💪', '${session.completedSets}/${session.totalSets}')),
              SizedBox(width: 2.5.w),
              Expanded(child: _buildMiniStat('🔥', '~${session.completedSets * 15} kcal')),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(String emoji, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.w, vertical: 1.8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: 18.sp)),
          SizedBox(width: 1.5.w),
          Flexible(
            child: Text(text, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
