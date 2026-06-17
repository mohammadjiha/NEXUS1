import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../gym/models/exercise_model.dart';

class MyPlanNotifier extends Notifier<List<ExerciseModel>> {
  @override
  List<ExerciseModel> build() {
    // Load favorites asynchronously but initialize with empty list
    _loadFavorites();
    return [];
  }

  String get _storageKey {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'my_plan_favorites_$userId';
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_storageKey);
    if (favoritesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(favoritesJson) as List<dynamic>;
        final List<ExerciseModel> loaded = decoded
            .map((item) => ExerciseModel.fromJson(item as Map<String, dynamic>))
            .toList();
        state = loaded;
      } catch (e) {
        debugPrint('Error parsing favorites: $e');
      }
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encoded = state.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(encoded));
  }

  void toggleFavorite(ExerciseModel exercise) {
    if (isFavorite(exercise.name)) {
      state = state.where((e) => e.name != exercise.name).toList();
    } else {
      state = [...state, exercise];
    }
    _saveFavorites();
  }

  bool isFavorite(String name) {
    return state.any((e) => e.name == name);
  }

  Map<String, List<ExerciseModel>> getGroupedByMuscle() {
    final map = <String, List<ExerciseModel>>{};
    for (var exercise in state) {
      if (!map.containsKey(exercise.targetMuscleGroup)) {
        map[exercise.targetMuscleGroup] = [];
      }
      map[exercise.targetMuscleGroup]!.add(exercise);
    }
    return map;
  }
}

final myPlanProvider = NotifierProvider<MyPlanNotifier, List<ExerciseModel>>(MyPlanNotifier.new);
