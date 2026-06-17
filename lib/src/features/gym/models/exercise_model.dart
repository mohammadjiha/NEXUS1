class ExerciseModel {
  final String name;
  final String targetMuscleGroup;
  final String exerciseType;
  final String equipmentRequired;
  final String mechanics;
  final String forceType;
  final String experienceLevel;
  final String secondaryMuscles;
  final String videoLink;
  final String warnings;
  final List<String> steps;
  final String? nameAr;
  final String? targetMuscleGroupAr;
  final String? exerciseTypeAr;
  final String? equipmentRequiredAr;
  final String? mechanicsAr;
  final String? forceTypeAr;
  final String? experienceLevelAr;
  final String? secondaryMusclesAr;
  final String? warningsAr;
  final List<String> stepsAr;

  ExerciseModel({
    required this.name,
    required this.targetMuscleGroup,
    required this.exerciseType,
    required this.equipmentRequired,
    required this.mechanics,
    required this.forceType,
    required this.experienceLevel,
    required this.secondaryMuscles,
    required this.videoLink,
    required this.warnings,
    required this.steps,
    this.nameAr,
    this.targetMuscleGroupAr,
    this.exerciseTypeAr,
    this.equipmentRequiredAr,
    this.mechanicsAr,
    this.forceTypeAr,
    this.experienceLevelAr,
    this.secondaryMusclesAr,
    this.warningsAr,
    this.stepsAr = const [],
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      name: json['Name'] ?? json['name'] ?? 'Unknown',
      targetMuscleGroup:
          json['TargetMuscleGroup'] ?? json['targetMuscleGroup'] ?? 'Unknown',
      exerciseType: json['ExerciseType'] ?? json['exerciseType'] ?? 'None',
      equipmentRequired:
          json['EquipmentRequired'] ?? json['equipmentRequired'] ?? 'None',
      mechanics: json['Mechanics'] ?? json['mechanics'] ?? 'None',
      forceType: json['ForceType'] ?? json['forceType'] ?? 'None',
      experienceLevel:
          json['ExperienceLevel'] ?? json['experienceLevel'] ?? 'None',
      secondaryMuscles:
          json['SecondaryMuscles'] ?? json['secondaryMuscles'] ?? 'None',
      videoLink: json['VideoLink'] ?? json['videoLink'] ?? 'None',
      warnings: json['Warnings'] ?? json['warnings'] ?? 'None',
      steps: json['Steps'] != null
          ? (json['Steps'] as List<dynamic>).map((e) => e.toString()).toList()
          : (json['steps'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
      nameAr: json['NameAr'] ?? json['nameAr'],
      targetMuscleGroupAr:
          json['TargetMuscleGroupAr'] ?? json['targetMuscleGroupAr'],
      exerciseTypeAr: json['ExerciseTypeAr'] ?? json['exerciseTypeAr'],
      equipmentRequiredAr:
          json['EquipmentRequiredAr'] ?? json['equipmentRequiredAr'],
      mechanicsAr: json['MechanicsAr'] ?? json['mechanicsAr'],
      forceTypeAr: json['ForceTypeAr'] ?? json['forceTypeAr'],
      experienceLevelAr: json['ExperienceLevelAr'] ?? json['experienceLevelAr'],
      secondaryMusclesAr:
          json['SecondaryMusclesAr'] ?? json['secondaryMusclesAr'],
      warningsAr: json['WarningsAr'] ?? json['warningsAr'],
      stepsAr: json['StepsAr'] != null
          ? (json['StepsAr'] as List<dynamic>).map((e) => e.toString()).toList()
          : (json['stepsAr'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
    );
  }

  bool _isArabic(String locale) => locale.toLowerCase().startsWith('ar');

  String _localized(String locale, String fallback, String? ar) {
    if (_isArabic(locale) && ar != null && ar.trim().isNotEmpty) {
      return ar.trim();
    }
    return fallback;
  }

  String localizedName(String locale) => _localized(locale, name, nameAr);

  String localizedTargetMuscleGroup(String locale) =>
      _localized(locale, targetMuscleGroup, targetMuscleGroupAr);

  String localizedExerciseType(String locale) =>
      _localized(locale, exerciseType, exerciseTypeAr);

  String localizedEquipmentRequired(String locale) =>
      _localized(locale, equipmentRequired, equipmentRequiredAr);

  String localizedMechanics(String locale) =>
      _localized(locale, mechanics, mechanicsAr);

  String localizedForceType(String locale) =>
      _localized(locale, forceType, forceTypeAr);

  String localizedExperienceLevel(String locale) =>
      _localized(locale, experienceLevel, experienceLevelAr);

  String localizedSecondaryMuscles(String locale) =>
      _localized(locale, secondaryMuscles, secondaryMusclesAr);

  String localizedWarnings(String locale) =>
      _localized(locale, warnings, warningsAr);

  List<String> localizedSteps(String locale) {
    if (_isArabic(locale) && stepsAr.isNotEmpty) return stepsAr;
    return steps;
  }

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    final haystack = [
      name,
      nameAr,
      targetMuscleGroup,
      targetMuscleGroupAr,
      exerciseType,
      exerciseTypeAr,
      equipmentRequired,
      equipmentRequiredAr,
      secondaryMuscles,
      secondaryMusclesAr,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(normalized);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'targetMuscleGroup': targetMuscleGroup,
      'exerciseType': exerciseType,
      'equipmentRequired': equipmentRequired,
      'mechanics': mechanics,
      'forceType': forceType,
      'experienceLevel': experienceLevel,
      'secondaryMuscles': secondaryMuscles,
      'videoLink': videoLink,
      'warnings': warnings,
      'steps': steps,
      if (nameAr != null) 'nameAr': nameAr,
      if (targetMuscleGroupAr != null)
        'targetMuscleGroupAr': targetMuscleGroupAr,
      if (exerciseTypeAr != null) 'exerciseTypeAr': exerciseTypeAr,
      if (equipmentRequiredAr != null)
        'equipmentRequiredAr': equipmentRequiredAr,
      if (mechanicsAr != null) 'mechanicsAr': mechanicsAr,
      if (forceTypeAr != null) 'forceTypeAr': forceTypeAr,
      if (experienceLevelAr != null) 'experienceLevelAr': experienceLevelAr,
      if (secondaryMusclesAr != null) 'secondaryMusclesAr': secondaryMusclesAr,
      if (warningsAr != null) 'warningsAr': warningsAr,
      if (stepsAr.isNotEmpty) 'stepsAr': stepsAr,
    };
  }
}
