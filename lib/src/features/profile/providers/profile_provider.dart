import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/data/auth_repository.dart';
import '../../onboarding/controllers/goal_selection_provider.dart';
import '../../smart_workout/providers/exercise_history_provider.dart';
import '../../smart_workout/providers/workout_history_provider.dart';
import '../../user/data/user_repository.dart';
import 'body_metrics_provider.dart';

enum ProfileTab { overview, stats, records }

class ProfileTabNotifier extends Notifier<ProfileTab> {
  @override
  ProfileTab build() => ProfileTab.overview;

  void setTab(ProfileTab tab) {
    state = tab;
  }
}

final profileTabProvider = NotifierProvider<ProfileTabNotifier, ProfileTab>(() {
  return ProfileTabNotifier();
});

// Profile User Data Provider (aggregating Auth, UserRepo, and GoalSelection)
final profileUserProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  final firstName = ref.watch(currentUserFirstNameProvider) ?? 'User';
  final initials = ref.watch(currentUserInitialsProvider);

  String handle = '@user';
  String gym = 'No Gym Assigned';

  if (user != null) {
    handle = '@${user.email?.split('@').first ?? 'user'}';
    final userRepo = ref.read(userRepositoryProvider);
    final userModel = await userRepo.getUser(user.uid);
    if (userModel != null) {
      final fullName = [
        userModel.firstName?.trim(),
        userModel.lastName?.trim(),
      ].where((part) => part != null && part.isNotEmpty).join(' ');
      if (fullName.isNotEmpty && (user.email == null || user.email!.isEmpty)) {
        handle = '@${fullName.replaceAll(' ', '_').toLowerCase()}';
      }
      if (userModel.gymId != null && userModel.gymId!.isNotEmpty) {
        final firestore = ref.read(firestoreProvider);
        try {
          final doc = await firestore
              .collection('gyms')
              .doc(userModel.gymId!)
              .get();
          if (doc.exists) {
            gym = doc.data()?['name'] as String? ?? userModel.gymId!;
          } else {
            gym = userModel.gymId!;
          }
        } catch (e) {
          gym = userModel.gymId!;
        }
      }
    }
  }

  // Tags based on Goal
  final userModel = ref.watch(currentUserModelProvider).asData?.value;
  final metrics = ref.watch(bodyMetricsProvider).value ?? BodyMetrics();
  final goalState = ref.watch(goalSelectionProvider);
  final goalName = metrics.goal.isNotEmpty
      ? metrics.goal
      : goalState.primaryGoal?.name ?? 'General Fitness';
  final levelName = goalState.fitnessLevel?.name ?? 'Beginner';

  final tags = [
    {'name': _capitalize(goalName), 'color': 0xFF7A4D0A, 'bg': 0xFFFFF8E8},
    {'name': _capitalize(levelName), 'color': 0xFF5B3FBF, 'bg': 0xFFF0EEFF},
  ];

  // Stats from History
  final history = ref.watch(workoutHistoryProvider);
  final workoutsCount = history.length;

  // Calculate streak (consecutive days)
  int streak = 0;
  if (history.isNotEmpty) {
    streak = 1;
    final now = DateTime.now();
    DateTime lastDate = DateTime.parse(
      history.first.timestampIso ?? now.toIso8601String(),
    );
    if (now.difference(lastDate).inDays <= 1) {
      // active streak
      for (int i = 1; i < history.length; i++) {
        final date = DateTime.parse(
          history[i].timestampIso ?? now.toIso8601String(),
        );
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

  // Workouts this week
  final now = DateTime.now();
  final offsetFromSaturday = (now.weekday + 1) % 7;
  final weekStart = now.subtract(Duration(days: offsetFromSaturday));
  int thisWeekCount = 0;
  for (final h in history) {
    final d = DateTime.parse(h.timestampIso ?? now.toIso8601String());
    if (d.isAfter(weekStart)) thisWeekCount++;
  }

  final weightDiff = metrics.weight - metrics.initialWeight;
  final progressStr = weightDiff > 0
      ? '+${weightDiff.toStringAsFixed(1)}kg'
      : '${weightDiff.toStringAsFixed(1)}kg';

  return {
    'name': _profileDisplayName(ref, firstName),
    'initials': initials,
    'handle': handle,
    'gym': gym,
    'bio':
        '${_capitalize(goalName)} journey 🔥 ${_capitalize(levelName)} lifter',
    'tags': tags,
    'workouts': workoutsCount.toString(),
    'streak': '$streak🔥',
    'progress': progressStr,
    'photoUrl': userModel?.photoUrl ?? user?.photoURL,
    'thisWeek': '$thisWeekCount🏆',
    'role': userModel?.role ?? 'player',
    'uid': userModel?.uid ?? user?.uid,
    'gymId': userModel?.gymId,
    'assignedCoachUid': userModel?.assignedCoachUid,
    'assignedCoachName': userModel?.assignedCoachName,
  };
});

String _capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

String _profileDisplayName(Ref ref, String fallbackFirstName) {
  final userModel = ref.watch(currentUserModelProvider).asData?.value;
  final fullName = [
    userModel?.firstName?.trim(),
    userModel?.lastName?.trim(),
  ].where((part) => part != null && part.isNotEmpty).join(' ');
  return fullName.isNotEmpty ? fullName : fallbackFirstName;
}

// Body Metrics
final profileMetricsUiProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final metrics = ref.watch(bodyMetricsProvider).value ?? BodyMetrics();

  Map<String, dynamic> calcTrend(double current, double prev) {
    if (prev == 0.0 || current == prev) {
      return {'trend': '—', 'isUp': false, 'isNeutral': true};
    }
    final diff = current - prev;
    final isUp = diff > 0;
    return {
      'trend': '${isUp ? '▲' : '▼'} ${diff.abs().toStringAsFixed(1)}',
      'isUp': isUp,
      'isNeutral': false,
    };
  }

  return [
    {
      'label': 'Weight',
      'val': metrics.weight.toStringAsFixed(1),
      'unit': ' kg',
      ...calcTrend(metrics.weight, metrics.previousWeight),
    },
    {
      'label': 'Height',
      'val': metrics.height.toStringAsFixed(0),
      'unit': ' cm',
      ...calcTrend(metrics.height, metrics.previousHeight),
    },
    {
      'label': 'BMI',
      'val': metrics.bmi.toStringAsFixed(1),
      'unit': '',
      ...calcTrend(metrics.bmi, metrics.previousBmi),
    },
    {
      'label': 'Body Fat',
      'val': metrics.bodyFat.toStringAsFixed(1),
      'unit': '%',
      ...calcTrend(metrics.bodyFat, metrics.previousBodyFat),
    },
    {
      'label': 'Muscle Mass',
      'val': metrics.muscleMass.toStringAsFixed(1),
      'unit': ' kg',
      ...calcTrend(metrics.muscleMass, metrics.previousMuscleMass),
    },
    {
      'label': 'Fat Free Mass',
      'val': metrics.fatFreeMass.toStringAsFixed(1),
      'unit': ' kg',
      'trend': '—',
      'isUp': false,
      'isNeutral': true,
    },
    {
      'label': 'Body Water',
      'val': metrics.water.toStringAsFixed(1),
      'unit': ' kg',
      'trend': '—',
      'isUp': false,
      'isNeutral': true,
    },
    {
      'label': 'BMR',
      'val': metrics.bmr.toStringAsFixed(0),
      'unit': ' kcal',
      'trend': '—',
      'isUp': false,
      'isNeutral': true,
    },
    {
      'label': 'Metabolic Age',
      'val': metrics.metabolicAge.toStringAsFixed(0),
      'unit': ' y',
      'trend': '—',
      'isUp': false,
      'isNeutral': true,
    },
  ];
});

