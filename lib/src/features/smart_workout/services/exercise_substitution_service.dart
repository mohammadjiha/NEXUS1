class ExerciseAlternative {
  final String name;
  final String level;
  final String subtitle;

  ExerciseAlternative({
    required this.name,
    required this.level,
    required this.subtitle,
  });
}

class ExerciseSubstitutionInfo {
  final String targetPortion;
  final List<ExerciseAlternative> alternatives;

  ExerciseSubstitutionInfo({
    required this.targetPortion,
    required this.alternatives,
  });
}

class ExerciseSubstitutionService {
  static final Map<String, ExerciseSubstitutionInfo> _substitutions = {
    // CHEST — Upper
    'Incline BB Press': ExerciseSubstitutionInfo(
      targetPortion: 'Chest / Upper Chest',
      alternatives: [
        ExerciseAlternative(name: 'Incline DB Press', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Incline Smith Press', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Low Cable Fly', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Incline DB Press': ExerciseSubstitutionInfo(
      targetPortion: 'Chest / Upper Chest',
      alternatives: [
        ExerciseAlternative(name: 'Incline BB Press', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Incline Smith Press', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Low Cable Fly', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Low Cable Fly': ExerciseSubstitutionInfo(
      targetPortion: 'Chest / Upper Chest',
      alternatives: [
        ExerciseAlternative(name: 'Incline DB Fly', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Incline Cable Fly', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Band Pull Apart', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // CHEST — Lower / General
    'Push Up': ExerciseSubstitutionInfo(
      targetPortion: 'Chest / Triceps / Front Delt',
      alternatives: [
        ExerciseAlternative(name: 'Knee Push Up', level: 'Beginner', subtitle: 'Easier variation'),
        ExerciseAlternative(name: 'Flat DB Press', level: 'Intermediate', subtitle: 'Similar target muscles'),
        ExerciseAlternative(name: 'Incline Push Up', level: 'Beginner', subtitle: 'Easier angle'),
      ],
    ),
    'Flat Bench Press': ExerciseSubstitutionInfo(
      targetPortion: 'Chest / Lower Chest',
      alternatives: [
        ExerciseAlternative(name: 'Flat DB Press', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Smith Bench Press', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'High Cable Fly', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Dip': ExerciseSubstitutionInfo(
      targetPortion: 'Chest / Lower Chest',
      alternatives: [
        ExerciseAlternative(name: 'Weighted Dip', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Decline DB Press', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'High Cable Fly', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'High Cable Fly': ExerciseSubstitutionInfo(
      targetPortion: 'Chest / Lower Chest',
      alternatives: [
        ExerciseAlternative(name: 'Decline DB Fly', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Pec Deck Low', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Resistance Band Fly', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // CHEST — Overall
    'Flat DB Press': ExerciseSubstitutionInfo(
      targetPortion: 'Chest / Overall',
      alternatives: [
        ExerciseAlternative(name: 'Flat Bench Press', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Smith Flat Press', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Cable Crossover', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // BACK — Upper / Lats
    'Pull Up': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Upper Back / Lats',
      alternatives: [
        ExerciseAlternative(name: 'Lat Pulldown', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Assisted Pull Up', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Straight Arm Pulldown', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Lat Pulldown': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Upper Back / Lats',
      alternatives: [
        ExerciseAlternative(name: 'Pull Up', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Pullover', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Band Pulldown', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Single Arm Row': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Lats',
      alternatives: [
        ExerciseAlternative(name: 'Cable Row (one)', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Meadows Row', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'DB Pullover', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // BACK — Mid
    'Seated Cable Row': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Mid Back',
      alternatives: [
        ExerciseAlternative(name: 'Machine Row', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'DB Row', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Barbell Row', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Barbell Row': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Mid Back',
      alternatives: [
        ExerciseAlternative(name: 'DB Row', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Row', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Machine Row', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'T-Bar Row': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Mid Back',
      alternatives: [
        ExerciseAlternative(name: 'Chest Supported Row', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Row Wide', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Machine Row', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // BACK — Lower
    'Romanian DL': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Lower Back',
      alternatives: [
        ExerciseAlternative(name: 'Good Morning', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Back Extension', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Hyperextension', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Good Morning': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Lower Back',
      alternatives: [
        ExerciseAlternative(name: 'Romanian DL', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Hyperextension', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Back Extension', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Back Extension': ExerciseSubstitutionInfo(
      targetPortion: 'Back / Lower Back',
      alternatives: [
        ExerciseAlternative(name: 'Hyperextension', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Romanian DL', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Cable Pull Through', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // SHOULDERS — Front Delt
    'Front Raise DB': ExerciseSubstitutionInfo(
      targetPortion: 'Shoulders / Front Delt',
      alternatives: [
        ExerciseAlternative(name: 'Front Raise BB', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Front Raise', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Plate Raise', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Overhead Press': ExerciseSubstitutionInfo(
      targetPortion: 'Shoulders / Front Delt',
      alternatives: [
        ExerciseAlternative(name: 'Arnold Press', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Smith OHP', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Seated DB Press', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // SHOULDERS — Side Delt
    'Lateral Raise DB': ExerciseSubstitutionInfo(
      targetPortion: 'Shoulders / Side Delt',
      alternatives: [
        ExerciseAlternative(name: 'Cable Lateral Raise', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Machine Lateral Raise', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Upright Row', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Cable Lateral Raise': ExerciseSubstitutionInfo(
      targetPortion: 'Shoulders / Side Delt',
      alternatives: [
        ExerciseAlternative(name: 'Lateral Raise DB', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Machine Lateral Raise', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Band Lateral Raise', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // SHOULDERS — Rear Delt
    'Reverse Fly DB': ExerciseSubstitutionInfo(
      targetPortion: 'Shoulders / Rear Delt',
      alternatives: [
        ExerciseAlternative(name: 'Cable Rear Fly', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Machine Rear Fly', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Face Pull', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Face Pull': ExerciseSubstitutionInfo(
      targetPortion: 'Shoulders / Rear Delt',
      alternatives: [
        ExerciseAlternative(name: 'Reverse Fly DB', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Band Pull Apart', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Cable Rear Fly', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // BICEPS — Long Head
    'Incline DB Curl': ExerciseSubstitutionInfo(
      targetPortion: 'Biceps / Long Head',
      alternatives: [
        ExerciseAlternative(name: 'Hammer Curl', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Curl Low', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Band Curl', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Hammer Curl': ExerciseSubstitutionInfo(
      targetPortion: 'Biceps / Long Head',
      alternatives: [
        ExerciseAlternative(name: 'Incline DB Curl', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cross Body Curl', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Cable Hammer Curl', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // BICEPS — Short Head
    'Preacher Curl': ExerciseSubstitutionInfo(
      targetPortion: 'Biceps / Short Head',
      alternatives: [
        ExerciseAlternative(name: 'Concentration Curl', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Curl High', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Machine Curl', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Concentration Curl': ExerciseSubstitutionInfo(
      targetPortion: 'Biceps / Short Head',
      alternatives: [
        ExerciseAlternative(name: 'Preacher Curl', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Spider Curl', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Machine Curl', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // TRICEPS — Long Head
    'Overhead Extension DB': ExerciseSubstitutionInfo(
      targetPortion: 'Triceps / Long Head',
      alternatives: [
        ExerciseAlternative(name: 'Overhead Extension BB', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Overhead Ext', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Skull Crusher', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Skull Crusher': ExerciseSubstitutionInfo(
      targetPortion: 'Triceps / Long Head',
      alternatives: [
        ExerciseAlternative(name: 'Overhead Extension DB', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Overhead Ext', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'EZ Bar Overhead Ext', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // TRICEPS — Lateral Head
    'Cable Pushdown': ExerciseSubstitutionInfo(
      targetPortion: 'Triceps / Lateral Head',
      alternatives: [
        ExerciseAlternative(name: 'Bar Pushdown', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Band Pushdown', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Kickback DB', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Kickback DB': ExerciseSubstitutionInfo(
      targetPortion: 'Triceps / Lateral Head',
      alternatives: [
        ExerciseAlternative(name: 'Cable Kickback', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Band Kickback', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'One Arm Pushdown', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // QUADS — Overall
    'Barbell Squat': ExerciseSubstitutionInfo(
      targetPortion: 'Quads / Overall',
      alternatives: [
        ExerciseAlternative(name: 'Hack Squat', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Leg Press', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Smith Squat', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Leg Press': ExerciseSubstitutionInfo(
      targetPortion: 'Quads / Overall',
      alternatives: [
        ExerciseAlternative(name: 'Hack Squat', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Smith Squat', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Goblet Squat', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // QUADS — Lower
    'Hack Squat': ExerciseSubstitutionInfo(
      targetPortion: 'Quads / Lower Quad',
      alternatives: [
        ExerciseAlternative(name: 'Leg Press Low', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Sissy Squat', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Leg Extension', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Leg Extension': ExerciseSubstitutionInfo(
      targetPortion: 'Quads / Lower Quad',
      alternatives: [
        ExerciseAlternative(name: 'Sissy Squat', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Hack Squat', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'VMO Squat', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // QUADS — Upper
    'Bulgarian Split Squat': ExerciseSubstitutionInfo(
      targetPortion: 'Quads / Upper Quad',
      alternatives: [
        ExerciseAlternative(name: 'Lunge', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Step Up', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'High Bar Squat', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Lunge': ExerciseSubstitutionInfo(
      targetPortion: 'Quads / Upper Quad',
      alternatives: [
        ExerciseAlternative(name: 'Bulgarian Split Squat', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Step Up', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'DB Squat', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // HAMSTRINGS — Upper
    'Romanian Deadlift': ExerciseSubstitutionInfo(
      targetPortion: 'Hamstrings / Upper',
      alternatives: [
        ExerciseAlternative(name: 'Stiff Leg DL', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Pull Through', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Glute Ham Raise', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Stiff Leg DL': ExerciseSubstitutionInfo(
      targetPortion: 'Hamstrings / Upper',
      alternatives: [
        ExerciseAlternative(name: 'Romanian Deadlift', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Good Morning', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Cable Pull Through', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // HAMSTRINGS — Lower
    'Lying Leg Curl': ExerciseSubstitutionInfo(
      targetPortion: 'Hamstrings / Lower',
      alternatives: [
        ExerciseAlternative(name: 'Seated Leg Curl', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Nordic Curl', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Band Leg Curl', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Nordic Curl': ExerciseSubstitutionInfo(
      targetPortion: 'Hamstrings / Lower',
      alternatives: [
        ExerciseAlternative(name: 'Lying Leg Curl', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Glute Ham Raise', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Stability Ball Curl', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // GLUTES — Overall
    'Hip Thrust': ExerciseSubstitutionInfo(
      targetPortion: 'Glutes / Overall',
      alternatives: [
        ExerciseAlternative(name: 'Glute Bridge', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Cable Kickback', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Bulgarian Split Squat', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Glute Bridge': ExerciseSubstitutionInfo(
      targetPortion: 'Glutes / Overall',
      alternatives: [
        ExerciseAlternative(name: 'Hip Thrust', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Single Leg Bridge', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Cable Pull Through', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // CALVES — Overall
    'Standing Calf Raise': ExerciseSubstitutionInfo(
      targetPortion: 'Calves / Overall',
      alternatives: [
        ExerciseAlternative(name: 'Leg Press Calf Raise', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Smith Machine Calf', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Donkey Calf Raise', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Seated Calf Raise': ExerciseSubstitutionInfo(
      targetPortion: 'Calves / Overall',
      alternatives: [
        ExerciseAlternative(name: 'Leg Press Calf Raise', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Tibialis Raise', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Band Calf Raise', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // ABS — Upper
    'Crunch': ExerciseSubstitutionInfo(
      targetPortion: 'Abs / Upper',
      alternatives: [
        ExerciseAlternative(name: 'Cable Crunch', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Machine Crunch', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Decline Crunch', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Cable Crunch': ExerciseSubstitutionInfo(
      targetPortion: 'Abs / Upper',
      alternatives: [
        ExerciseAlternative(name: 'Crunch', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Swiss Ball Crunch', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Ab Wheel Rollout', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),

    // ABS — Lower
    'Leg Raise': ExerciseSubstitutionInfo(
      targetPortion: 'Abs / Lower',
      alternatives: [
        ExerciseAlternative(name: 'Reverse Crunch', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Ab Wheel Rollout', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Dragon Flag', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
    'Reverse Crunch': ExerciseSubstitutionInfo(
      targetPortion: 'Abs / Lower',
      alternatives: [
        ExerciseAlternative(name: 'Leg Raise', level: 'M1', subtitle: 'Most similar movement'),
        ExerciseAlternative(name: 'Mountain Climber', level: 'M2', subtitle: 'Same angle, different mechanics'),
        ExerciseAlternative(name: 'Hanging Knee Raise', level: 'M3', subtitle: 'Same target, different approach'),
      ],
    ),
  };

  static ExerciseSubstitutionInfo? getAlternatives(String exerciseName) {
    // Normalization logic: Some original names might differ slightly.
    String query = exerciseName.toLowerCase();
    
    // Exact match
    for (var key in _substitutions.keys) {
      if (key.toLowerCase() == query) {
        return _substitutions[key];
      }
    }

    // Fuzzy match
    for (var key in _substitutions.keys) {
      if (query.contains(key.toLowerCase()) || key.toLowerCase().contains(query)) {
        return _substitutions[key];
      }
    }

    return null; // No direct mapping found
  }
}
