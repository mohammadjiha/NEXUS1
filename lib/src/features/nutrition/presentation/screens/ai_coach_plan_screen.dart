import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../coaching/domain/models/ai_coach_plan.dart';
import '../../../coaching/providers/ai_coach_plan_provider.dart';
import '../../services/alarm_service.dart';
import '../widgets/nutrition_settings_sheet.dart';

class AiCoachPlanScreen extends ConsumerWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const AiCoachPlanScreen({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiPlanAsync = ref.watch(aiCoachPlanProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => navigatorKey.currentState!.pop(),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16.sp, color: const Color(0xFF1C1C1E)),
        ),
        title: Text(
          'ai_coach_plan'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () {
              NutritionSettingsSheet.show(context, navigatorKey.currentState!);
            },
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 3.w),
              child: Icon(Icons.settings_rounded, color: const Color(0xFF1C1C1E), size: 20.sp),
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(aiCoachPlanProvider.notifier).refreshPlan();
            },
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 4.w),
              child: Icon(Icons.refresh_rounded, color: const Color(0xFF1C1C1E), size: 20.sp),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: aiPlanAsync.when(
          data: (plan) {
            if (plan == null) {
              return Center(child: Text('unable_generate_plan'.tr(context), style: TextStyle(fontSize: 12.sp)));
            }
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Column(
                children: [
                  _buildAiBox(plan.summary, context),
                  _buildSummaryRing(plan, context),
                  _buildMealsSection(plan, ref, context),
                ],
              ),
            );
          },
          loading: () => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                SizedBox(height: 2.h),
                Text('analyzing_profile_plan'.tr(context), style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93))),
              ],
            ),
          ),
          error: (e, st) => Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, size: 10.w, color: const Color(0xFFFF3B30)),
                  SizedBox(height: 2.h),
                  Text(
                    '${'error_colon'.tr(context)} $e',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
                  ),
                  SizedBox(height: 2.h),
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(aiCoachPlanProvider),
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
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFF5F5F7),
              const Color(0xFFF5F5F7).withValues(alpha: 0.0),
            ],
            stops: const [0.68, 1.0],
          ),
        ),
        child: ElevatedButton(
          onPressed: aiPlanAsync.isLoading || aiPlanAsync.value == null ? null : () async {
            await ref.read(aiCoachPlanProvider.notifier).syncProgressToCloud();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('progress_saved_synced'.tr(context))),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007AFF),
            minimumSize: Size(double.infinity, 6.5.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5.w)),
            elevation: 0,
            disabledBackgroundColor: const Color(0xFFE5E5EA),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (aiPlanAsync.isLoading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              else ...[
                Icon(Icons.save_rounded, color: Colors.white, size: 16.sp),
                SizedBox(width: 2.w),
              ],
              Text(
                'save_progress'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiBox(String summary, BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(3.5.w),
        border: Border.all(color: const Color(0xFFB5D4F4), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(2.w),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16.sp),
          ),
          SizedBox(width: 2.5.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14.sp, color: const Color(0xFF0C447C), height: 1.4),
                children: [
                  TextSpan(text: 'ai_coach_colon'.tr(context), style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: summary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRing(AICoachPlan plan, BuildContext context) {
    int totalProteinTarget = plan.protein.target == 0 ? 1 : plan.protein.target;
    int totalCarbsTarget = plan.carbs.target == 0 ? 1 : plan.carbs.target;
    int totalFatTarget = plan.fat.target == 0 ? 1 : plan.fat.target;

    int totalTargetMacros = totalProteinTarget + totalCarbsTarget + totalFatTarget;
    double proteinPct = totalProteinTarget / totalTargetMacros;
    double carbsPct = totalCarbsTarget / totalTargetMacros;
    double fatPct = totalFatTarget / totalTargetMacros;
    int currentCalories = 0;
    for (final m in plan.meals) {
      if (m.isEaten) currentCalories += m.totalCalories;
    }
    int caloriesLeft = plan.totalCalories - currentCalories;
    if (caloriesLeft < 0) caloriesLeft = 0;

    double pPctVal = plan.protein.target == 0 ? 0 : plan.protein.current / plan.protein.target;
    double cPctVal = plan.carbs.target == 0 ? 0 : plan.carbs.current / plan.carbs.target;
    double fPctVal = plan.fat.target == 0 ? 0 : plan.fat.current / plan.fat.target;

    int pPctDisplay = (pPctVal * 100).toInt();
    int cPctDisplay = (cPctVal * 100).toInt();
    int fPctDisplay = (fPctVal * 100).toInt();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 2.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'todays_targets'.tr(context),
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E)),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                SizedBox(
                  width: 32.w,
                  height: 32.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(32.w, 32.w),
                        painter: _MacroRingPainter(
                          proteinPct: proteinPct,
                          carbsPct: carbsPct,
                          fatPct: fatPct,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$currentCalories', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.5, height: 1)),
                          SizedBox(height: 0.2.h),
                          Text("${'of_text'.tr(context)} ${plan.totalCalories}", style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF8E8E93))),
                          SizedBox(height: 0.2.h),
                          Text("$caloriesLeft ${'left_text'.tr(context)}", style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: const Color(0xFF34C759))),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    children: [
                      _buildMacroBar('protein_title'.tr(context), '${plan.protein.current}g', '$pPctDisplay%', '${plan.protein.target}g', pPctVal.clamp(0.0, 1.0), const Color(0xFF007AFF)),
                      SizedBox(height: 1.h),
                      _buildMacroBar('carbs_title'.tr(context), '${plan.carbs.current}g', '$cPctDisplay%', '${plan.carbs.target}g', cPctVal.clamp(0.0, 1.0), const Color(0xFFFF9500)),
                      SizedBox(height: 1.h),
                      _buildMacroBar('fat_title'.tr(context), '${plan.fat.current}g', '$fPctDisplay%', '${plan.fat.target}g', fPctVal.clamp(0.0, 1.0), const Color(0xFFFF3B30)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.symmetric(vertical: 2.h),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F0F5), width: 0.5)),
            ),
            child: Row(
              children: [
                _buildStatColumn('${plan.calorieDeficit}', 'deficit_upper'.tr(context), const Color(0xFF34C759)),
                _buildStatColumn('${plan.caloriesBurned}', 'burned_upper'.tr(context), const Color(0xFFFF9500)),
                _buildStatColumn('${plan.waterLiters}L', 'water_upper'.tr(context), const Color(0xFF007AFF)),
                _buildStatColumn(plan.workoutFocus, 'today_upper'.tr(context), const Color(0xFF5B3FBF), border: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String val, String lbl, Color color, {bool border = true}) {
    return Expanded(
      child: Container(
        decoration: border ? const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFFF0F0F5), width: 0.5))) : null,
        child: Column(
          children: [
            Text(val, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: color)),
            SizedBox(height: 0.2.h),
            Text(lbl, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93))),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroBar(String name, String val, String pct, String goal, double pctVal, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF3A3A3C))),
            Text(val, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
          ],
        ),
        SizedBox(height: 0.5.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(1.h),
          child: LinearProgressIndicator(
            value: pctVal,
            backgroundColor: const Color(0xFFF0F0F5),
            color: color,
            minHeight: 0.8.h,
          ),
        ),
        SizedBox(height: 0.5.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(pct, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: color)),
            Text('/ $goal', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: const Color(0xFF8E8E93))),
          ],
        ),
      ],
    );
  }

  Widget _buildMealsSection(AICoachPlan plan, WidgetRef ref, BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 1.5.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ai_suggested_meals'.tr(context),
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E)),
                ),
                GestureDetector(
                  onTap: () => ref.read(aiCoachPlanProvider.notifier).refreshPlan(),
                  child: Text(
                    'refresh_text'.tr(context),
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF007AFF)),
                  ),
                ),
              ],
            ),
          ),
          ...plan.meals.asMap().entries.map((entry) {
            final idx = entry.key;
            final meal = entry.value;
            final isLast = idx == plan.meals.length - 1;
            final isPostWorkout = meal.name.toLowerCase().contains('post');
            
            final mealRow = _buildMealRow(
              context: context,
              ref: ref,
              idx: idx,
              meal: meal,
              iconBg: isPostWorkout ? const Color(0xFFE8FFF0) : (idx % 2 == 0 ? const Color(0xFFFFF8E8) : const Color(0xFFE8F5FF)),
              color: isPostWorkout ? const Color(0xFF34C759) : const Color(0xFF007AFF),
              border: !isPostWorkout, // If post-workout, we handle border differently
              foods: meal.foods.map((food) => _buildFoodItem(food.emoji, food.name, food.macros, '${food.calories}')).toList(),
            );

            if (isPostWorkout) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF34C759), width: 0.5),
                  borderRadius: isLast 
                      ? BorderRadius.only(bottomLeft: Radius.circular(4.5.w), bottomRight: Radius.circular(4.5.w))
                      : BorderRadius.zero,
                ),
                child: Column(
                  children: [
                    mealRow,
                    Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'anabolic_window'.tr(context),
                          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800, color: const Color(0xFF34C759)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return mealRow;
          }),
        ],
      ),
    );
  }

  Widget _buildMealRow({
    required BuildContext context,
    required WidgetRef ref,
    required int idx,
    required AIPlanMeal meal,
    required Color iconBg,
    required Color color,
    required List<Widget> foods,
    bool border = true,
  }) {
    return Container(
      decoration: border ? const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF5F5F7), width: 0.5))) : null,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ref.read(aiCoachPlanProvider.notifier).toggleMealEaten(idx),
                  child: Container(
                    width: 7.w, height: 7.w,
                    margin: EdgeInsetsDirectional.only(end: 3.w),
                    decoration: BoxDecoration(
                      color: meal.isEaten ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(1.5.w),
                      border: Border.all(color: meal.isEaten ? color : const Color(0xFFE5E5EA), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: meal.isEaten ? Icon(Icons.check, color: Colors.white, size: 14.sp) : null,
                  ),
                ),
                Container(
                  width: 10.w, height: 10.w,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(2.5.w)),
                  alignment: Alignment.center,
                  child: Text(meal.icon, style: TextStyle(fontSize: 20.sp)),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      TimeOfDay initialTime = TimeOfDay.now();
                      try {
                        final timeStr = meal.time.toUpperCase();
                        final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)?').firstMatch(timeStr);
                        if (match != null) {
                          int hour = int.parse(match.group(1)!);
                          int minute = int.parse(match.group(2)!);
                          final ampm = match.group(3);
                          if (ampm == 'PM' && hour != 12) hour += 12;
                          if (ampm == 'AM' && hour == 12) hour = 0;
                          initialTime = TimeOfDay(hour: hour, minute: minute);
                        }
                      } catch (_) {}

                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                      );
                      
                      if (selectedTime != null && context.mounted) {
                        // Format time to "08:00 AM" style
                        final hour = selectedTime.hour == 0 ? 12 : (selectedTime.hour > 12 ? selectedTime.hour - 12 : selectedTime.hour);
                        final ampm = selectedTime.hour >= 12 ? 'PM' : 'AM';
                        final minuteStr = selectedTime.minute.toString().padLeft(2, '0');
                        final hourStr = hour.toString().padLeft(2, '0');
                        const newTimeStr = r'$hourStr:$minuteStr $ampm';
                        
                        ref.read(aiCoachPlanProvider.notifier).updateMealTime(idx, newTimeStr);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${meal.name} - ${meal.time}', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
                            SizedBox(width: 1.5.w),
                            Icon(Icons.edit_rounded, size: 12.sp, color: const Color(0xFF8E8E93)),
                          ],
                        ),
                        SizedBox(height: 0.2.h),
                        Text(meal.macros, style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93))),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    try {
                      final timeStr = meal.time.toUpperCase();
                      int hour = 8;
                      int minute = 0;
                      final match = RegExp(r'(\d+):(\d+)\s*(AM|PM)?').firstMatch(timeStr);
                      if (match != null) {
                        hour = int.parse(match.group(1)!);
                        minute = int.parse(match.group(2)!);
                        final ampm = match.group(3);
                        if (ampm == 'PM' && hour != 12) hour += 12;
                        if (ampm == 'AM' && hour == 12) hour = 0;
                      }
                      await AlarmService().scheduleMealAlarm(
                        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        title: '${'time_for'.tr(context)} ${meal.name}!',
                        body: meal.macros,
                        time: TimeOfDay(hour: hour, minute: minute),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${'alarm_set_for'.tr(context)} ${meal.name} at ${meal.time}!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${'error_scheduling_alarm'.tr(context)} $e')),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: 9.w, height: 9.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(2.w),
                      border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.alarm_add_rounded, color: color, size: 16.sp),
                  ),
                ),
              ],
            ),
          ),
          ...foods,
        ],
      ),
    );
  }

  Widget _buildFoodItem(String emoji, String name, String macros, String cal) {
    return Container(
      padding: EdgeInsets.fromLTRB(5.w, 1.5.h, 4.w, 1.5.h),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF8F8F8), width: 0.5))),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
                SizedBox(height: 0.2.h),
                Text(macros, style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93))),
              ],
            ),
          ),
          Text('$cal kcal', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
        ],
      ),
    );
  }
}

