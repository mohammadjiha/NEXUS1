import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/body_metrics_provider.dart';
import '../../smart_workout/models/routine_model.dart';
import '../../smart_workout/providers/split_setup_provider.dart';
import '../../smart_workout/providers/workout_history_provider.dart';
import '../../smart_workout/services/plan_generator.dart';

// 1. Workout History Provider for a specific player
final playerWorkoutHistoryProvider = StreamProvider.family<List<CompletedSession>, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('workoutHistory')
      .orderBy('timestampIso', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => CompletedSession.fromJson(doc.data()))
        .toList();
  });
});

// 2. Body Metrics Provider for a specific player
final playerBodyMetricsProvider = StreamProvider.family<BodyMetrics, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('metrics')
      .doc('body_composition')
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) {
      return BodyMetrics();
    }
    return BodyMetrics.fromJson(snapshot.data()!);
  });
});

// Helper: Player Base + Modified Routines
final playerRoutinesProvider = FutureProvider.family<List<RoutineModel>, String>((ref, playerId) async {
  try {
    final jsonString = await rootBundle.loadString('assets/data/ms_routines.json');
    final dynamic decoded = jsonDecode(jsonString);
    final List<dynamic> jsonData = decoded is Map ? decoded['routines'] : decoded;
    final baseRoutines = jsonData.map((e) => RoutineModel.fromJson(e as Map<String, dynamic>)).toList();

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(playerId)
        .collection('appData')
        .doc('modified_routines')
        .get();
        
    final decodedMods = doc.data()?['routines'];
    if (decodedMods is Map<String, dynamic>) {
      final newRoutines = [...baseRoutines];
      for (var i = 0; i < newRoutines.length; i++) {
        final id = newRoutines[i].id;
        if (decodedMods.containsKey(id)) {
          newRoutines[i] = RoutineModel.fromJson(decodedMods[id] as Map<String, dynamic>);
        }
      }
      return newRoutines;
    }
    return baseRoutines;
  } catch (e) {
    return [];
  }
});

// Helper: Player Split Setup
final playerSplitSetupProvider = StreamProvider.family<SplitSetupData, String>((ref, playerId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('appData')
      .doc('split_setup')
      .snapshots()
      .map((snapshot) {
    final data = snapshot.data()?['setupData'];
    if (data is Map<String, dynamic>) {
      final setupData = SplitSetupData.fromJson(data);
      return setupData.planStartDate == null
          ? setupData.copyWith(planStartDate: DateTime.now())
          : setupData;
    }
    return SplitSetupData(planStartDate: DateTime.now());
  });
});

// Helper: Player Generated Plan
final playerGeneratedPlanProvider = FutureProvider.family<List<WorkoutDay>, String>((ref, playerId) async {
  final routines = await ref.watch(playerRoutinesProvider(playerId).future);
  final splitSetupData = await ref.watch(playerSplitSetupProvider(playerId).future);
  
  final catalog = <String, List<RoutineModel>>{};
  for (var routine in routines) {
    catalog.putIfAbsent(routine.category, () => []).add(routine);
  }

  return PlanGenerator.generatePlan(
    daysPerWeek: splitSetupData.daysPerWeek,
    splitType: splitSetupData.splitType,
    trainingDays: splitSetupData.trainingDays,
    catalog: catalog,
    startDate: splitSetupData.planStartDate ?? DateTime.now(),
    swaps: splitSetupData.swappedDates,
  );
});

// 3. Routine Provider for a specific player (to fetch today's routine or active plan)
final playerRoutineProvider = FutureProvider.family<List<RoutineModel>, String>((ref, playerId) async {
  final plan = await ref.watch(playerGeneratedPlanProvider(playerId).future);
  if (plan.isEmpty) return [];
  
  final today = plan.first;
  if (today.isRest || today.assignedRoutineId == null) return [];
  
  final routines = await ref.watch(playerRoutinesProvider(playerId).future);
  try {
    return [routines.firstWhere((r) => r.id == today.assignedRoutineId)];
  } catch (_) {
    return [routines.first];
  }
});

// 4. Daily Nutrition Provider for a specific player
final playerNutritionHistoryProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  final dateStr = DateTime.now().toIso8601String().split('T').first;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('daily_nutrition')
      .doc(dateStr)
      .snapshots()
      .map((snapshot) {
    if (snapshot.exists && snapshot.data() != null) {
      return snapshot.data() as Map<String, dynamic>;
    }
    return null;
  });
});
