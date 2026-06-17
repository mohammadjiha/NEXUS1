import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../smart_workout/providers/exercise_history_provider.dart';
import '../../smart_workout/providers/workout_history_provider.dart';

class AchievementBadge {
  final String emoji;
  final String title;
  final int bgColor;
  final bool locked;

  AchievementBadge({
    required this.emoji,
    required this.title,
    required this.bgColor,
    required this.locked,
  });
}

final achievementsProvider = Provider<List<AchievementBadge>>((ref) {
  final history = ref.watch(workoutHistoryProvider);
  final exerciseHist = ref.watch(exerciseHistoryProvider).value ?? {};

  final int workouts = history.length;
  
  // Calculate streak (consecutive days)
  int streak = 0;
  if (history.isNotEmpty) {
    streak = 1;
    final now = DateTime.now();
    DateTime lastDate = DateTime.parse(history.first.timestampIso ?? now.toIso8601String());
    if (now.difference(lastDate).inDays <= 1) { // active streak
       for (int i = 1; i < history.length; i++) {
         final date = DateTime.parse(history[i].timestampIso ?? now.toIso8601String());
         if (lastDate.difference(date).inDays == 1) {
           streak++;
           lastDate = date;
         } else if (lastDate.difference(date).inDays == 0) {
           continue; // same day workout
         } else {
           break;
         }
       }
    } else {
      streak = 0; // Lost streak
    }
  }

  int totalSets = 0;
  for (final h in history) {
    totalSets += h.completedSets;
  }

  return [
    AchievementBadge(
      emoji: '🔥',
      title: '12-Day Streak',
      bgColor: 0xFFFFF0E8,
      locked: streak < 12,
    ),
    AchievementBadge(
      emoji: '💪',
      title: '100 Sets Done',
      bgColor: 0xFFE8F5FF,
      locked: totalSets < 100,
    ),
    AchievementBadge(
      emoji: '🏆',
      title: 'First PR',
      bgColor: 0xFFFFF8E8,
      locked: exerciseHist.isEmpty,
    ),
    AchievementBadge(
      emoji: '⚡',
      title: '30 Workouts',
      bgColor: 0xFFF0EEFF,
      locked: workouts < 30,
    ),
    AchievementBadge(
      emoji: '🎯',
      title: '50 Workouts',
      bgColor: 0xFFF5F5F7,
      locked: workouts < 50,
    ),
    AchievementBadge(
      emoji: '🌙',
      title: '30-Day Streak',
      bgColor: 0xFFF5F5F7,
      locked: streak < 30,
    ),
  ];
});