class _MacroRingPainter extends CustomPainter {
  final double proteinPct;
  final double carbsPct;
  final double fatPct;

  _MacroRingPainter({required this.proteinPct, required this.carbsPct, required this.fatPct});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 2.5.w;

    final bgPaint = Paint()
      ..color = const Color(0xFFE5E5EA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Background ring
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);
    const startAngle = -math.pi / 2; // top

    void drawArc(double sweep, Color color) {
      if (sweep <= 0) return;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweep * 2 * math.pi, false, paint);
    }

    // Protein: blue, Carbs: orange, Fat: red
    double offset = 0;
    final proteinSweep = proteinPct.clamp(0.0, 1.0);
    final carbsSweep = carbsPct.clamp(0.0, 1.0 - proteinSweep);
    final fatSweep = fatPct.clamp(0.0, 1.0 - proteinSweep - carbsSweep);

    final proteinPaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final carbsPaint = Paint()
      ..color = const Color(0xFFFF9500)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fatPaint = Paint()
      ..color = const Color(0xFFFF3B30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (proteinSweep > 0) {
      canvas.drawArc(rect, startAngle + offset * 2 * math.pi, proteinSweep * 2 * math.pi, false, proteinPaint);
      offset += proteinSweep;
    }
    if (carbsSweep > 0) {
      canvas.drawArc(rect, startAngle + offset * 2 * math.pi, carbsSweep * 2 * math.pi, false, carbsPaint);
      offset += carbsSweep;
    }
    if (fatSweep > 0) {
      canvas.drawArc(rect, startAngle + offset * 2 * math.pi, fatSweep * 2 * math.pi, false, fatPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MacroRingPainter oldDelegate) {
    return oldDelegate.proteinPct != proteinPct ||
        oldDelegate.carbsPct != carbsPct ||
        oldDelegate.fatPct != fatPct;
  }
}
