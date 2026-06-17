class AICoachReport {
  final int formScore;
  final int totalReps;
  final int correctReps;
  final String exerciseName;
  final String coachFeedback;
  final List<CoachIssue> issues;
  final List<String> goodPoints;
  final String? recommendedAlternative;

  AICoachReport({
    required this.formScore,
    required this.totalReps,
    required this.correctReps,
    required this.exerciseName,
    required this.coachFeedback,
    required this.issues,
    required this.goodPoints,
    this.recommendedAlternative,
  });

  factory AICoachReport.fromJson(Map<String, dynamic> json) {
    return AICoachReport(
      formScore: json['formScore'] ?? 0,
      totalReps: json['totalReps'] ?? 0,
      correctReps: json['correctReps'] ?? 0,
      exerciseName: json['exerciseName'] ?? 'Unknown Exercise',
      coachFeedback: json['coachFeedback'] ?? '',
      issues: (json['issues'] as List<dynamic>?)
              ?.map((e) => CoachIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      goodPoints: (json['goodPoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendedAlternative: json['recommendedAlternative'],
    );
  }
}

class CoachIssue {
  final String title;
  final String severity; // 'Critical' | 'Warning'
  final String description;
  final String fix;
  final List<int> reps;

  CoachIssue({
    required this.title,
    required this.severity,
    required this.description,
    required this.fix,
    required this.reps,
  });

  factory CoachIssue.fromJson(Map<String, dynamic> json) {
    return CoachIssue(
      title: json['title'] ?? '',
      severity: json['severity'] ?? 'Warning',
      description: json['description'] ?? '',
      fix: json['fix'] ?? '',
      reps: (json['reps'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .toList() ??
          [],
    );
  }
}
