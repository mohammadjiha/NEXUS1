import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../gamification/services/trophy_service.dart';
import '../../domain/models/diet_template_model.dart';
import '../../services/alarm_service.dart';
import '../widgets/nutrition_settings_sheet.dart';
import 'nutrition_history_screen.dart';

class DailyMealPlanScreen extends ConsumerStatefulWidget {
  final DietTemplateModel template;

  const DailyMealPlanScreen({super.key, required this.template});

  @override
  ConsumerState<DailyMealPlanScreen> createState() =>
      _DailyMealPlanScreenState();
}

class _DailyMealPlanScreenState extends ConsumerState<DailyMealPlanScreen>
    with WidgetsBindingObserver {
  // Store checked food items using a unique key: "mealIndex_itemIndex"
  Set<String> _checkedItems = {};
  Map<String, TimeOfDay> _mealTimes = {};
  late String _todayDateStr;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _todayDateStr = DateTime.now().toIso8601String().split('T')[0];
    _loadSavedTimes();
    _loadDailyChecks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final newDateStr = DateTime.now().toIso8601String().split('T')[0];
      if (newDateStr != _todayDateStr) {
        setState(() {
          _todayDateStr = newDateStr;
          _checkedItems.clear(); // Reset for new day
        });
        _loadDailyChecks(); // Load checks if any for the new day
      }
    }
  }

  String get _planId =>
      widget.template.id.isNotEmpty ? widget.template.id : 'default_plan';

  Future<void> _loadDailyChecks() async {
    final prefs = await SharedPreferences.getInstance();
    final savedChecks = prefs.getStringList(
      'checked_items_${_planId}_$_todayDateStr',
    );
    if (savedChecks != null) {
      setState(() {
        _checkedItems = savedChecks.toSet();
      });
    }
  }

  Future<void> _saveDailyChecks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'checked_items_${_planId}_$_todayDateStr',
      _checkedItems.toList(),
    );
  }

  Future<void> _finishDay(int cKcal, int tKcal, int cP, int cC, int cF) async {
    if (tKcal == 0) return;
    double progress = cKcal / tKcal;

    if (progress < 0.7) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'havent_reached_70'.tr(context),
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.w),
          ),
        ),
      );
      return;
    }

    // Save to history
    final prefs = await SharedPreferences.getInstance();
    final historyStr = prefs.getString('nutrition_history');
    List<dynamic> history = historyStr != null ? jsonDecode(historyStr) : [];

    // Check if today already saved
    final existingIndex = history.indexWhere((e) => e['date'] == _todayDateStr);
    final dayRecord = {
      'date': _todayDateStr,
      'consumedKcal': cKcal,
      'targetKcal': tKcal,
      'protein': cP,
      'carbs': cC,
      'fat': cF,
    };

    if (existingIndex != -1) {
      history[existingIndex] = dayRecord;
    } else {
      history.add(dayRecord);
    }
    await prefs.setString('nutrition_history', jsonEncode(history));

    await _syncProgressToCloud();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'champion_progress_saved'.tr(context),
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.w),
          ),
        ),
      );

      final user = ref.read(currentUserModelProvider).asData?.value;
      if (user != null) {
        ref
            .read(trophyServiceProvider)
            .awardTrophiesOnce(
              context: context,
              uid: user.uid,
              awardId: 'nutrition_finish_${_planId}_$_todayDateStr',
              amount: 10,
              reason: 'completed_daily_meals'.tr(context),
            );
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NutritionHistoryScreen()),
      );
    }
  }

  Future<void> _loadSavedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTimes = prefs.getString('custom_meal_times_$_planId');
    if (savedTimes != null) {
      try {
        final decoded = jsonDecode(savedTimes) as Map<String, dynamic>;
        final Map<String, TimeOfDay> loadedTimes = {};
        decoded.forEach((key, val) {
          final parts = val.toString().split(':');
          loadedTimes[key] = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        });
        setState(() {
          _mealTimes = loadedTimes;
        });
      } catch (e) {
        // Ignored
      }
    }
  }

  void _pickTime(String mealName, int index, BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _mealTimes[mealName] ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _mealTimes[mealName] = picked;
      });

      // Save and reschedule immediately
      final prefs = await SharedPreferences.getInstance();
      Map<String, String> timeMap = {};
      _mealTimes.forEach((key, val) {
        timeMap[key] = '${val.hour}:${val.minute}';
      });
      await prefs.setString(
        'custom_meal_times_$_planId',
        jsonEncode(timeMap),
      );

      await AlarmService().scheduleMealAlarm(
        id: index,
        title: '${'time_for'.tr(context)} $mealName! 🍽️',
        body: 'meal_ready_tracked'.tr(context),
        time: picked,
      );
    }
  }

  void _toggleFood(int mealIndex, int itemIndex) {
    setState(() {
      final key = '${mealIndex}_$itemIndex';
      if (_checkedItems.contains(key)) {
        _checkedItems.remove(key);
      } else {
        _checkedItems.add(key);
      }
    });
    _saveDailyChecks();
    _syncProgressToCloud();
  }

  Future<void> _syncProgressToCloud() async {
    final cKcal = _getConsumedCalories();
    final cP = _getConsumedProtein();
    final cC = _getConsumedCarbs();
    final cF = _getConsumedFat();
    final tKcal = widget.template.totalCalories;

    try {
      final userModel = ref.read(currentUserModelProvider).value;
      if (userModel != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userModel.uid)
            .collection('daily_nutrition')
            .doc(_todayDateStr)
            .set({
              'date': _todayDateStr,
              'proteinTarget': widget.template.macros.protein,
              'proteinCurrent': cP,
              'carbsTarget': widget.template.macros.carbs,
              'carbsCurrent': cC,
              'fatTarget': widget.template.macros.fat,
              'fatCurrent': cF,
              'totalCaloriesTarget': tKcal,
              'workoutFocus': 'Standard Plan',
              'syncedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  // Calculate consumed macros based on checked items
  int _getConsumedCalories() {
    int total = 0;
    for (int i = 0; i < widget.template.meals.length; i++) {
      for (int j = 0; j < widget.template.meals[i].items.length; j++) {
        if (_checkedItems.contains('${i}_$j')) {
          total += widget.template.meals[i].items[j].calories;
        }
      }
    }
    return total;
  }

  int _getConsumedProtein() {
    // We don't have item-level protein in the JSON, only meal-level.
    // For a dynamic tracker to be accurate on a per-item basis, we'd need per-item macros.
    // Since we only have per-item calories, we can approximate macros by distributing meal macros,
    // or we can just track calories at the item level and macros at the meal level when ALL items are checked.
    // To implement the user's idea, let's approximate per-item macros based on their calorie contribution to the meal!
    double totalProtein = 0;
    for (int i = 0; i < widget.template.meals.length; i++) {
      final meal = widget.template.meals[i];
      if (meal.calories == 0) continue;

      for (int j = 0; j < meal.items.length; j++) {
        if (_checkedItems.contains('${i}_$j')) {
          final item = meal.items[j];
          double ratio = item.calories / meal.calories;
          totalProtein += meal.macros.protein * ratio;
        }
      }
    }
    return totalProtein.round();
  }

  int _getConsumedCarbs() {
    double totalCarbs = 0;
    for (int i = 0; i < widget.template.meals.length; i++) {
      final meal = widget.template.meals[i];
      if (meal.calories == 0) continue;

      for (int j = 0; j < meal.items.length; j++) {
        if (_checkedItems.contains('${i}_$j')) {
          final item = meal.items[j];
          double ratio = item.calories / meal.calories;
          totalCarbs += meal.macros.carbs * ratio;
        }
      }
    }
    return totalCarbs.round();
  }

  int _getConsumedFat() {
    double totalFat = 0;
    for (int i = 0; i < widget.template.meals.length; i++) {
      final meal = widget.template.meals[i];
      if (meal.calories == 0) continue;

      for (int j = 0; j < meal.items.length; j++) {
        if (_checkedItems.contains('${i}_$j')) {
          final item = meal.items[j];
          double ratio = item.calories / meal.calories;
          totalFat += meal.macros.fat * ratio;
        }
      }
    }
    return totalFat.round();
  }

  int _getConsumedFiber() {
    double totalFiber = 0;
    for (int i = 0; i < widget.template.meals.length; i++) {
      final meal = widget.template.meals[i];
      if (meal.calories == 0) continue;

      for (int j = 0; j < meal.items.length; j++) {
        if (_checkedItems.contains('${i}_$j')) {
          final item = meal.items[j];
          double ratio = item.calories / meal.calories;
          totalFiber += meal.macros.fiber * ratio;
        }
      }
    }
    return totalFiber.round();
  }

  @override
  Widget build(BuildContext context) {
    int consumedKcal = _getConsumedCalories();
    int consumedP = _getConsumedProtein();
    int consumedC = _getConsumedCarbs();
    int consumedF = _getConsumedFat();
    int consumedFi = _getConsumedFiber();

    int targetKcal = widget.template.totalCalories;
    int targetP = widget.template.macros.protein;
    int targetC = widget.template.macros.carbs;
    int targetF = widget.template.macros.fat;
    int targetFi = widget.template.macros.fiber;
    double targetWater = widget.template.waterLiters;

    double progress = targetKcal == 0 ? 0 : consumedKcal / targetKcal;
    if (progress > 1.0) progress = 1.0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            'daily_meal_plan'.tr(context),
            style: TextStyle(
              color: const Color(0xFF1C1C1E),
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
          actions: [
            if (widget.template.id == 'custom_plan')
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/build_own',
                    arguments: {'initialStep': 3, 'forceManual': true},
                  );
                },
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: 3.w),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: const Color(0xFF1C1C1E),
                    size: 20.sp,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                final startDateStr = prefs.getString(
                  'nutrition_plan_start_date',
                );
                if (startDateStr != null) {
                  final startDate = DateTime.parse(startDateStr);
                  final diff = DateTime.now().difference(startDate).inDays;
                  if (diff < 7) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${'must_wait_week'.tr(context)}${7 - diff} ${'days_left'.tr(context)}',
                        ),
                        backgroundColor: const Color(0xFFFF3B30),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                }
                // If >= 7 days or no start date (legacy), allow reset
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      'change_diet_plan_title'.tr(context),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      'change_diet_plan_desc'.tr(context),
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('cancel'.tr(context)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                        ),
                        onPressed: () async {
                          final p = await SharedPreferences.getInstance();
                          await p.remove('nutrition_active_template_json');
                          await p.remove('nutrition_last_flow_path');
                          await p.remove('nutrition_plan_start_date');
                          if (mounted) {
                            Navigator.pop(ctx);
                            Navigator.pushReplacementNamed(
                              context,
                              '/',
                            ); // Reset flow
                          }
                        },
                        child: Text(
                          'confirm'.tr(context),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: 3.w),
                child: Icon(
                  Icons.edit_calendar_rounded,
                  color: const Color(0xFF1C1C1E),
                  size: 20.sp,
                ),
              ),
            ),
            GestureDetector(
              onTap: () async {
                NutritionSettingsSheet.show(context, Navigator.of(context));
              },
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: 3.w),
                child: Icon(
                  Icons.settings_rounded,
                  color: const Color(0xFF1C1C1E),
                  size: 20.sp,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NutritionHistoryScreen(),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: 3.w),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: const Color(0xFF1C1C1E),
                  size: 20.sp,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                final String shareText =
                    "${'share_progress_msg1'.tr(context)}$consumedKcal${'share_progress_msg2'.tr(context)}$targetKcal${'share_progress_msg3'.tr(context)}";
                Share.share(shareText);
              },
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: 4.w),
                child: Icon(
                  Icons.share_rounded,
                  color: const Color(0xFF1C1C1E),
                  size: 20.sp,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Dynamic Macro Strip
                  _buildMacroStrip(
                    consumedKcal,
                    targetKcal,
                    consumedP,
                    targetP,
                    consumedC,
                    targetC,
                    consumedF,
                    targetF,
                    consumedFi,
                    targetFi,
                    targetWater,
                    progress,
                  ),

                  // Meals List
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                        bottom: 16.h,
                      ), // padding to scroll past the floating button
                      itemCount: widget.template.meals.length,
                      itemBuilder: (context, index) {
                        return _buildMealCard(
                          widget.template.meals[index],
                          index, context);
                      },
                    ),
                  ),
                ],
              ),
              PositionedDirectional(
                bottom: 8.h,
                start: 4.w,
                end: 4.w,
                child: GestureDetector(
                  onTap: () => _finishDay(
                    consumedKcal,
                    targetKcal,
                    consumedP,
                    consumedC,
                    consumedF,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(4.w),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'finish_day'.tr(context),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroStrip(
    int cKcal,
    int tKcal,
    int cP,
    int tP,
    int cC,
    int tC,
    int cF,
    int tF,
    int cFi,
    int tFi,
    double targetWater,
    double progress,
  ) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Row(
        children: [
          // Circular Progress
          SizedBox(
            width: 24.w,
            height: 24.w,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 2.w,
                  color: const Color(0xFFF0F0F5),
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.w,
                  backgroundColor: Colors.transparent,
                  color: const Color(0xFFFF3B30),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$cKcal',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1E),
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'kcal_upper'.tr(context),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 4.w),

          // Macros
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: _buildStripMacro(
                        cP,
                        tP,
                        'protein_upper'.tr(context),
                        const Color(0xFF007AFF),
                      ),
                    ),
                    Flexible(
                      child: _buildStripMacro(
                        cC,
                        tC,
                        'carbs_upper'.tr(context),
                        const Color(0xFFFF9500),
                      ),
                    ),
                    Flexible(
                      child: _buildStripMacro(
                        cF,
                        tF,
                        'fat_upper'.tr(context),
                        const Color(0xFFFF3B30),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1.5.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: _buildStripMacro(
                        cFi,
                        tFi,
                        'fiber_upper'.tr(context),
                        const Color(0xFF8B572A),
                      ),
                    ),
                    Flexible(
                      child: _buildStripWater(targetWater, 'water_target_upper'.tr(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStripMacro(int consumed, int target, String label, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$consumed',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                '/${target}g',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 0.3.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8E8E93),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStripWater(double target, String label) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${target.toStringAsFixed(1)} L',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF5AC8FA),
            ),
          ),
        ),
        SizedBox(height: 0.3.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8E8E93),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(DietTemplateMeal meal, int mealIndex, BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  alignment: Alignment.center,
                  child: Text('🍽️', style: TextStyle(fontSize: 22.sp)),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.mealName,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(height: 0.3.h),
                      Text(
                        "${'p_label'.tr(context)}: ${meal.macros.protein}g • ${'c_label'.tr(context)}: ${meal.macros.carbs}g • ${'f_label'.tr(context)}: ${meal.macros.fat}g",
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: const Color(0xFF8E8E93),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _pickTime(meal.mealName, mealIndex, context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.5.w,
                      vertical: 0.7.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEFF),
                      borderRadius: BorderRadius.circular(2.5.w),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.alarm_rounded,
                          size: 17.sp,
                          color: const Color(0xFF5B3FBF),
                        ),
                        if (_mealTimes.containsKey(meal.mealName)) ...[
                          SizedBox(width: 1.5.w),
                          Text(
                            _mealTimes[meal.mealName]!.format(context),
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: const Color(0xFF5B3FBF),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Text(
                  '${meal.calories} kcal',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFF5F5F7), height: 1, thickness: 1),

          // Food Items
          ...List.generate(meal.items.length, (itemIndex) {
            final item = meal.items[itemIndex];
            final isChecked = _checkedItems.contains(
              '${mealIndex}_$itemIndex',
            );

            return GestureDetector(
              onTap: () => _toggleFood(mealIndex, itemIndex),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  border: itemIndex < meal.items.length - 1
                      ? const Border(
                          bottom: BorderSide(
                            color: Color(0xFFF8F8F8),
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Text('🥘', style: TextStyle(fontSize: 22.sp)),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          SizedBox(height: 0.3.h),
                          Text(
                            item.amount,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF8E8E93),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.calories} kcal',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    SizedBox(width: 3.w),

                    // Checkbox Circle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 7.5.w,
                      height: 7.5.w,
                      decoration: BoxDecoration(
                        color: isChecked
                            ? const Color(0xFFE8FFF0)
                            : const Color(0xFFF5F5F7),
                        border: Border.all(
                          color: isChecked
                              ? Colors.transparent
                              : const Color(0xFFE5E5EA),
                        ),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      alignment: Alignment.center,
                      child: isChecked
                          ? Icon(
                              Icons.check_rounded,
                              color: const Color(0xFF1A7A30),
                              size: 5.w,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
