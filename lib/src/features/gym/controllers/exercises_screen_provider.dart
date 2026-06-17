import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/exercises_repository.dart';
import '../models/exercise_model.dart';

final selectedCategoryProvider = StateProvider<String>((ref) => 'All');

final searchQueryProvider = StateProvider<String>((ref) => '');

class ExerciseFilters {
  final String equipment;
  final String level;

  ExerciseFilters({this.equipment = 'All', this.level = 'All'});

  ExerciseFilters copyWith({String? equipment, String? level}) {
    return ExerciseFilters(
      equipment: equipment ?? this.equipment,
      level: level ?? this.level,
    );
  }
}

final filtersProvider = StateProvider<ExerciseFilters>(
  (ref) => ExerciseFilters(),
);

final filteredExercisesProvider = Provider<AsyncValue<List<ExerciseModel>>>((
  ref,
) {
  final allExercisesAsync = ref.watch(allExercisesProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
  final filters = ref.watch(filtersProvider);

  return allExercisesAsync.whenData((muscleGroups) {
    List<ExerciseModel> allExs = [];

    for (var group in muscleGroups) {
      if (selectedCategory == 'All' ||
          group.muscleGroup.toLowerCase() == selectedCategory.toLowerCase()) {
        allExs.addAll(group.exercises);
      }
    }

    if (searchQuery.isNotEmpty) {
      allExs = allExs.where((ex) => ex.matchesSearch(searchQuery)).toList();
    }

    if (filters.equipment != 'All') {
      allExs = allExs
          .where(
            (ex) =>
                ex.equipmentRequired.toLowerCase() ==
                filters.equipment.toLowerCase(),
          )
          .toList();
    }

    if (filters.level != 'All') {
      allExs = allExs
          .where(
            (ex) =>
                ex.experienceLevel.toLowerCase() == filters.level.toLowerCase(),
          )
          .toList();
    }

    return allExs;
  });
});
