import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../profile/providers/body_metrics_provider.dart';
import '../domain/models/ai_coach_plan.dart';
import '../services/ai_coach_service.dart';

final aiCoachPlanProvider = AsyncNotifierProvider<AiCoachPlanNotifier, AICoachPlan?>(() {
  return AiCoachPlanNotifier();
});

class AiCoachPlanNotifier extends AsyncNotifier<AICoachPlan?> {
  @override
  Future<AICoachPlan?> build() async {
    return _loadOrGeneratePlan();
  }

  Future<AICoachPlan?> _loadOrGeneratePlan() async {
    // 1. Check local cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final cachedStr = prefs.getString('ai_coach_plan_$dateStr');
      if (cachedStr != null) {
        return AICoachPlan.fromJson(jsonDecode(cachedStr));
      }
    } catch (_) {}

    // 2. Generate new plan
    return _generatePlan();
  }

  Future<AICoachPlan?> _generatePlan() async {
    final player = await ref.read(currentUserModelProvider.future);
    final metrics = await ref.read(bodyMetricsProvider.future);
    
    if (player == null) {
      throw Exception('User profile not loaded.');
    }

    final service = ref.read(aiCoachServiceProvider);
    
    final userData = {
      'weight': metrics.weight > 0 ? metrics.weight : player.weight,
      'height': metrics.height > 0 ? metrics.height : player.height,
      'bodyFat': metrics.bodyFat > 0 ? metrics.bodyFat : player.bodyFat,
      'muscleMass': metrics.muscleMass,
      'fatFreeMass': metrics.fatFreeMass,
      'bodyWater': metrics.water,
      'bmr': metrics.bmr,
      'metabolicAge': metrics.metabolicAge,
      'age': metrics.age,
      'gender': metrics.gender.isNotEmpty ? metrics.gender : player.gender,
      'goal': player.goal,
      'fitnessLevel': player.fitnessLevel,
      'trainingMode': player.trainingMode,
    };

    final plan = await service.generateNutritionPlan(userData);
    
    if (plan != null) {
      await _saveToCache(plan);
    }
    return plan;
  }

  Future<void> refreshPlan() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final newPlan = await _generatePlan();
      return newPlan;
    });
  }

  Future<void> updateMealTime(int mealIndex, String newTime) async {
    if (state.value == null) return;
    final currentPlan = state.value!;
    
    // Create a new copy of the meals list with the updated time
    final updatedMeals = List<AIPlanMeal>.from(currentPlan.meals);
    final oldMeal = updatedMeals[mealIndex];
    updatedMeals[mealIndex] = AIPlanMeal(
      icon: oldMeal.icon,
      name: oldMeal.name,
      time: newTime,
      totalCalories: oldMeal.totalCalories,
      protein: oldMeal.protein,
      carbs: oldMeal.carbs,
      fat: oldMeal.fat,
      foods: oldMeal.foods,
    );

    // Create a new copy of the plan
    final updatedPlan = AICoachPlan(
      summary: currentPlan.summary,
      totalCalories: currentPlan.totalCalories,
      caloriesBurned: currentPlan.caloriesBurned,
      calorieDeficit: currentPlan.calorieDeficit,
      waterLiters: currentPlan.waterLiters,
      workoutFocus: currentPlan.workoutFocus,
      protein: currentPlan.protein,
      carbs: currentPlan.carbs,
      fat: currentPlan.fat,
      meals: updatedMeals,
    );

    // Update state
    state = AsyncValue.data(updatedPlan);

    // Save to cache
    await _saveToCache(updatedPlan);
  }

  Future<void> toggleMealEaten(int mealIndex) async {
    if (state.value == null) return;
    final currentPlan = state.value!;
    
    // Toggle the specific meal
    final updatedMeals = List<AIPlanMeal>.from(currentPlan.meals);
    final oldMeal = updatedMeals[mealIndex];
    updatedMeals[mealIndex] = AIPlanMeal(
      icon: oldMeal.icon,
      name: oldMeal.name,
      time: oldMeal.time,
      totalCalories: oldMeal.totalCalories,
      protein: oldMeal.protein,
      carbs: oldMeal.carbs,
      fat: oldMeal.fat,
      foods: oldMeal.foods,
      isEaten: !oldMeal.isEaten,
    );

    // Recalculate current macros and calories based on all eaten meals
    int currentProtein = 0;
    int currentCarbs = 0;
    int currentFat = 0;
    int currentCalories = 0; // if we want to track current calories, but for now we track macros

    for (final m in updatedMeals) {
      if (m.isEaten) {
        currentProtein += m.protein;
        currentCarbs += m.carbs;
        currentFat += m.fat;
        currentCalories += m.totalCalories; // We'll just leave this here in case
      }
    }

    final updatedPlan = AICoachPlan(
      summary: currentPlan.summary,
      totalCalories: currentPlan.totalCalories,
      caloriesBurned: currentPlan.caloriesBurned,
      calorieDeficit: currentPlan.calorieDeficit,
      waterLiters: currentPlan.waterLiters,
      workoutFocus: currentPlan.workoutFocus,
      protein: AIMacroTarget(target: currentPlan.protein.target, current: currentProtein),
      carbs: AIMacroTarget(target: currentPlan.carbs.target, current: currentCarbs),
      fat: AIMacroTarget(target: currentPlan.fat.target, current: currentFat),
      meals: updatedMeals,
    );

    state = AsyncValue.data(updatedPlan);
    await _saveToCache(updatedPlan);
  }

  Future<void> syncProgressToCloud() async {
    final player = await ref.read(currentUserModelProvider.future);
    if (player == null || state.value == null) return;
    
    final plan = state.value!;
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(player.uid)
          .collection('daily_nutrition')
          .doc(dateStr)
          .set({
        'date': dateStr,
        'proteinTarget': plan.protein.target,
        'proteinCurrent': plan.protein.current,
        'carbsTarget': plan.carbs.target,
        'carbsCurrent': plan.carbs.current,
        'fatTarget': plan.fat.target,
        'fatCurrent': plan.fat.current,
        'totalCaloriesTarget': plan.totalCalories,
        'workoutFocus': plan.workoutFocus,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _saveToCache(AICoachPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      final jsonPlan = {
        'summary': plan.summary,
        'totalCalories': plan.totalCalories,
        'caloriesBurned': plan.caloriesBurned,
        'calorieDeficit': plan.calorieDeficit,
        'waterLiters': plan.waterLiters,
        'workoutFocus': plan.workoutFocus,
        'macros': {
          'protein': {'target': plan.protein.target, 'current': plan.protein.current},
          'carbs': {'target': plan.carbs.target, 'current': plan.carbs.current},
          'fat': {'target': plan.fat.target, 'current': plan.fat.current},
        },
        'meals': plan.meals.map((m) => m.toJson()).toList(),
      };
      await prefs.setString('ai_coach_plan_$dateStr', jsonEncode(jsonPlan));
    } catch (_) {}
  }
}