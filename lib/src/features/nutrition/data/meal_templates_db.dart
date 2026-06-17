import '../domain/models/food_model.dart';
import 'local_food_db.dart';

class MealTemplate {
  final String id;
  final String title;
  final String description;
  final String category;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final Map<String, List<FoodModel>> meals;

  const MealTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.meals,
  });
}

class MealTemplatesDB {
  static FoodModel _f(String id) => LocalFoodDB.foods.firstWhere((element) => element.id == id);

  static final List<MealTemplate> templates = [
    // -----------------------------------------------------
    // 1. FAT LOSS (تنشيف وحرق دهون)
    // -----------------------------------------------------
    MealTemplate(
      id: 't1',
      title: 'Aggressive Shred 1500',
      description: 'جدول قاسي للتنشيف السريع. عالي جداً بالبروتين لضمان عدم خسارة العضلات أثناء العجز في السعرات.',
      category: 'Fat Loss',
      totalCalories: 1484,
      totalProtein: 128,
      totalCarbs: 153,
      totalFat: 35,
      meals: {
        'Breakfast': [_f('d1'), _f('d2'), _f('g1')], // Whole Eggs, Egg Whites, Oats
        'Lunch': [_f('m1'), _f('m1'), _f('g5'), _f('v1')], // Chicken x2, Sweet Potato, Broccoli
        'Dinner': [_f('s2'), _f('g2'), _f('v3')], // Salmon, White Rice, Salad
        'Snacks': [],
      },
    ),
    MealTemplate(
      id: 't2',
      title: 'Lean Shred 1800',
      description: 'جدول تنشيف معتدل ومريح. يسمح لك بأكل كمية جيدة من الكارب للتمارين القوية مع حرق الدهون.',
      category: 'Fat Loss',
      totalCalories: 1817,
      totalProtein: 153,
      totalCarbs: 161,
      totalFat: 47,
      meals: {
        'Breakfast': [_f('d1'), _f('g1'), _f('d3')], // Whole Eggs, Oats, Greek Yogurt
        'Lunch': [_f('m1'), _f('m1'), _f('g5'), _f('v1'), _f('f4')], // Chicken x2, Sweet Potato, Broccoli, Olive Oil
        'Dinner': [_f('s4'), _f('g2'), _f('v3')], // Tilapia, White Rice, Salad
        'Snacks': [_f('sup1'), _f('fr1')], // Whey Isolate, Banana
      },
    ),

    // -----------------------------------------------------
    // 2. LEAN BULK (تضخيم صافي وزيادة عضلات)
    // -----------------------------------------------------
    MealTemplate(
      id: 't3',
      title: 'Clean Bulk 2800',
      description: 'جدول ممتاز لزيادة الكتلة العضلية بدون دهون. يعتمد على الكربوهيدرات المعقدة لضخامة صافية.',
      category: 'Lean Bulk',
      totalCalories: 2795,
      totalProtein: 175,
      totalCarbs: 320,
      totalFat: 85,
      meals: {
        'Breakfast': [_f('d1'), _f('d1'), _f('g1'), _f('f2'), _f('fr1')], // 4 Eggs, Oats, Peanut Butter, Banana
        'Lunch': [_f('m1'), _f('m1'), _f('g2'), _f('g2'), _f('v2')], // Chicken x2, Rice x2, Spinach
        'Dinner': [_f('m3'), _f('m3'), _f('g6'), _f('v6')], // Lean Beef x2, White Potato, Bell Pepper
        'Snacks': [_f('sup1'), _f('fr2'), _f('f1')], // Whey Isolate, Apple, Almonds
      },
    ),
    MealTemplate(
      id: 't4',
      title: 'Heavy Gainer 3400',
      description: 'للأشخاص الذين يعانون من صعوبة في زيادة الوزن (Hardgainers). وجبات غنية جداً بالسعرات الصحية.',
      category: 'Lean Bulk',
      totalCalories: 3350,
      totalProtein: 190,
      totalCarbs: 410,
      totalFat: 105,
      meals: {
        'Breakfast': [_f('d1'), _f('d1'), _f('g1'), _f('g1'), _f('f2'), _f('fr1'), _f('fr1')], // Huge breakfast
        'Lunch': [_f('m1'), _f('m1'), _f('g7'), _f('g7'), _f('f4')], // Chicken, Double Pasta, Olive Oil
        'Dinner': [_f('s2'), _f('s2'), _f('g2'), _f('g2'), _f('f3')], // Double Salmon, Double Rice, Avocado
        'Snacks': [_f('sup4'), _f('d5')], // Mass Gainer, Whole Milk
      },
    ),

    // -----------------------------------------------------
    // 3. MAINTENANCE & OTHERS (محافظة وخيارات أخرى)
    // -----------------------------------------------------
    MealTemplate(
      id: 't5',
      title: 'Maintain & Recomp 2200',
      description: 'جدول متوازن للحفاظ على الوزن الحالي مع بناء العضل (Recomposition). ممتاز لمن لا يريد زيادة أو نقصان.',
      category: 'Maintenance',
      totalCalories: 2185,
      totalProtein: 155,
      totalCarbs: 220,
      totalFat: 68,
      meals: {
        'Breakfast': [_f('d1'), _f('d2'), _f('g1'), _f('fr5')], // Eggs, Egg Whites, Oats, Strawberries
        'Lunch': [_f('m1'), _f('g2'), _f('v1'), _f('f4')], // Chicken, Rice, Broccoli, Olive Oil
        'Dinner': [_f('m3'), _f('g5'), _f('v3')], // Lean Beef, Sweet Potato, Salad
        'Snacks': [_f('sup1'), _f('f1'), _f('fr1')], // Whey Isolate, Almonds, Banana
      },
    ),
    MealTemplate(
      id: 't6',
      title: 'Keto Shred 1700',
      description: 'نظام الكيتو (عالي الدهون، منخفض الكارب جداً). يعتمد على حرق الدهون كمصدر طاقة للجسم.',
      category: 'Keto',
      totalCalories: 1680,
      totalProtein: 125,
      totalCarbs: 25,
      totalFat: 115,
      meals: {
        'Breakfast': [_f('d1'), _f('d1'), _f('d7')], // 4 Eggs, Cheddar Cheese
        'Lunch': [_f('m2'), _f('m2'), _f('f3'), _f('v3')], // Chicken Thighs x2, Avocado, Salad
        'Dinner': [_f('s2'), _f('v1'), _f('f4')], // Salmon, Broccoli, Olive Oil
        'Snacks': [_f('f5')], // Walnuts
      },
    ),
  ];
}
