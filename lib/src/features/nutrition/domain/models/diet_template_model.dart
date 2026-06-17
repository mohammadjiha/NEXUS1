class DietTemplateModel {
  final String id;
  final String bodyType;
  final String goal;
  final String title;
  final int totalCalories;
  final double waterLiters;
  final Macros macros;
  final int numberOfMeals;
  final List<DietTemplateMeal> meals;

  DietTemplateModel({
    required this.id,
    required this.bodyType,
    required this.goal,
    required this.title,
    required this.totalCalories,
    required this.waterLiters,
    required this.macros,
    required this.numberOfMeals,
    required this.meals,
  });

  factory DietTemplateModel.fromJson(Map<String, dynamic> json) {
    return DietTemplateModel(
      id: json['id'] ?? '',
      bodyType: json['bodyType'] ?? '',
      goal: json['goal'] ?? '',
      title: json['title'] ?? '',
      totalCalories: json['totalCalories'] ?? 0,
      waterLiters: (json['waterLiters'] as num?)?.toDouble() ?? 3.0,
      macros: Macros.fromJson(json['macros'] ?? {}),
      numberOfMeals: json['numberOfMeals'] ?? 0,
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => DietTemplateMeal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bodyType': bodyType,
      'goal': goal,
      'title': title,
      'totalCalories': totalCalories,
      'waterLiters': waterLiters,
      'macros': macros.toJson(),
      'numberOfMeals': numberOfMeals,
      'meals': meals.map((e) => e.toJson()).toList(),
    };
  }
}

class DietTemplateMeal {
  final String mealName;
  final int calories;
  final Macros macros;
  final List<DietTemplateItem> items;

  DietTemplateMeal({
    required this.mealName,
    required this.calories,
    required this.macros,
    required this.items,
  });

  factory DietTemplateMeal.fromJson(Map<String, dynamic> json) {
    return DietTemplateMeal(
      mealName: json['mealName'] ?? '',
      calories: json['calories'] ?? 0,
      macros: Macros.fromJson(json['macros'] ?? {}),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => DietTemplateItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mealName': mealName,
      'calories': calories,
      'macros': macros.toJson(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}

class DietTemplateItem {
  final String name;
  final String amount;
  final int calories;

  DietTemplateItem({
    required this.name,
    required this.amount,
    required this.calories,
  });

  factory DietTemplateItem.fromJson(Map<String, dynamic> json) {
    // Clean up corrupted emojis like "?? "
    String cleanName = json['name']?.toString() ?? '';
    cleanName = cleanName.replaceAll(RegExp(r'^\?+\s*'), ''); // removes leading ??
    cleanName = cleanName.replaceAll(RegExp(r'^Y\??\s*'), ''); // removes other corrupted chars

    return DietTemplateItem(
      name: cleanName,
      amount: json['amount'] ?? '',
      calories: json['calories'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'calories': calories,
    };
  }
}

class Macros {
  final int protein;
  final int carbs;
  final int fat;
  final int fiber;

  Macros({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  factory Macros.fromJson(Map<String, dynamic> json) {
    return Macros(
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
      fiber: json['fiber'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
    };
  }
}
