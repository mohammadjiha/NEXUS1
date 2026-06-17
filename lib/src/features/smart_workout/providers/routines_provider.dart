import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../models/routine_model.dart';

class RoutinesNotifier extends AsyncNotifier<List<RoutineModel>> {
  List<RoutineModel>? _originalRoutines;

  @override
  Future<List<RoutineModel>> build() async {
    // Watch auth state before any async gaps
    ref.watch(authStateProvider);
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/ms_routines.json',
      );
      final dynamic decoded = jsonDecode(jsonString);
      final List<dynamic> jsonData = (decoded is Map
          ? decoded['routines']
          : decoded) as List<dynamic>;
      final routines = jsonData
          .map((e) => RoutineModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _originalRoutines = routines.toList();

      return await _loadModifiedRoutines(routines);
    } catch (e) {
      debugPrint('Error loading routines: $e');
      return [];
    }
  }

  Future<List<RoutineModel>> _loadModifiedRoutines(
    List<RoutineModel> baseRoutines,
  ) async {
    try {
      final user = ref.read(authStateProvider).asData?.value;
      if (user == null) return baseRoutines;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appData')
          .doc('modified_routines')
          .get();
      final decoded = doc.data()?['routines'];
      if (decoded is Map<String, dynamic>) {
        final newRoutines = [...baseRoutines];
        for (var i = 0; i < newRoutines.length; i++) {
          final id = newRoutines[i].id;
          if (decoded.containsKey(id)) {
            newRoutines[i] = RoutineModel.fromJson(
              decoded[id] as Map<String, dynamic>,
            );
          }
        }
        return newRoutines;
      }
      return baseRoutines;
    } catch (_) {
      return baseRoutines;
    }
  }

  void updateRoutine(String id, RoutineModel newRoutine) {
    state.whenData((routines) {
      final index = routines.indexWhere((r) => r.id == id);
      if (index != -1) {
        final newRoutines = [...routines];
        newRoutines[index] = newRoutine;
        state = AsyncData(newRoutines);
        _saveModifiedRoutine(newRoutine);
      }
    });
  }

  Future<void> _saveModifiedRoutine(RoutineModel routine) async {
    try {
      final user = ref.read(authStateProvider).asData?.value;
      if (user == null) return;

      final routineData = {
        'id': routine.id,
        'category': routine.category,
        'routineName': routine.routineName,
        'description': routine.description,
        'exercises': routine.exercises
            .map(
              (e) => {
                'name': e.name,
                'sets': e.sets,
                'reps': e.reps,
                'weight': e.weight,
                'restTime': e.restTime,
                'note': e.note,
              },
            )
            .toList(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appData')
          .doc('modified_routines')
          .set({
            'routines': {routine.id: routineData},
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving modified routine: $e');
    }
  }

  void quick30Routine(String id) {
    if (_originalRoutines == null) return;
    state.whenData((routines) {
      final index = routines.indexWhere((r) => r.id == id);
      if (index != -1) {
        final routine = _originalRoutines!.firstWhere((r) => r.id == id);
        // Keep only first 3 exercises
        final newExercises = routine.exercises.take(3).toList();
        final newRoutine = routine.copyWith(
          exercises: newExercises,
          description: 'Quick 30: Core movements only.',
        );
        updateRoutine(id, newRoutine);
      }
    });
  }

  void focused45Routine(String id) {
    if (_originalRoutines == null) return;
    state.whenData((routines) {
      final index = routines.indexWhere((r) => r.id == id);
      if (index != -1) {
        final routine = _originalRoutines!.firstWhere((r) => r.id == id);
        final newRoutine = routine.copyWith(
          description: 'Focused 45: Keep all exercises, cut rest time.',
        );
        updateRoutine(id, newRoutine);
      }
    });
  }

  void adjustIntensityLevel(String id, String level) {
    if (_originalRoutines == null) return;
    state.whenData((routines) {
      final index = routines.indexWhere((r) => r.id == id);
      if (index != -1) {
        final originalRoutine = _originalRoutines!.firstWhere(
          (r) => r.id == id,
        );

        var newExercises = [...originalRoutine.exercises];
        String newDescription = originalRoutine.description;

        if (level == 'easy') {
          if (newExercises.isNotEmpty) newExercises.removeLast();
          newExercises = newExercises.map((e) {
            final reps = e.reps.toLowerCase().contains('fail') ? '8' : e.reps;
            return e.copyWith(
              sets: e.sets > 1 ? e.sets - 1 : 1,
              weight: _roundWeight(e.weight * 0.80),
              restTime: e.restTime + 30,
              reps: reps,
            );
          }).toList();
          newDescription =
              'Easy Mode: Trimmed volume, lighter weights, longer rest.';
        } else if (level == 'lighter') {
          newExercises = newExercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return e.copyWith(
              sets: (i < 2 && e.sets > 1) ? e.sets - 1 : e.sets,
              weight: _roundWeight(e.weight * 0.85),
              restTime: e.restTime + 15,
            );
          }).toList();
          newDescription =
              'Lighter: Reduced sets on main lifts, weights dropped 15%.';
        } else if (level == 'normal') {
          newDescription = 'As Planned: Standard intensity.';
        } else if (level == 'harder') {
          newExercises = newExercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            String? note = e.note;
            String reps = e.reps;
            if (i < 2) note = 'Last set Rest-Pause';
            if (e.reps.toLowerCase().contains('fail')) {
              reps = 'Failure + push past failure';
            }
            return e.copyWith(
              weight: _roundWeight(e.weight * 1.05),
              restTime: e.restTime - 15 < 30 ? 30 : e.restTime - 15,
              reps: reps,
              note: note,
            );
          }).toList();
          newDescription =
              'Push Harder: Increased weight, shorter rest, Rest-Pause on core lifts.';
        } else if (level == 'beast') {
          newExercises = newExercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            String note = 'Last set Drop Set';
            if (i >= newExercises.length - 2) {
              note = 'Last set Drop Set + Superset';
            }
            String reps = e.reps;
            if (e.reps.toLowerCase().contains('fail')) {
              reps = 'Failure + Drop Set';
            }
            return e.copyWith(
              sets: e.sets + 1,
              weight: _roundWeight(e.weight * 1.10),
              restTime: e.restTime - 30 < 30 ? 30 : e.restTime - 30,
              reps: reps,
              note: note,
            );
          }).toList();
          newDescription =
              'Beast Mode: More sets, heavier weight, very short rest, Drop Sets & Supersets! 💀';
        }

        final newRoutine = originalRoutine.copyWith(
          exercises: newExercises,
          description: newDescription,
        );
        updateRoutine(id, newRoutine);
      }
    });
  }

  double _roundWeight(double weight) {
    return (weight / 2.5).roundToDouble() * 2.5;
  }

  RoutineModel? previewMuscleSwap(
    RoutineModel currentRoutine,
    String newCategory,
  ) {
    if (_originalRoutines == null) return null;

    // Find a routine that matches the new category
    final matchingRoutines = _originalRoutines!
        .where((r) => r.category == newCategory)
        .toList();
    if (matchingRoutines.isEmpty) return null;

    final targetRoutine = matchingRoutines
        .first; // Grab the first available routine for that muscle

    // Take 4-5 exercises
    final exerciseCount = currentRoutine.exercises.length > 5
        ? 5
        : (currentRoutine.exercises.length < 4
              ? 4
              : currentRoutine.exercises.length);
    final newExercises = targetRoutine.exercises.take(exerciseCount).toList();

    // Map the new exercises but keep default weights and try to match sets/rest from original if we wanted,
    // but the prompt says: "take from last session, if none calculate 70% of 1RM, maintain total sets".
    // We will simulate this by keeping the sets from the new routine, but adjusting if needed to match total volume.

    int currentTotalSets = currentRoutine.exercises.fold(
      0,
      (total, e) => total + e.sets,
    );
    int newTotalSets = newExercises.fold(0, (total, e) => total + e.sets);

    // Adjust sets of the last exercise to match roughly
    if (newExercises.isNotEmpty && currentTotalSets != newTotalSets) {
      final diff = currentTotalSets - newTotalSets;
      final lastEx = newExercises.last;
      final adjustedSets = (lastEx.sets + diff) > 0 ? (lastEx.sets + diff) : 1;
      newExercises[newExercises.length - 1] = lastEx.copyWith(
        sets: adjustedSets,
      );
    }

    return currentRoutine.copyWith(
      routineName: 'Switched: $newCategory Focus',
      category: newCategory,
      description: 'Switched from ${currentRoutine.category} to $newCategory.',
      exercises: newExercises,
    );
  }
}

final msRoutinesProvider =
    AsyncNotifierProvider<RoutinesNotifier, List<RoutineModel>>(() {
      return RoutinesNotifier();
    });

final routineCatalogProvider = FutureProvider<Map<String, List<RoutineModel>>>((
  ref,
) async {
  final routines = await ref.watch(msRoutinesProvider.future);
  final map = <String, List<RoutineModel>>{};
  for (var routine in routines) {
    map.putIfAbsent(routine.category, () => []).add(routine);
  }
  return map;
});
