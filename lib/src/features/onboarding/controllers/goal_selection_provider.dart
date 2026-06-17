import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PrimaryGoal { loseFat, buildMuscle, getFit, maintain }
enum FitnessLevel { beginner, intermediate, advanced }

class GoalSelectionState {
  final PrimaryGoal? primaryGoal;
  final FitnessLevel? fitnessLevel;

  GoalSelectionState({this.primaryGoal, this.fitnessLevel});

  GoalSelectionState copyWith({
    PrimaryGoal? primaryGoal,
    FitnessLevel? fitnessLevel,
  }) {
    return GoalSelectionState(
      primaryGoal: primaryGoal ?? this.primaryGoal,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
    );
  }
}

class GoalSelectionNotifier extends Notifier<GoalSelectionState> {
  @override
  GoalSelectionState build() => GoalSelectionState();

  void selectGoal(PrimaryGoal goal) {
    state = state.copyWith(primaryGoal: goal);
  }

  void selectLevel(FitnessLevel level) {
    state = state.copyWith(fitnessLevel: level);
  }
}

final goalSelectionProvider = NotifierProvider<GoalSelectionNotifier, GoalSelectionState>(GoalSelectionNotifier.new);
