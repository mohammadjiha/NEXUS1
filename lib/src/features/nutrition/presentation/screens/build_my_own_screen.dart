import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../profile/providers/body_metrics_provider.dart';
import '../../domain/models/diet_template_model.dart';
import '../../domain/models/food_model.dart';
import '../../services/alarm_service.dart';
import '../widgets/nutrition_settings_sheet.dart';
import 'ai_food_scanner_screen.dart';
import 'daily_meal_plan_screen.dart';

class BuildMyOwnScreen extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool autoLoad;
  final int initialStep;
  const BuildMyOwnScreen({
    super.key,
    required this.navigatorKey,
    this.autoLoad = false,
    this.initialStep = 1,
  });

  @override
  ConsumerState<BuildMyOwnScreen> createState() => _BuildMyOwnScreenState();
}

class _BuildMyOwnScreenState extends ConsumerState<BuildMyOwnScreen> {
  late int _currentStep;
  late final PageController _pageController;

  Timer? _warningTimer;
  bool _showWarnings = false;

  // Step 1
  String _selectedGoal = 'fat';

  // Step 2
  int _targetKcal = 2100;
  int _targetProtein = 170;
  int _targetCarbs = 200;
  int _targetFat = 55;
  int _targetFiber = 30;
  double _targetWaterLiters = 3.0;

