import 'dart:math';

import '../models/routine_model.dart';
import '../providers/split_setup_provider.dart';

class PlanGenerator {
  static List<WorkoutDay> generatePlan({
    required int daysPerWeek,
    required String splitType,
    required List<String> trainingDays,
    required Map<String, List<RoutineModel>> catalog,
    required DateTime startDate,
    Map<String, String> swaps = const {},
  }) {
    List<WorkoutDay> plan = [];
    final random = Random();

    // Map the split type to an ordered list of categories to assign
    List<List<String>> assignedCategoriesPerDay = _getCategoryMapping(daysPerWeek, splitType);

    // If the split requires more days than selected, trim it. If less, loop it.
    while (assignedCategoriesPerDay.length < trainingDays.length) {
      assignedCategoriesPerDay.addAll(_getCategoryMapping(daysPerWeek, splitType));
    }
    assignedCategoriesPerDay = assignedCategoriesPerDay.take(trainingDays.length).toList();

    // Sort training days into actual order (e.g., MON, TUE, WED) starting from today
    final orderedWeekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    
    int dayCount = 0;
    Map<String, int> categoryUsage = {};
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final dayName = _getWeekdayName(date.weekday);
      
      if (trainingDays.contains(dayName) && dayCount < assignedCategoriesPerDay.length) {
        final dayCategories = assignedCategoriesPerDay[dayCount];
        final title = _getTitleForCategories(dayCategories);
        
        // Find a routine that matches the PRIMARY category
        final primaryCategory = dayCategories.first;
        final availableRoutines = catalog[primaryCategory] ?? [];
        
        String? assignedId;
        String? assignedName;
        if (availableRoutines.isNotEmpty) {
          int usage = categoryUsage[primaryCategory] ?? 0;
          
          final deterministicRandom = Random(splitType.hashCode + primaryCategory.hashCode);
          List<RoutineModel> shuffledRoutines = List.from(availableRoutines);
          shuffledRoutines.shuffle(deterministicRandom);
          
          final selectedRoutine = shuffledRoutines[usage % shuffledRoutines.length];
          assignedId = selectedRoutine.id;
          assignedName = selectedRoutine.routineName;
          
          categoryUsage[primaryCategory] = usage + 1;
        }

        plan.add(WorkoutDay(
          dayName: dayName,
          date: date.day.toString(),
          fullDate: date.toIso8601String().split('T')[0],
          title: title,
          categories: dayCategories,
          assignedRoutineId: assignedId,
          assignedRoutineName: assignedName,
        ));
        dayCount++;
      } else {
        plan.add(WorkoutDay(
          dayName: dayName,
          date: date.day.toString(),
          fullDate: date.toIso8601String().split('T')[0],
          title: 'Rest Day',
          categories: [],
          isRest: true,
        ));
      }
    }

    // Post-process swaps
    if (swaps.isNotEmpty) {
      final List<WorkoutDay> swappedPlan = List.from(plan);
      for (int i = 0; i < swappedPlan.length; i++) {
        final dateKey = startDate.add(Duration(days: i)).toIso8601String().split('T')[0];
        if (swaps.containsKey(dateKey)) {
          final targetDateKey = swaps[dateKey]!;
          // Find the index of targetDateKey
          int targetIndex = -1;
          for (int j = 0; j < plan.length; j++) {
            if (startDate.add(Duration(days: j)).toIso8601String().split('T')[0] == targetDateKey) {
              targetIndex = j;
              break;
            }
          }
          if (targetIndex != -1 && targetIndex > i) { // only swap forward to avoid double swapping
            final temp = swappedPlan[i];
            swappedPlan[i] = WorkoutDay(
              dayName: temp.dayName,
              date: temp.date,
              fullDate: temp.fullDate,
              title: swappedPlan[targetIndex].title,
              categories: swappedPlan[targetIndex].categories,
              assignedRoutineId: swappedPlan[targetIndex].assignedRoutineId,
              assignedRoutineName: swappedPlan[targetIndex].assignedRoutineName,
              isRest: swappedPlan[targetIndex].isRest,
            );
            final targetTemp = swappedPlan[targetIndex];
            swappedPlan[targetIndex] = WorkoutDay(
              dayName: targetTemp.dayName,
              date: targetTemp.date,
              fullDate: targetTemp.fullDate,
              title: temp.title,
              categories: temp.categories,
              assignedRoutineId: temp.assignedRoutineId,
              assignedRoutineName: temp.assignedRoutineName,
              isRest: temp.isRest,
            );
          }
        }
      }
      return swappedPlan;
    }

    return plan;
  }

  static String _getWeekdayName(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday - 1];
  }

  static String _getTitleForCategories(List<String> categories) {
    if (categories.contains('Chest') && categories.contains('Triceps')) return 'Push Day';
    if (categories.contains('Back') && categories.contains('Biceps')) return 'Pull Day';
    if (categories.contains('Legs')) return 'Leg Day';
    if (categories.contains('Chest') || categories.contains('Back')) return 'Upper Body';
    return '${categories.first} Day';
  }

  static List<List<String>> _getCategoryMapping(int days, String splitType) {
    if (splitType == 'ai_decide') {
      if (days <= 3) {
        splitType = 'fb';
      } else if (days == 4) splitType = 'ul';
      else if (days == 5) splitType = 'bro_split';
      else splitType = 'ppl';
    }

    if (splitType == 'ppl') {
      return [
        ['Chest', 'Shoulders', 'Triceps'],
        ['Back', 'Biceps'],
        ['Legs', 'Glutes'],
      ];
    } else if (splitType == 'upper_lower' || splitType == 'ul') {
      return [
        ['Chest', 'Back'],
        ['Legs', 'Glutes'],
      ];
    } else if (splitType == 'full_body' || splitType == 'fb') {
      return [
        ['Chest', 'Back', 'Legs'],
        ['Chest', 'Back', 'Legs'],
        ['Chest', 'Back', 'Legs'],
      ];
    } else if (splitType == 'bro_split') {
      return [
        ['Chest'],
        ['Back'],
        ['Shoulders'],
        ['Legs'],
        ['Biceps', 'Triceps'],
      ];
    }
    // Default fallback
    return [['Chest'], ['Back'], ['Legs']];
  }
}
