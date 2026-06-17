import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../smart_workout/providers/routines_provider.dart';
import '../../smart_workout/providers/split_setup_provider.dart';
import '../../smart_workout/services/plan_generator.dart';

final playerSplitSetupProvider = FutureProvider.family<SplitSetupData, String>((ref, playerId) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(playerId)
      .collection('appData')
      .doc('split_setup')
      .get();
      
  final data = doc.data()?['setupData'];
  if (data is Map<String, dynamic>) {
    final setupData = SplitSetupData.fromJson(data);
    return setupData.planStartDate == null
        ? setupData.copyWith(planStartDate: DateTime.now())
        : setupData;
  }
  return SplitSetupData(planStartDate: DateTime.now());
});

final playerGeneratedPlanProvider = FutureProvider.family<List<WorkoutDay>, String>((ref, playerId) async {
  final setupData = await ref.watch(playerSplitSetupProvider(playerId).future);
  // Using the coach's version of the catalog (which currently defaults to the standard ms_routines + any modifications)
  // In the future, this could be specifically `playerRoutinesProvider` to fetch the player's modifications.
  final catalog = await ref.watch(routineCatalogProvider.future); 

  return PlanGenerator.generatePlan(
    daysPerWeek: setupData.daysPerWeek,
    splitType: setupData.splitType,
    trainingDays: setupData.trainingDays,
    catalog: catalog,
    startDate: setupData.planStartDate ?? DateTime.now(),
    swaps: setupData.swappedDates,
  );
});