// Weekly Activity Data (returns 7 days counts for current week [Mon..Sun])
final weeklyActivityProvider = Provider<List<int>>((ref) {
  final history = ref.watch(workoutHistoryProvider);
  final now = DateTime.now();
  final counts = List.filled(7, 0); // Mon=0, Sun=6

  // start of week (monday)
  final offsetFromSaturday = (now.weekday + 1) % 7;
  final weekStart = now.subtract(Duration(days: offsetFromSaturday));
  final weekStartStartOfDay = DateTime(
    weekStart.year,
    weekStart.month,
    weekStart.day,
  );

  for (final h in history) {
    if (h.timestampIso == null) continue;
    final d = DateTime.parse(h.timestampIso!);
    if (d.isAfter(weekStartStartOfDay) ||
        d.isAtSameMomentAs(weekStartStartOfDay)) {
      counts[d.weekday - 1] += h.completedSets;
    }
  }
  return counts;
});

// Monthly Volume
final monthlyVolumeProvider = Provider<Map<String, dynamic>>((ref) {
  final history = ref.watch(workoutHistoryProvider);
  final now = DateTime.now();
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  int sessions = 0;
  int totalSets = 0;
  int durationMins = 0;

  for (final h in history) {
    if (h.timestampIso == null) continue;
    final d = DateTime.parse(h.timestampIso!);
    if (d.isAfter(thirtyDaysAgo)) {
      sessions++;
      totalSets += h.completedSets;
      durationMins += h.durationMinutes;
    }
  }

  return {
    'sessions': sessions.toString(),
    'totalSets': totalSets.toString(),
    'gymTime': '${(durationMins / 60).toStringAsFixed(1)}h',
  };
});

