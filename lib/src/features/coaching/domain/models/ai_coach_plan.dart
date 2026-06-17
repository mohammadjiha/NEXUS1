class AIPlanFood {
  final String emoji;
  final String name;
  final String amount;
  final int protein;
  final int carbs;
  final int fat;
  final int calories;

  AIPlanFood({
    required this.emoji,
    required this.name,
    required this.amount,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.calories,
  });

  factory AIPlanFood.fromJson(Map<String, dynamic> json) {
    return AIPlanFood(
      emoji: json['emoji'] as String? ?? '🍽️',
      name: json['name'] as String? ?? '',
      amount: json['amount'] as String? ?? '',
      protein: (json['protein'] as num?)?.toInt() ?? 0,
      carbs: (json['carbs'] as num?)?.toInt() ?? 0,
      fat: (json['fat'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
    );
  }

  String get macros => 'P:${protein}g · C:${carbs}g · F:${fat}g';
}

class AIPlanMeal {
  final String icon;
  final String name;
  final String time; // e.g., "08:00 AM"
  final int totalCalories;
  final int protein;
  final int carbs;
  final int fat;
  final List<AIPlanFood> foods;
  final bool isEaten;

  AIPlanMeal({
    required this.icon,
    required this.name,
    required this.time,
    required this.totalCalories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.foods,
    this.isEaten = false,
  });

  factory AIPlanMeal.fromJson(Map<String, dynamic> json) {
    return AIPlanMeal(
      icon: json['icon'] as String? ?? '🍱',
      name: json['name'] as String? ?? '',
      time: json['time'] as String? ?? '',
      totalCalories: (json['totalCalories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toInt() ?? 0,
      carbs: (json['carbs'] as num?)?.toInt() ?? 0,
      fat: (json['fat'] as num?)?.toInt() ?? 0,
      foods: (json['foods'] as List<dynamic>?)
              ?.map((e) => AIPlanFood.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isEaten: json['isEaten'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'icon': icon,
      'name': name,
      'time': time,
      'totalCalories': totalCalories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'foods': foods.map((e) => {
        'emoji': e.emoji,
        'name': e.name,
        'amount': e.amount,
        'protein': e.protein,
        'carbs': e.carbs,
        'fat': e.fat,
        'calories': e.calories,
      }).toList(),
      'isEaten': isEaten,
    };
  }

  String get macros => '$totalCalories kcal · P:${protein}g · C:${carbs}g · F:${fat}g';
}

class AIMacroTarget {
  final int target;
  final int current;

  AIMacroTarget({required this.target, required this.current});

  factory AIMacroTarget.fromJson(Map<String, dynamic> json) {
    return AIMacroTarget(
      target: (json['target'] as num?)?.toInt() ?? 0,
      current: (json['current'] as num?)?.toInt() ?? 0,
    );
  }
}

class AICoachPlan {
  final String summary;
  final int totalCalories;
  final int caloriesBurned;
  final int calorieDeficit;
  final double waterLiters;
  final String workoutFocus;
  final AIMacroTarget protein;
  final AIMacroTarget carbs;
  final AIMacroTarget fat;
  final List<AIPlanMeal> meals;

  AICoachPlan({
    required this.summary,
    required this.totalCalories,
    required this.caloriesBurned,
    required this.calorieDeficit,
    required this.waterLiters,
    required this.workoutFocus,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.meals,
  });

  factory AICoachPlan.fromJson(Map<String, dynamic> json) {
    final macros = json['macros'] as Map<String, dynamic>? ?? {};
    return AICoachPlan(
      summary: json['summary'] as String? ?? '',
      totalCalories: (json['totalCalories'] as num?)?.toInt() ?? 0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toInt() ?? 0,
      calorieDeficit: (json['calorieDeficit'] as num?)?.toInt() ?? 0,
      waterLiters: (json['waterLiters'] as num?)?.toDouble() ?? 0.0,
      workoutFocus: json['workoutFocus'] as String? ?? '',
      protein: AIMacroTarget.fromJson(macros['protein'] as Map<String, dynamic>? ?? {}),
      carbs: AIMacroTarget.fromJson(macros['carbs'] as Map<String, dynamic>? ?? {}),
      fat: AIMacroTarget.fromJson(macros['fat'] as Map<String, dynamic>? ?? {}),
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => AIPlanMeal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