  // Step 3
  String? _pickerTarget;
  Map<String, List<FoodModel>> _meals = {
    'Breakfast': [],
    'Lunch': [],
    'Dinner': [],
  };
  Map<String, TimeOfDay> _mealTimes = {
    'Breakfast': const TimeOfDay(hour: 7, minute: 0),
    'Lunch': const TimeOfDay(hour: 12, minute: 30),
    'Dinner': const TimeOfDay(hour: 20, minute: 0),
  };

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _pageController = PageController(initialPage: widget.initialStep - 1);
    _loadSavedPlan();
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('custom_meal_plan');
    if (savedData != null) {
      try {
        final decoded = jsonDecode(savedData) as Map<String, dynamic>;

        final Map<String, List<FoodModel>> loadedMeals = {};
        if (decoded['meals'] != null) {
          (decoded['meals'] as Map<String, dynamic>).forEach((key, val) {
            loadedMeals[key] = (val as List)
                .map((e) => FoodModel.fromJson(e))
                .toList();
          });
        }

        final Map<String, TimeOfDay> loadedTimes = {};
        if (decoded['times'] != null) {
          (decoded['times'] as Map<String, dynamic>).forEach((key, val) {
            final parts = val.toString().split(':');
            loadedTimes[key] = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          });
        }

        setState(() {
          _meals = loadedMeals;
          if (loadedTimes.isNotEmpty) _mealTimes = loadedTimes;

          if (decoded['targetKcal'] != null) {
            _targetKcal = (decoded['targetKcal'] as num).toInt();
          }
          if (decoded['targetProtein'] != null) {
            _targetProtein = (decoded['targetProtein'] as num).toInt();
          }
          if (decoded['targetCarbs'] != null) {
            _targetCarbs = (decoded['targetCarbs'] as num).toInt();
          }
          if (decoded['targetFat'] != null) _targetFat = (decoded['targetFat'] as num).toInt();
          if (decoded['targetFiber'] != null) {
            _targetFiber = (decoded['targetFiber'] as num).toInt();
          }
          if (decoded['targetWaterLiters'] != null) {
            _targetWaterLiters = (decoded['targetWaterLiters'] as num).toDouble();
          }
        });

        if (widget.autoLoad &&
            loadedMeals.values.any((list) => list.isNotEmpty)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _finishAndSave(context);
          });
        }
      } catch (e) {
        debugPrint('Error loading plan: $e');
      }
    }
  }

  Future<void> _savePlanToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final mealsMap = {};
    _meals.forEach((key, val) {
      mealsMap[key] = val.map((e) => e.toJson()).toList();
    });

    final timesMap = {};
    _mealTimes.forEach((key, val) {
      timesMap[key] = '${val.hour}:${val.minute}';
    });

    final dataToSave = {
      'meals': mealsMap,
      'times': timesMap,
      'targetKcal': _targetKcal,
      'targetProtein': _targetProtein,
      'targetCarbs': _targetCarbs,
      'targetFat': _targetFat,
      'targetFiber': _targetFiber,
      'targetWaterLiters': _targetWaterLiters,
    };

    await prefs.setString('custom_meal_plan', jsonEncode(dataToSave));
  }

  void _nextStep(BuildContext context) {
    if (_currentStep == 2 && _getMacroWarnings().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'resolve_warnings_proceed'.tr(context),
            style: TextStyle(fontSize: 14.sp),
          ),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: AppDurations.standard,
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() async {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: AppDurations.standard,
        curve: Curves.easeInOut,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nutrition_last_flow_path');
      if (mounted) Navigator.pop(context);
    }
  }

  // ============== HELPER METHODS ==============

  int _getLoggedKcal() => _meals.values
      .expand((e) => e)
      .fold(0, (sum, item) => sum + item.calories.toInt());
  int _getLoggedProtein() => _meals.values
      .expand((e) => e)
      .fold(0, (sum, item) => sum + item.protein.toInt());
  int _getLoggedCarbs() => _meals.values
      .expand((e) => e)
      .fold(0, (sum, item) => sum + item.carbs.toInt());
  int _getLoggedFat() => _meals.values
      .expand((e) => e)
      .fold(0, (sum, item) => sum + item.fat.toInt());

  void _checkWarningsAndStartTimer() {
    final w = _getMacroWarnings();
    if (w.isNotEmpty) {
      _warningTimer?.cancel();
      setState(() => _showWarnings = true);
      _warningTimer = Timer(AppDurations.warningAutoDismiss, () {
        if (mounted) setState(() => _showWarnings = false);
      });
    } else {
      setState(() => _showWarnings = false);
    }
  }

  void _showFiberInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        title: Text(
          'why_track_fiber'.tr(context),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'fiber_satiety_title'.tr(context),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
              Text(
                'fiber_satiety_desc'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF6E6E73),
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                'fiber_digestion_title'.tr(context),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
              Text(
                'fiber_digestion_desc'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF6E6E73),
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                'fiber_clean_eating_title'.tr(context),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
              Text(
                'fiber_clean_eating_desc'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF6E6E73),
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                'fiber_stable_energy_title'.tr(context),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
              Text(
                'fiber_stable_energy_desc'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF6E6E73),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'got_it'.tr(context),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _recalcTotalKcal() {
    setState(() {
      _targetKcal =
          (_targetProtein * 4) + (_targetCarbs * 4) + (_targetFat * 9);
    });
    _checkWarningsAndStartTimer();
  }

  void _updateMacrosFromKcal(int kcal) {
    setState(() {
      _targetKcal = kcal;

      final metrics = ref.read(bodyMetricsProvider).value;
      double weight = metrics?.weight ?? 0.0;
      double bodyFat = metrics?.bodyFat ?? 0.0;
      double lbm = metrics?.fatFreeMass ?? 0.0;

      // Calculate Lean Body Mass if not provided but we have weight and body fat
      if (lbm <= 0 && weight > 0 && bodyFat > 0) {
        lbm = weight * (1 - (bodyFat / 100));
      }

      // If we still don't have LBM, estimate it based on standard body fat (20%)
      if (lbm <= 0 && weight > 0) {
        lbm = weight * 0.8;
      }

      if (_selectedGoal == 'fat') {
        // High protein to preserve muscle, moderate fat, lower carbs
        if (lbm > 0) {
          _targetProtein = (lbm * 2.5).round(); // 2.5g per kg of LBM
        } else {
          _targetProtein = ((kcal * 0.40) / 4).round();
        }

        if (weight > 0) {
          _targetFat = (weight * 0.8)
              .clamp(35.0, 80.0)
              .round(); // 0.8g per kg of body weight
        } else {
          _targetFat = ((kcal * 0.30) / 9).round();
        }
      } else if (_selectedGoal == 'bulk') {
        // Sufficient protein, moderate fat, high carbs for energy and growth
        if (lbm > 0) {
          _targetProtein = (lbm * 2.2).round(); // 2.2g per kg of LBM
        } else {
          _targetProtein = ((kcal * 0.25) / 4).round();
        }

        if (weight > 0) {
          _targetFat = (weight * 1.0)
              .clamp(40.0, 100.0)
              .round(); // 1g per kg of body weight
        } else {
          _targetFat = ((kcal * 0.25) / 9).round();
        }
      } else {
        // Maintenance or Custom
        if (lbm > 0) {
          _targetProtein = (lbm * 2.2).round();
        } else {
          _targetProtein = ((kcal * 0.30) / 4).round();
        }

        if (weight > 0) {
          _targetFat = (weight * 1.0).clamp(40.0, 90.0).round();
        } else {
          _targetFat = ((kcal * 0.30) / 9).round();
        }
      }

      // Calculate remaining calories for carbs
      int remainingKcal = kcal - (_targetProtein * 4) - (_targetFat * 9);
      if (remainingKcal < 0) {
        // If calories are too low, fallback to percentage-based
        _targetCarbs = 0;
        _scaleMacrosToNewKcal(kcal);
        return;
      }
      _targetCarbs = (remainingKcal / 4).round();
      _targetFiber = ((kcal / 1000) * 14).round();

      if (weight > 0) {
        _targetWaterLiters = double.parse(
          (weight * 0.04).clamp(2.0, 6.0).toStringAsFixed(1),
        );
      } else {
        _targetWaterLiters = 3.0;
      }
    });
  }

  void _scaleMacrosToNewKcal(int newKcal) {
    setState(() {
      int currentKcal =
          (_targetProtein * 4) + (_targetCarbs * 4) + (_targetFat * 9);
      if (currentKcal <= 0) {
        _updateMacrosFromKcal(newKcal);
        return;
      }

      double pPct = (_targetProtein * 4) / currentKcal;
      double cPct = (_targetCarbs * 4) / currentKcal;
      double fPct = (_targetFat * 9) / currentKcal;

      _targetKcal = newKcal;
      _targetProtein = ((newKcal * pPct) / 4).round();
      _targetCarbs = ((newKcal * cPct) / 4).round();
      _targetFat = ((newKcal * fPct) / 9).round();
      _targetFiber = ((newKcal / 1000) * 14).round();
    });
    _checkWarningsAndStartTimer();
  }

  int _getTdee() {
    final metrics = ref.read(bodyMetricsProvider).value;
    double weight = metrics?.weight ?? 0.0;
    double bodyFat = metrics?.bodyFat ?? 0.0;
    double lbm = metrics?.fatFreeMass ?? 0.0;
    double bmr = metrics?.bmr ?? 0.0;

    // 1. If InBody BMR is provided, use it directly!
    if (bmr > 0) return (bmr * 1.45).round();

    // 2. If we have Lean Body Mass (Fat Free Mass), use Katch-McArdle (Most accurate for athletes)
    if (lbm <= 0 && weight > 0 && bodyFat > 0) {
      lbm = weight * (1 - (bodyFat / 100));
    }
    if (lbm > 0) {
      double katchBmr = 370 + (21.6 * lbm);
      return (katchBmr * 1.45).round();
    }

    // 3. Fallback to basic weight multiplier
    if (weight > 0) return (weight * 2.2 * 15).round();

    return 2500;
  }

  List<String> _getMacroWarnings() {
    List<String> warnings = [];
    int totalKcal = _targetKcal;
    if (totalKcal <= 0) return warnings;

    int tdee = _getTdee();
    double pPct = (_targetProtein * 4) / totalKcal;
    double cPct = (_targetCarbs * 4) / totalKcal;
    double fPct = (_targetFat * 9) / totalKcal;

    if (fPct < 0.15) {
      warnings.add('warning_fat_danger_low'.tr(context));
    }
    if (pPct < 0.15) {
      warnings.add('warning_protein_extremely_low'.tr(context));
    }

    if (_selectedGoal == 'fat') {
      if (totalKcal >= tdee) {
        warnings.add('warning_calories_too_high_fat'.tr(context));
      }
      if (cPct > 0.45) warnings.add('warning_carbs_high_fat'.tr(context));
      if (pPct < 0.25) warnings.add('warning_protein_low_fat'.tr(context));
      if (fPct > 0.40) warnings.add('warning_fat_too_high_fat'.tr(context));

      final metrics = ref.read(bodyMetricsProvider).value;
      double weight = metrics?.weight ?? 0.0;
      if (weight > 0 && _targetFat > weight * 1.0) {
        warnings.add(
          "${'warning_fat_excessive_weight'.tr(context)}${(weight * 0.8).toInt()}-${weight.toInt()}g.",
        );
      } else if (weight <= 0 && _targetFat > 80) {
        warnings.add('warning_fat_high_cut'.tr(context));
      }
    } else if (_selectedGoal == 'bulk') {
      if (totalKcal < tdee) {
        warnings.add('warning_calories_too_low_bulk'.tr(context));
      }
      if (pPct > 0.35) {
        warnings.add('warning_protein_excessive_bulk'.tr(context));
      }
      if (cPct < 0.35) warnings.add('warning_carbs_low_bulk'.tr(context));
      if (fPct > 0.35) warnings.add('warning_fat_high_bulk'.tr(context));
    }

    return warnings;
  }

  void _selectGoal(String goal, int kcal) {
    if (_selectedGoal != goal) {
      _meals.forEach((key, _) => _meals[key] = []);
      _savePlanToPrefs();
    }
    setState(() {
      _selectedGoal = goal;
    });
    _updateMacrosFromKcal(kcal);
  }

  Future<void> _pickTime(String mealName) async {
    final initialTime =
        _mealTimes[mealName] ?? const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF1C1C1E)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _mealTimes[mealName] = picked;
      });
      _savePlanToPrefs();
    }
  }

  void _showAddCustomMealDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'add_custom_meal'.tr(context),
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            hintText: 'meal_name_hint'.tr(context),
            hintStyle: TextStyle(fontSize: 14.sp),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'cancel'.tr(context),
              style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 14.sp),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty && !_meals.containsKey(name)) {
                setState(() {
                  _meals[name] = [];
                  _mealTimes[name] = const TimeOfDay(hour: 15, minute: 0);
                });
                _savePlanToPrefs();
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
            ),
            child: Text(
              'add'.tr(context),
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleAllAlarms(BuildContext context) {
    _meals.forEach((mealName, foods) {
      if (foods.isNotEmpty && _mealTimes.containsKey(mealName)) {
        final time = _mealTimes[mealName]!;
        AlarmService().scheduleMealAlarm(
          id: mealName.hashCode.abs(),
          title: "${'time_for_meal'.tr(context)}$mealName!",
          body: "${'dont_forget_track_meal'.tr(context)}${foods.length}",
          time: time,
        );
      }
    });
  }

  void _finishAndSave(BuildContext context) async {
    int curKcal = _getLoggedKcal();
    int diff = (curKcal - _targetKcal).abs();

    if (diff > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('please_add_meals_diff'.tr(context)),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
      return;
    }

    _savePlanToPrefs();
    _scheduleAllAlarms(context);

    List<DietTemplateMeal> finalMeals = [];
    _meals.forEach((name, foods) {
      int cals = foods.fold(0, (s, f) => s + f.calories.toInt());
      int p = foods.fold(0, (s, f) => s + f.protein.toInt());
      int c = foods.fold(0, (s, f) => s + f.carbs.toInt());
      int fA = foods.fold(0, (s, f) => s + f.fat.toInt());
      int fib = foods.fold(0, (s, f) => s + f.fiber.toInt());

      finalMeals.add(
        DietTemplateMeal(
          mealName: name,
          calories: cals,
          macros: Macros(protein: p, carbs: c, fat: fA, fiber: fib),
          items: foods
              .map(
                (f) => DietTemplateItem(
                  name: f.name,
                  amount: f.servingSize,
                  calories: f.calories.toInt(),
                ),
              )
              .toList(),
        ),
      );
    });

    final template = DietTemplateModel(
      id: 'custom_plan',
      bodyType: 'Custom',
      goal: _selectedGoal,
      title: 'my_custom_plan'.tr(context),
      totalCalories: _targetKcal,
      waterLiters: _targetWaterLiters,
      macros: Macros(
        protein: _targetProtein,
        carbs: _targetCarbs,
        fat: _targetFat,
        fiber: _targetFiber,
      ),
      numberOfMeals: _meals.length,
      meals: finalMeals,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'nutrition_active_template_json',
      jsonEncode(template.toJson()),
    );
    await prefs.setString('nutrition_last_flow_path', '/daily_meal_plan');
    if (!prefs.containsKey('nutrition_plan_start_date')) {
      await prefs.setString(
        'nutrition_plan_start_date',
        DateTime.now().toIso8601String(),
      );
    }

    if (mounted) {
      widget.navigatorKey.currentState!.pushReplacement(
        MaterialPageRoute(
          builder: (_) => DailyMealPlanScreen(template: template),
        ),
      );
    }
  }

  String _getMealIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('break')) return '🌅';
    if (lower.contains('lunch')) return '☀️';
    if (lower.contains('din')) return '🌙';
    if (lower.contains('snack')) return '🍎';
    if (lower.contains('pre')) return '⚡';
    if (lower.contains('sleep')) return '😴';
    return '🍽️';
  }

  Color _getMealBg(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('break')) return const Color(0xFFFFF8E8);
    if (lower.contains('lunch')) return const Color(0xFFE8F5FF);
    if (lower.contains('din')) return const Color(0xFFEBF5FF);
    return const Color(0xFFF0EEFF);
  }

  // ============== WIDGETS ==============

  Widget _buildTopBar(
    String title,
    BuildContext context, {
    bool showSkip = false,
    bool isDone = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.initialStep == 3)
            SizedBox(width: 12.w, height: 12.w)
          else
            GestureDetector(
              onTap: _prevStep,
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: 1.w,
                  ), // Adjust to perfectly center the iOS back arrow
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 22.sp,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ),
          Row(
            children: List.generate(3, (index) {
              int stepNum = index + 1;
              bool isActive = stepNum == _currentStep;
              bool isPast = stepNum < _currentStep;
              return AnimatedContainer(
                duration: AppDurations.fast,
                margin: EdgeInsets.symmetric(horizontal: 1.w),
                width: isActive ? 6.w : 2.w,
                height: 2.w,
                decoration: BoxDecoration(
                  color: isPast
                      ? const Color(0xFF34C759)
                      : (isActive
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFE5E5EA)),
                  borderRadius: BorderRadius.circular(2.w),
                ),
              );
            }),
          ),
          if (showSkip)
            GestureDetector(
              onTap: () => _nextStep(context),
              child: Text(
                'skip'.tr(context),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            )
          else if (isDone)
            GestureDetector(
              onTap: () => _nextStep(context),
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.check,
                  size: 24.sp,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                NutritionSettingsSheet.show(
                  context,
                  widget.navigatorKey.currentState!,
                );
              },
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.settings_rounded,
                  size: 22.sp,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(String step, String title, String sub) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF007AFF),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            sub,
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF6E6E73)),
          ),
        ],
      ),
    );
  }

  Widget _buildCta(String text, VoidCallback onTap, {bool isDisabled = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        4.w,
        2.w,
        4.w,
        8.h,
      ), // Lowered slightly based on user feedback
      color: Colors.transparent, // Completely transparent background
      child: ElevatedButton(
        onPressed: isDisabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? const Color(0xFF1C1C1E).withValues(alpha: 0.3)
              : const Color(0xFF1C1C1E),
          disabledBackgroundColor: const Color(
            0xFF1C1C1E,
          ).withValues(alpha: 0.3),
          padding: EdgeInsets.symmetric(
            vertical: 2.1.h,
          ), // Made the button slightly bigger
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(3.w),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 2.w),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18.sp),
          ],
        ),
      ),
    );
  }

  // --- STEP 1 UI ---
  Widget _buildGoalCard(
    String id,
    String icon,
    Color iconBg,
    String title,
    String sub,
    int kcalValue,
    Color kcalColor,
  ) {
    bool isSel = _selectedGoal == id;
    return GestureDetector(
      onTap: () {
        _selectGoal(id, kcalValue);
      },
      child: AnimatedContainer(
        duration: AppDurations.veryFast,
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.all(5.w),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(
            color: isSel ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            width: isSel ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16.w,
              height: 16.w,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(3.w),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: TextStyle(fontSize: 28.sp)),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF6E6E73),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$kcalValue kcal',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: kcalColor,
                  ),
                ),
              ],
            ),
            SizedBox(width: 3.w),
            Container(
              width: 7.w,
              height: 7.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFD1D1D6),
                  width: 2.0,
                ),
                color: isSel ? const Color(0xFF1C1C1E) : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: isSel
                  ? Icon(Icons.circle, size: 3.5.w, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(BuildContext context) {
    final metrics = ref.watch(bodyMetricsProvider).value;
    double weight = metrics?.weight ?? 0.0;
    double bmr = metrics?.bmr ?? 0.0;

    int tdee = 2500;
    if (bmr > 0) {
      tdee = (bmr * 1.45).round();
    } else if (weight > 0) {
      tdee = (weight * 2.2 * 15).round();
    }

    return Stack(
      children: [
        Column(
          children: [
            _buildTopBar('set_goal'.tr(context), context),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: 24.h,
                ), // Padding so you can scroll past the CTA
                children: [
                  _buildStepHeader(
                    'step_1_build_my_own'.tr(context),
                    'whats_your_main_goal'.tr(context),
                    'calc_calorie_targets'.tr(context),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Column(
                      children: [
                        _buildGoalCard(
                          'bulk',
                          '🏗️',
                          const Color(0xFFFFF8E8),
                          'lean_bulk'.tr(context),
                          'build_muscle_minimal_fat'.tr(context),
                          tdee + 300,
                          const Color(0xFFFF9500),
                        ),
                        _buildGoalCard(
                          'fat',
                          '🔥',
                          const Color(0xFFFFF0F0),
                          'fat_loss'.tr(context),
                          'aggressive_cut'.tr(context),
                          tdee - 500,
                          const Color(0xFFFF3B30),
                        ),
                        _buildGoalCard(
                          'maint',
                          '⚖️',
                          const Color(0xFFE8FFF0),
                          'maintenance_goal'.tr(context),
                          'keep_current_weight'.tr(context),
                          tdee,
                          const Color(0xFF1A7A30),
                        ),
                        _buildGoalCard(
                          'custom',
                          '✏️',
                          const Color(0xFFF0EEFF),
                          'custom_goal'.tr(context),
                          'set_own_targets'.tr(context),
                          tdee,
                          const Color(0xFF5B3FBF),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: _buildCta(
            'continue_button'.tr(context),
            () => _nextStep(context),
          ),
        ),
      ],
    );
  }

  // --- STEP 2 UI ---
  Widget _buildMacroSlider(
    String title,
    String goalTxt,
    int value,
    int max,
    Color color,
    Function(double) onChanged, {
    VoidCallback? onInfoTap,
  }) {
    double safeMax = max.toDouble();
    if (value.toDouble() > safeMax) safeMax = value.toDouble();

    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF3A3A3C),
                        ),
                      ),
                      if (onInfoTap != null)
                        GestureDetector(
                          onTap: onInfoTap,
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(start: 2.w),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 18.sp,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    goalTxt,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${value}g',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(
            height: 5.h,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: const Color(0xFFF0F0F5),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 1.h,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value.toDouble(),
                max: safeMax,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterSlider(
    String title,
    String goalTxt,
    double value,
    double max,
    Color color,
    Function(double) onChanged,
  ) {
    double safeMax = max;
    if (value > safeMax) safeMax = value;

    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3A3A3C),
                    ),
                  ),
                  Text(
                    goalTxt,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${value.toStringAsFixed(1)}L',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(
            height: 5.h,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: const Color(0xFFF0F0F5),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 1.h,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value,
                min: 1.0,
                max: safeMax,
                divisions: ((safeMax - 1.0) * 10).toInt(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(BuildContext context) {
    return Column(
      children: [
        _buildTopBar('set_macros'.tr(context), context, showSkip: true),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(bottom: 24.h),
            children: [
              _buildStepHeader(
                'step_2_macro_targets'.tr(context),
                'set_daily_macros'.tr(context),
                'drag_sliders_adjust'.tr(context),
              ),

              // Kcal Big (Shrunk)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(4.w),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'daily_calories_upper'.tr(context),
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          '$_targetKcal',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_targetKcal > 500) {
                              _scaleMacrosToNewKcal(_targetKcal - 50);
                            }
                          },
                          child: Container(
                            width: 8.w,
                            height: 8.w,
                            margin: EdgeInsets.only(bottom: 0.5.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _scaleMacrosToNewKcal(_targetKcal + 50),
                          child: Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Column(
                  children: [
                    _buildMacroSlider(
                      'protein_slider'.tr(context),
                      'muscle_recovery'.tr(context),
                      _targetProtein,
                      300,
                      const Color(0xFF007AFF),
                      (v) {
                        setState(() {
                          _targetProtein = v.toInt();
                        });
                        _recalcTotalKcal();
                      },
                    ),
                    _buildMacroSlider(
                      'carbs_slider'.tr(context),
                      'primary_energy_fuel'.tr(context),
                      _targetCarbs,
                      400,
                      const Color(0xFFFF9500),
                      (v) {
                        setState(() {
                          _targetCarbs = v.toInt();
                        });
                        _recalcTotalKcal();
                      },
                    ),
                    _buildMacroSlider(
                      'fat_slider'.tr(context),
                      'hormones_brain_health'.tr(context),
                      _targetFat,
                      150,
                      const Color(0xFFFF3B30),
                      (v) {
                        setState(() {
                          _targetFat = v.toInt();
                        });
                        _recalcTotalKcal();
                      },
                    ),

                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(
                          'micro_hydration'.tr(context),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF3A3A3C),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),

                    _buildMacroSlider(
                      'fiber_slider'.tr(context),
                      'digestion_satiety'.tr(context),
                      _targetFiber,
                      60,
                      const Color(0xFF8B572A),
                      (v) {
                        setState(() {
                          _targetFiber = v.toInt();
                        });
                      },
                      onInfoTap: () => _showFiberInfoDialog(context),
                    ),
                    _buildWaterSlider(
                      'water_slider'.tr(context),
                      'daily_hydration_target'.tr(context),
                      _targetWaterLiters,
                      6.0,
                      const Color(0xFF5AC8FA),
                      (v) {
                        setState(() {
                          _targetWaterLiters = v;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildCta('continue_build_meals'.tr(context), () => _nextStep(context)),
      ],
    );
  }

  Widget _buildWarningCard(String text) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(2.w),
        border: Border.all(
          color: const Color(0xFFFFCC00).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF8A6D00),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 3 UI ---
  Widget _buildSummaryStrip(BuildContext context) {
    int curKcal = _getLoggedKcal();
    int rem = _targetKcal - curKcal;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'logged_today_upper'.tr(context),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$curKcal',
                            style: TextStyle(
                              fontSize: 34.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            ' / $_targetKcal kcal',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 2.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: rem >= 0
                      ? const Color(0xFF34C759).withValues(alpha: 0.15)
                      : const Color(0xFFFF3B30).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text(
                  rem >= 0
                      ? "$rem${'remaining_text'.tr(context)}"
                      : "${rem.abs()}${'over_text'.tr(context)}",
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: rem >= 0
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Expanded(
                child: _buildMiniBar(
                  'P: ${_getLoggedProtein()}g',
                  _getLoggedProtein() /
                      (_targetProtein == 0 ? 1 : _targetProtein),
                  const Color(0xFF007AFF),
                ),
              ),
              SizedBox(width: 1.w),
              Expanded(
                child: _buildMiniBar(
                  'C: ${_getLoggedCarbs()}g',
                  _getLoggedCarbs() / (_targetCarbs == 0 ? 1 : _targetCarbs),
                  const Color(0xFFFF9500),
                ),
              ),
              SizedBox(width: 1.w),
              Expanded(
                child: _buildMiniBar(
                  'F: ${_getLoggedFat()}g',
                  _getLoggedFat() / (_targetFat == 0 ? 1 : _targetFat),
                  const Color(0xFFFF3B30),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBar(String label, double pct, Color color) {
    if (pct > 1.0) pct = 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 0.5.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(1.w),
          ),
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1.w),
              ),
            ),
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(String mealName, BuildContext context) {
    final foods = _meals[mealName]!;
    final time = _mealTimes[mealName];
    String timeStr = time != null ? time.format(context) : 'Set Time';
    int mKcal = foods.fold(0, (sum, f) => sum + f.calories.toInt());
    int mP = foods.fold(0, (sum, f) => sum + f.protein.toInt());
    int mC = foods.fold(0, (sum, f) => sum + f.carbs.toInt());
    int mF = foods.fold(0, (sum, f) => sum + f.fat.toInt());

    return Container(
      margin: EdgeInsetsDirectional.only(bottom: 1.h, start: 4.w, end: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(3.w),
            child: Row(
              children: [
                Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    color: _getMealBg(mealName),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getMealIcon(mealName),
                    style: TextStyle(fontSize: 16.sp),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      if (foods.isEmpty)
                        Text(
                          'empty_tap_add'.tr(context),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF8E8E93),
                          ),
                        )
                      else
                        Text(
                          '$mKcal kcal · P:${mP}g · C:${mC}g · F:${mF}g',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          if (foods.isNotEmpty)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF5F5F7))),
              ),
              child: Column(
                children: foods.asMap().entries.map((entry) {
                  int idx = entry.key;
                  FoodModel f = entry.value;
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 1.h,
                    ),
                    child: Row(
                      children: [
                        Text(f.emoji, style: TextStyle(fontSize: 18.sp)),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.name,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              Text(
                                '${f.servingSize} · P:${f.protein.toInt()}g · C:${f.carbs.toInt()}g · F:${f.fat.toInt()}g',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${f.calories.toInt()}',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _meals[mealName]!.removeAt(idx);
                            });
                            _savePlanToPrefs();
                          },
                          child: Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F0),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.close,
                              color: const Color(0xFFFF3B30),
                              size: 16.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          GestureDetector(
            onTap: () => setState(() => _pickerTarget = mealName),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF8F8F8))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: const Color(0xFF007AFF), size: 16.sp),
                  SizedBox(width: 2.w),
                  Text(
                    'add_food'.tr(context),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF007AFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickTime(mealName),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFF5F5F7)),
                        right: BorderSide(color: Color(0xFFF5F5F7)),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'edit_time'.tr(context),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _meals.remove(mealName);
                      _mealTimes.remove(mealName);
                    });
                    _savePlanToPrefs();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF5F5F7))),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'remove_meal'.tr(context),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildTopBar('build_meals'.tr(context), context, isDone: true),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: 2.h),
                children: [
                  _buildSummaryStrip(context),
                  _buildStepHeader(
                    'step_3_build_meals'.tr(context),
                    'add_your_meals'.tr(context),
                    'tap_plus_add_food'.tr(context),
                  ),
                  ..._meals.keys.map((name) => _buildMealCard(name, context)),
                  GestureDetector(
                    onTap: () => _showAddCustomMealDialog(context),
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3.5.w),
                        border: Border.all(
                          color: const Color(0xFFD1D1D6),
                          style: BorderStyle.none,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            color: const Color(0xFF007AFF),
                            size: 18.sp,
                          ),
                          SizedBox(width: 2.5.w),
                          Text(
                            'add_custom_meal'.tr(context),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildCta(
              'save_my_plan'.tr(context),
              () => _nextStep(context),
              isDisabled: (_getLoggedKcal() - _targetKcal).abs() > 100,
            ),
          ],
        ),
        if (_pickerTarget != null)
          _FoodPickerOverlay(
            targetMeal: _pickerTarget!,
            onClose: () => setState(() => _pickerTarget = null),
            onAdd: (food) {
              setState(() {
                _meals[_pickerTarget!]!.add(food);
              });
              _savePlanToPrefs();
            },
          ),
      ],
    );
  }

  // --- STEP 4 UI ---
  Widget _buildStep4(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF34C759).withValues(alpha: 0.15),
              border: Border.all(
                color: const Color(0xFF34C759).withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF34C759).withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.verified_rounded,
              color: const Color(0xFF34C759),
              size: 45.sp,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'plan_saved'.tr(context),
            style: TextStyle(
              fontSize: 26.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Text(
              'custom_nutrition_ready'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                color: const Color(0xFF6E6E73),
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'daily_kcal_upper'.tr(context),
                    '$_targetKcal',
                    const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _buildStatBox(
                    'protein_upper'.tr(context),
                    '${_targetProtein}g',
                    const Color(0xFF007AFF),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'carbs_upper'.tr(context),
                    '${_targetCarbs}g',
                    const Color(0xFFFF9500),
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _buildStatBox(
                    'fat_upper'.tr(context),
                    '${_targetFat}g',
                    const Color(0xFFFF3B30),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: ElevatedButton(
              onPressed: () => _finishAndSave(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                minimumSize: Size(double.infinity, 6.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.w),
                ),
              ),
              child: Text(
                'start_logging_today'.tr(context),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 1.h),
          TextButton(
            onPressed: _prevStep,
            child: Text(
              'edit_plan'.tr(context),
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String lbl, String val, Color color) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            lbl,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.initialStep != 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStep1(context),
              _buildStep2(context),
              _buildStep3(context),
              _buildStep4(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodPickerOverlay extends StatefulWidget {
  final String targetMeal;
  final VoidCallback onClose;
  final Function(FoodModel) onAdd;

  const _FoodPickerOverlay({
    required this.targetMeal,
    required this.onClose,
    required this.onAdd,
  });

  @override
  State<_FoodPickerOverlay> createState() => _FoodPickerOverlayState();
}

class _FoodPickerOverlayState extends State<_FoodPickerOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<FoodModel> _searchResults = [];
  Timer? _debounce;

  final Set<String> _addedFoodIds = {};

  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchFoods(); // Fetch initial default list
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _fetchFoods(loadMore: true);
      }
    }
  }

  Future<void> _fetchFoods({bool loadMore = false}) async {
    if (_isLoading ||
        (!loadMore && _currentQuery.isEmpty && _searchResults.isNotEmpty)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance.collection('foods');

      if (_currentQuery.isNotEmpty) {
        query = query.where(
          'namePrefixes',
          arrayContains: _currentQuery.toLowerCase(),
        );
      } else {
        query = query.orderBy('gymScore', descending: true);
      }

      query = query.limit(10);

      if (loadMore && _lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        final newFoods = snapshot.docs
            .map(
              (doc) =>
                  FoodModel.fromMap(doc.id, doc.data() as Map<String, dynamic>),
            )
            .toList();

        setState(() {
          if (loadMore) {
            _searchResults.addAll(newFoods);
          } else {
            _searchResults = newFoods;
          }
          _hasMore = snapshot.docs.length == 10;
        });
      } else {
        setState(() {
          _hasMore = false;
          if (!loadMore) _searchResults = [];
        });
      }
    } catch (e) {
      debugPrint(r'Error fetching foods: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(AppDurations.searchDebounce, () {
      final q = query.trim();
      if (_currentQuery != q) {
        setState(() {
          _currentQuery = q;
          _lastDoc = null;
          _hasMore = true;
          _searchResults.clear();
        });
        _fetchFoods();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F7),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.h),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close,
                      size: 18.sp,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    "${'add_to'.tr(context)}${widget.targetMeal}",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AIFoodScannerScreen(),
                      ),
                    );
                    if (result != null && result is FoodModel && mounted) {
                      widget.onAdd(result);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "${result.name}${'added_exclamation'.tr(context)}",
                          ),
                          duration: AppDurations.shortDelay,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      widget
                          .onClose(); // Close the picker after successful scan and add
                    }
                  },
                  child: Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.document_scanner_rounded,
                      size: 16.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Container(
              height: 6.h, // Adjusted search bar height to be slightly larger
              padding: EdgeInsets.symmetric(horizontal: 3.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3.w),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: const Color(0xFF8E8E93),
                    size: 16.sp,
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'search_food'.tr(context),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFFC7C7CC),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Expanded(
            child: _searchResults.isEmpty && !_isLoading
                ? Center(
                    child: Text(
                      _currentQuery.isEmpty
                          ? 'no_foods_available'.tr(context)
                          : "${'no_results_found_for'.tr(context)}$_currentQuery'",
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(bottom: 10.h),
                    itemCount: _searchResults.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _searchResults.length) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF1C1C1E),
                            ),
                          ),
                        );
                      }
                      final food = _searchResults[index];
                      final isAdded = _addedFoodIds.contains(food.id);
                      final displayName = food.localizedName(
                        Localizations.localeOf(context).languageCode,
                      );

                      return GestureDetector(
                        onTap: () {
                          if (!isAdded) {
                            setState(() {
                              _addedFoodIds.add(food.id);
                            });
                            widget.onAdd(food);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "$displayName${'added_exclamation'.tr(context)}",
                                ),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 0.8.h,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3.5.w),
                            border: Border.all(color: const Color(0xFFF8F8F8)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                food.emoji,
                                style: TextStyle(fontSize: 24.sp),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      '${food.servingSize} · P:${food.protein.toInt()}g C:${food.carbs.toInt()}g F:${food.fat.toInt()}g',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${food.calories.toInt()} kcal',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1C1C1E),
                                    ),
                                  ),
                                  SizedBox(height: 1.h),
                                  isAdded
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          color: const Color(0xFF34C759),
                                          size: 18.sp,
                                        )
                                      : Icon(
                                          Icons.add_circle_outline,
                                          color: const Color(0xFF007AFF),
                                          size: 18.sp,
                                        ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
