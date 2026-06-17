import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise_model.dart';
import '../models/muscle_group_model.dart';

class ExercisesRepository {
  final FirebaseFirestore _firestore;

  ExercisesRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<MuscleGroupModel>> loadExercises() async {
    final firestoreGroups = await _loadExercisesFromFirestore();
    if (firestoreGroups.isNotEmpty) return firestoreGroups;
    return _loadExercisesFromAsset();
  }

  Future<List<MuscleGroupModel>> _loadExercisesFromFirestore() async {
    try {
      final snapshot = await _firestore
          .collection('exercises')
          .orderBy('sortIndex')
          .get();
      if (snapshot.docs.isEmpty) return [];

      final grouped = <String, List<ExerciseModel>>{};
      final groupImages = <String, String>{};
      final groupNamesAr = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final exercise = ExerciseModel.fromJson(data);
        final group =
            data['MuscleGroup'] as String? ?? exercise.targetMuscleGroup;
        grouped.putIfAbsent(group, () => []).add(exercise);
        groupImages[group] =
            data['Image'] as String? ?? groupImages[group] ?? '';
        groupNamesAr[group] =
            data['MuscleGroupAr'] as String? ?? groupNamesAr[group] ?? '';
      }

      return grouped.entries.map((entry) {
        return MuscleGroupModel(
          muscleGroup: entry.key,
          muscleGroupAr: groupNamesAr[entry.key],
          image: groupImages[entry.key] ?? '',
          exercises: entry.value,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading Firestore exercises: $e');
      return [];
    }
  }

  Future<List<MuscleGroupModel>> _loadExercisesFromAsset() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/all_exercises.json',
      );
      final List<dynamic> data = json.decode(response);
      return data.map((json) => MuscleGroupModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error loading exercises: $e');
      return [];
    }
  }
}

final exercisesRepositoryProvider = Provider<ExercisesRepository>((ref) {
  return ExercisesRepository();
});

final allExercisesProvider = FutureProvider<List<MuscleGroupModel>>((
  ref,
) async {
  // keepAlive: parsed once, never re-parsed on rebuild.
  ref.keepAlive();
  final repository = ref.watch(exercisesRepositoryProvider);
  return repository.loadExercises();
});
