import 'dart:convert';

class FoodModel {
  final String id;
  final String name;
  final String? nameAr; // Arabic name (optional — populated via admin upload script)
  final String emoji;
  final String servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double gymScore;
  final List<String> tags;
  final bool isHighGymScore; // To quickly identify top picks

  const FoodModel({
    required this.id,
    required this.name,
    this.nameAr,
    required this.emoji,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.gymScore,
    required this.tags,
  }) : isHighGymScore = gymScore >= 8.0;

  factory FoodModel.fromMap(String id, Map<String, dynamic> map) {
    return FoodModel(
      id: id,
      name: map['name'] as String? ?? '',
      nameAr: map['nameAr'] as String?,
      emoji: map['emoji'] as String? ?? '🍽️',
      servingSize: map['servingSize'] as String? ?? '100g', // Default serving
      calories: (map['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (map['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (map['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (map['fat'] as num?)?.toDouble() ?? 0.0,
      fiber: (map['fiber'] as num?)?.toDouble() ?? 0.0,
      gymScore: (map['gymScore'] as num?)?.toDouble() ?? 0.0,
      tags:
          (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (map['namePrefixes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  factory FoodModel.fromJson(String source) {
    final map = json.decode(source);
    return FoodModel.fromMap(map['id'] as String? ?? '', map);
  }

  String toJson() => json.encode(toMap());

  /// Returns the display name for the given locale code ('ar' or 'en').
  String localizedName(String locale) {
    if (locale == 'ar' && nameAr != null && nameAr!.trim().isNotEmpty) {
      return nameAr!;
    }
    return name;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    if (nameAr != null) 'nameAr': nameAr,
    'emoji': emoji,
    'servingSize': servingSize,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'gymScore': gymScore,
    'tags': tags,
  };
}