// Muscle Frequency (Sets per category over 7 days)
final muscleFreqProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final history = ref.watch(workoutHistoryProvider);
  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(const Duration(days: 7));

  Map<String, int> counts = {};
  for (final h in history) {
    if (h.timestampIso == null) continue;
    final d = DateTime.parse(h.timestampIso!);
    if (d.isAfter(sevenDaysAgo)) {
      counts[h.category] = (counts[h.category] ?? 0) + h.completedSets;
    }
  }

  // Predefined colors
  final catColors = {
    'Chest': {'color': 0xFF0A64B0, 'bg': 0xFFE8F5FF},
    'Shoulders': {'color': 0xFF1A7A30, 'bg': 0xFFE8FFF0},
    'Back': {'color': 0xFF0A64B0, 'bg': 0xFFEBF5FF},
    'Legs': {'color': 0xFF7A4D0A, 'bg': 0xFFFFF8E8},
    'Core': {'color': 0xFF5B3FBF, 'bg': 0xFFF0EEFF},
    'Arms': {'color': 0xFFC05A0A, 'bg': 0xFFFFF0E8},
  };

  final List<Map<String, dynamic>> res = [];
  counts.forEach((cat, sets) {
    if (sets > 0) {
      final style = catColors[cat] ?? {'color': 0xFF1C1C1E, 'bg': 0xFFE5E5EA};
      res.add({
        'name': cat,
        'sets': sets,
        'color': style['color'],
        'bg': style['bg'],
      });
    }
  });

  res.sort((a, b) => (b['sets'] as int).compareTo(a['sets'] as int));
  return res;
});

// Personal Records
final profileRecordsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final exerciseHist = ref.watch(exerciseHistoryProvider).value ?? {};

  if (exerciseHist.isEmpty) {
    return [];
  }

  final List<Map<String, dynamic>> res = [];
  int rank = 1;

  // Sort by weight descending
  final sortedEntries = exerciseHist.entries.toList()
    ..sort((a, b) => b.value.weight.compareTo(a.value.weight));

  for (final entry in sortedEntries) {
    final isTop = rank <= 2;
    String dateStr = 'Recently';
    try {
      final dt = DateTime.parse(entry.value.dateIso);
      dateStr = DateFormat('MMM d').format(dt);
    } catch (_) {}

    res.add({
      'name': entry.key,
      'date': dateStr,
      'val': '${entry.value.weight} kg',
      'badge': 'PR',
      'rank': isTop ? '🏆' : rank.toString(),
      'rankBg': isTop ? 0xFFFFF8E8 : 0xFFF5F5F7,
      'rankColor': isTop ? 0xFFB07D10 : 0xFF8E8E93,
    });
    rank++;
  }

  return res;
});
