import 'exercise_model.dart';

class MuscleGroupModel {
  final String muscleGroup;
  final String? muscleGroupAr;
  final String image;
  final List<ExerciseModel> exercises;

  MuscleGroupModel({
    required this.muscleGroup,
    this.muscleGroupAr,
    required this.image,
    required this.exercises,
  });

  factory MuscleGroupModel.fromJson(Map<String, dynamic> json) {
    return MuscleGroupModel(
      muscleGroup: json['MuscleGroup'] ?? '',
      muscleGroupAr: json['MuscleGroupAr'] ?? json['muscleGroupAr'],
      image: json['Image'] ?? '',
      exercises: json['Exercises'] != null
          ? (json['Exercises'] as List)
                .map((i) => ExerciseModel.fromJson(i))
                .toList()
          : [],
    );
  }

  String localizedMuscleGroup(String locale) {
    if (locale.toLowerCase().startsWith('ar') &&
        muscleGroupAr != null &&
        muscleGroupAr!.trim().isNotEmpty) {
      return muscleGroupAr!.trim();
    }
    return muscleGroup;
  }
}
