import '../domain/models/food_model.dart';

class LocalFoodDB {
  static const List<FoodModel> foods = [
    // ==========================================
    // 🥩 MEATS & POULTRY (مصادر اللحوم والدواجن)
    // ==========================================
    FoodModel(id: 'm1', name: 'Chicken Breast (skinless, grilled)', emoji: '🍗', servingSize: '100g', calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0.0, gymScore: 9.8, tags: ['protein', 'meat', 'chicken', 'poultry', 'lean', 'دجاج', 'صدر دجاج']),
    FoodModel(id: 'm2', name: 'Chicken Thigh (roasted, skin eaten)', emoji: '🍗', servingSize: '100g', calories: 232, protein: 23.5, carbs: 0, fat: 14.8, fiber: 0.0, gymScore: 8.0, tags: ['protein', 'meat', 'chicken', 'فخذ دجاج']),
    FoodModel(id: 'm3', name: 'Lean Beef (95% lean, cooked)', emoji: '🥩', servingSize: '100g', calories: 171, protein: 26, carbs: 0, fat: 6.5, fiber: 0.0, gymScore: 9.0, tags: ['protein', 'meat', 'beef', 'لحم بقري']),
    FoodModel(id: 'm4', name: 'Ground Beef (80% lean, cooked)', emoji: '🥩', servingSize: '100g', calories: 254, protein: 24, carbs: 0, fat: 17, fiber: 0.0, gymScore: 7.5, tags: ['protein', 'meat', 'beef', 'لحم مفروم']),
    FoodModel(id: 'm5', name: 'Turkey Breast (roasted)', emoji: '🦃', servingSize: '100g', calories: 135, protein: 30, carbs: 0, fat: 1, fiber: 0.0, gymScore: 9.7, tags: ['protein', 'meat', 'lean', 'حبش', 'ديك رومي']),
    FoodModel(id: 'm6', name: 'Lamb Shoulder (roasted)', emoji: '🍖', servingSize: '100g', calories: 280, protein: 24, carbs: 0, fat: 20, fiber: 0.0, gymScore: 7.0, tags: ['protein', 'meat', 'lamb', 'لحم خروف', 'لحم ضأن']),
    FoodModel(id: 'm7', name: 'Beef Steak (Sirloin)', emoji: '🥩', servingSize: '100g', calories: 244, protein: 27, carbs: 0, fat: 14, fiber: 0.0, gymScore: 8.5, tags: ['protein', 'meat', 'steak', 'ستيك']),

    // ==========================================
    // 🐟 SEAFOOD (المأكولات البحرية)
    // ==========================================
    FoodModel(id: 's1', name: 'Canned Tuna (in water, drained)', emoji: '🐟', servingSize: '1 can (165g)', calories: 145, protein: 32, carbs: 0, fat: 1.5, fiber: 0.0, gymScore: 9.6, tags: ['protein', 'fish', 'seafood', 'lean', 'تونا', 'تونة']),
    FoodModel(id: 's2', name: 'Salmon (Atlantic, baked)', emoji: '🍣', servingSize: '100g', calories: 206, protein: 22, carbs: 0, fat: 12.3, fiber: 0.0, gymScore: 9.4, tags: ['protein', 'fat', 'fish', 'seafood', 'omega3', 'سلمون']),
    FoodModel(id: 's3', name: 'Shrimp (cooked)', emoji: '🍤', servingSize: '100g', calories: 99, protein: 24, carbs: 0.2, fat: 0.3, fiber: 0.0, gymScore: 9.5, tags: ['protein', 'seafood', 'lean', 'روبيان', 'جمبري']),
    FoodModel(id: 's4', name: 'Tilapia (cooked)', emoji: '🐟', servingSize: '100g', calories: 128, protein: 26, carbs: 0, fat: 2.7, fiber: 0.0, gymScore: 9.2, tags: ['protein', 'fish', 'lean', 'بلطي', 'سمك']),
    FoodModel(id: 's5', name: 'Sardines (canned in oil)', emoji: '🥫', servingSize: '100g', calories: 208, protein: 24.6, carbs: 0, fat: 11.5, fiber: 0.0, gymScore: 8.8, tags: ['protein', 'fat', 'fish', 'omega3', 'سردين']),

    // ==========================================
    // 🥚 EGGS & DAIRY (البيض ومنتجات الألبان)
    // ==========================================
    FoodModel(id: 'd1', name: 'Whole Eggs', emoji: '🥚', servingSize: '2 large (100g)', calories: 143, protein: 12.6, carbs: 0.7, fat: 9.5, fiber: 0.0, gymScore: 9.5, tags: ['protein', 'eggs', 'breakfast', 'بيض']),
    FoodModel(id: 'd2', name: 'Egg Whites', emoji: '🍳', servingSize: '100g (approx 3 whites)', calories: 52, protein: 10.9, carbs: 0.7, fat: 0.2, fiber: 0.0, gymScore: 9.8, tags: ['protein', 'eggs', 'lean', 'بياض البيض']),
    FoodModel(id: 'd3', name: 'Greek Yogurt (0% fat)', emoji: '🥣', servingSize: '150g', calories: 88, protein: 15, carbs: 5.4, fat: 0, fiber: 0.0, gymScore: 9.5, tags: ['protein', 'dairy', 'snack', 'زبادي', 'لبن يوناني']),
    FoodModel(id: 'd4', name: 'Cottage Cheese (1% fat)', emoji: '🧀', servingSize: '100g', calories: 72, protein: 12.4, carbs: 2.7, fat: 1, fiber: 0.0, gymScore: 9.4, tags: ['protein', 'dairy', 'casein', 'جبنة قريش']),
    FoodModel(id: 'd5', name: 'Milk (Whole, 3.25%)', emoji: '🥛', servingSize: '1 cup (240ml)', calories: 149, protein: 8, carbs: 12, fat: 8, fiber: 0.0, gymScore: 8.5, tags: ['protein', 'dairy', 'drink', 'حليب كامل الدسم']),
    FoodModel(id: 'd6', name: 'Milk (Skim, 0%)', emoji: '🥛', servingSize: '1 cup (240ml)', calories: 83, protein: 8.3, carbs: 12, fat: 0.2, fiber: 0.0, gymScore: 9.0, tags: ['protein', 'dairy', 'lean', 'حليب خالي الدسم']),
    FoodModel(id: 'd7', name: 'Cheddar Cheese', emoji: '🧀', servingSize: '1 slice (28g)', calories: 113, protein: 7, carbs: 0.4, fat: 9.3, fiber: 0.0, gymScore: 7.5, tags: ['fat', 'protein', 'dairy', 'جبنة شيدر']),
    FoodModel(id: 'd8', name: 'Mozzarella (part-skim)', emoji: '🧀', servingSize: '1 oz (28g)', calories: 85, protein: 7, carbs: 0.8, fat: 6, fiber: 0.0, gymScore: 8.0, tags: ['protein', 'dairy', 'موزاريلا']),
    FoodModel(id: 'd9', name: 'Labneh (Full fat)', emoji: '🥣', servingSize: '100g', calories: 120, protein: 8, carbs: 4, fat: 8, fiber: 0.0, gymScore: 8.5, tags: ['arabic', 'protein', 'fat', 'dairy', 'لبنة']),

    // ==========================================
    // 🌾 CARBS, GRAINS & BREADS (النشويات والحبوب)
    // ==========================================
    FoodModel(id: 'g1', name: 'Rolled Oats (dry)', emoji: '🌾', servingSize: '80g', calories: 303, protein: 10.5, carbs: 53.6, fat: 5.2, fiber: 0.0, gymScore: 9.4, tags: ['carbs', 'breakfast', 'pre-workout', 'شوفان']),
    FoodModel(id: 'g2', name: 'White Rice (cooked)', emoji: '🍚', servingSize: '200g', calories: 260, protein: 5.3, carbs: 57, fat: 0.6, fiber: 0.0, gymScore: 8.8, tags: ['carbs', 'post-workout', 'رز', 'ارز ابيض']),
    FoodModel(id: 'g3', name: 'Brown Rice (cooked)', emoji: '🍛', servingSize: '200g', calories: 224, protein: 4.5, carbs: 47, fat: 1.6, fiber: 0.0, gymScore: 8.9, tags: ['carbs', 'fiber', 'رز اسمر', 'ارز بني']),
    FoodModel(id: 'g4', name: 'Quinoa (cooked)', emoji: '🥗', servingSize: '150g', calories: 180, protein: 6.6, carbs: 32, fat: 2.8, fiber: 0.0, gymScore: 9.6, tags: ['carbs', 'protein', 'vegan', 'كينوا']),
    FoodModel(id: 'g5', name: 'Sweet Potato (baked)', emoji: '🍠', servingSize: '150g', calories: 135, protein: 3, carbs: 31, fat: 0.2, fiber: 0.0, gymScore: 9.5, tags: ['carbs', 'fiber', 'بطاطا حلوة']),
    FoodModel(id: 'g6', name: 'White Potato (boiled)', emoji: '🥔', servingSize: '150g', calories: 130, protein: 2.8, carbs: 30, fat: 0.2, fiber: 0.0, gymScore: 9.0, tags: ['carbs', 'بطاطس', 'بطاطا']),
    FoodModel(id: 'g7', name: 'Whole Wheat Pasta (cooked)', emoji: '🍝', servingSize: '150g', calories: 200, protein: 8, carbs: 42, fat: 1, fiber: 0.0, gymScore: 8.5, tags: ['carbs', 'مكرونة', 'معكرونة']),
    FoodModel(id: 'g8', name: 'White Pasta (cooked)', emoji: '🍝', servingSize: '150g', calories: 237, protein: 8.7, carbs: 46.5, fat: 0.9, fiber: 0.0, gymScore: 7.5, tags: ['carbs', 'مكرونة بيضاء']),
    FoodModel(id: 'g9', name: 'Whole Wheat Bread', emoji: '🍞', servingSize: '2 slices (56g)', calories: 138, protein: 7.2, carbs: 24, fat: 2, fiber: 0.0, gymScore: 8.0, tags: ['carbs', 'bread', 'خبز أسمر']),
    FoodModel(id: 'g10', name: 'White Bread', emoji: '🍞', servingSize: '2 slices (56g)', calories: 150, protein: 5.4, carbs: 28, fat: 1.8, fiber: 0.0, gymScore: 5.0, tags: ['carbs', 'bread', 'خبز أبيض']),
    FoodModel(id: 'g11', name: 'Arabic Pita Bread (White)', emoji: '🫓', servingSize: '1 medium (60g)', calories: 165, protein: 5.5, carbs: 33, fat: 0.7, fiber: 0.0, gymScore: 6.5, tags: ['arabic', 'carbs', 'bread', 'خبز عربي', 'كماج']),
    FoodModel(id: 'g12', name: 'Bulgur (cooked)', emoji: '🍚', servingSize: '150g', calories: 124, protein: 4.6, carbs: 28, fat: 0.4, fiber: 0.0, gymScore: 9.0, tags: ['arabic', 'carbs', 'fiber', 'برغل']),
    FoodModel(id: 'g13', name: 'Couscous (cooked)', emoji: '🍲', servingSize: '150g', calories: 168, protein: 5.7, carbs: 34.5, fat: 0.2, fiber: 0.0, gymScore: 8.5, tags: ['carbs', 'كسكس']),

    // ==========================================
    // 🥑 NUTS, SEEDS & HEALTHY FATS (الدهون الصحية والمكسرات)
    // ==========================================
    FoodModel(id: 'f1', name: 'Almonds', emoji: '🥜', servingSize: '30g', calories: 173, protein: 6, carbs: 6, fat: 15, fiber: 0.0, gymScore: 9.2, tags: ['fat', 'nuts', 'snack', 'لوز']),
    FoodModel(id: 'f2', name: 'Peanut Butter (100% natural)', emoji: '🥜', servingSize: '2 tbsp (32g)', calories: 190, protein: 8, carbs: 6, fat: 16, fiber: 0.0, gymScore: 8.8, tags: ['fat', 'nuts', 'spread', 'زبدة فول سوداني']),
    FoodModel(id: 'f3', name: 'Avocado', emoji: '🥑', servingSize: '100g', calories: 160, protein: 2, carbs: 8.5, fat: 14.7, fiber: 0.0, gymScore: 9.4, tags: ['fat', 'fruit', 'افوكادو']),
    FoodModel(id: 'f4', name: 'Olive Oil (Extra Virgin)', emoji: '🫒', servingSize: '1 tbsp (14g)', calories: 119, protein: 0, carbs: 0, fat: 13.5, fiber: 0.0, gymScore: 9.5, tags: ['fat', 'oil', 'زيت زيتون']),
    FoodModel(id: 'f5', name: 'Walnuts', emoji: '🧠', servingSize: '30g', calories: 196, protein: 4.3, carbs: 4.1, fat: 19.6, fiber: 0.0, gymScore: 9.3, tags: ['fat', 'nuts', 'omega3', 'جوز', 'عين جمل']),
    FoodModel(id: 'f6', name: 'Chia Seeds', emoji: '🌱', servingSize: '2 tbsp (28g)', calories: 138, protein: 4.7, carbs: 12, fat: 8.7, fiber: 0.0, gymScore: 9.8, tags: ['fat', 'fiber', 'omega3', 'بذور الشيا']),
    FoodModel(id: 'f7', name: 'Flaxseeds (ground)', emoji: '🌾', servingSize: '1 tbsp (7g)', calories: 37, protein: 1.3, carbs: 2, fat: 3, fiber: 0.0, gymScore: 9.7, tags: ['fat', 'fiber', 'omega3', 'بذور الكتان']),
    FoodModel(id: 'f8', name: 'Pistachios', emoji: '🥜', servingSize: '30g', calories: 168, protein: 6, carbs: 8, fat: 13, fiber: 0.0, gymScore: 8.9, tags: ['fat', 'nuts', 'فستق']),
    FoodModel(id: 'f9', name: 'Cashews', emoji: '🥜', servingSize: '30g', calories: 166, protein: 5, carbs: 9, fat: 13.8, fiber: 0.0, gymScore: 8.6, tags: ['fat', 'nuts', 'كاجو']),
    FoodModel(id: 'f10', name: 'Tahini (Sesame paste)', emoji: '🍯', servingSize: '1 tbsp (15g)', calories: 89, protein: 2.5, carbs: 3, fat: 8, fiber: 0.0, gymScore: 8.2, tags: ['arabic', 'fat', 'طحينة', 'طحينية']),
    FoodModel(id: 'f11', name: 'Butter', emoji: '🧈', servingSize: '1 tbsp (14g)', calories: 102, protein: 0.1, carbs: 0.1, fat: 11.5, fiber: 0.0, gymScore: 6.0, tags: ['fat', 'dairy', 'زبدة']),

    // ==========================================
    // 🥦 VEGETABLES & LEGUMES (الخضار والبقوليات)
    // ==========================================
    FoodModel(id: 'v1', name: 'Broccoli (steamed)', emoji: '🥦', servingSize: '100g', calories: 35, protein: 2.4, carbs: 7.2, fat: 0.4, fiber: 0.0, gymScore: 9.8, tags: ['vegetable', 'fiber', 'micronutrients', 'بروكلي']),
    FoodModel(id: 'v2', name: 'Spinach (raw)', emoji: '🥬', servingSize: '100g', calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fiber: 0.0, gymScore: 9.9, tags: ['vegetable', 'fiber', 'iron', 'سبانخ']),
    FoodModel(id: 'v3', name: 'Mixed Salad', emoji: '🥗', servingSize: '100g', calories: 20, protein: 1.5, carbs: 3.5, fat: 0.2, fiber: 0.0, gymScore: 9.5, tags: ['vegetable', 'fiber', 'سلطة']),
    FoodModel(id: 'v4', name: 'Cucumber', emoji: '🥒', servingSize: '100g', calories: 15, protein: 0.7, carbs: 3.6, fat: 0.1, fiber: 0.0, gymScore: 8.8, tags: ['vegetable', 'water', 'خيار']),
    FoodModel(id: 'v5', name: 'Tomato', emoji: '🍅', servingSize: '100g', calories: 18, protein: 0.9, carbs: 3.9, fat: 0.2, fiber: 0.0, gymScore: 9.0, tags: ['vegetable', 'طماطم', 'بندورة']),
    FoodModel(id: 'v6', name: 'Bell Pepper (Red)', emoji: '🫑', servingSize: '100g', calories: 31, protein: 1, carbs: 6, fat: 0.3, fiber: 0.0, gymScore: 9.3, tags: ['vegetable', 'vitamin c', 'فلفل رومي', 'فليفلة']),
    FoodModel(id: 'v7', name: 'Carrots (raw)', emoji: '🥕', servingSize: '100g', calories: 41, protein: 0.9, carbs: 9.6, fat: 0.2, fiber: 0.0, gymScore: 9.1, tags: ['vegetable', 'vitamin a', 'جزر']),
    FoodModel(id: 'v8', name: 'Asparagus (cooked)', emoji: '🎋', servingSize: '100g', calories: 22, protein: 2.4, carbs: 4.1, fat: 0.2, fiber: 0.0, gymScore: 9.6, tags: ['vegetable', 'هليون']),
    FoodModel(id: 'v9', name: 'Green Beans (cooked)', emoji: '🫛', servingSize: '100g', calories: 35, protein: 1.9, carbs: 7.9, fat: 0.3, fiber: 0.0, gymScore: 9.2, tags: ['vegetable', 'فاصوليا خضراء']),
    FoodModel(id: 'v10', name: 'Lentils (cooked)', emoji: '🍲', servingSize: '150g', calories: 174, protein: 13.5, carbs: 30, fat: 0.6, fiber: 0.0, gymScore: 9.5, tags: ['carbs', 'protein', 'vegan', 'fiber', 'عدس']),
    FoodModel(id: 'v11', name: 'Chickpeas (cooked)', emoji: '🥙', servingSize: '150g', calories: 246, protein: 13.3, carbs: 40.5, fat: 3.8, fiber: 0.0, gymScore: 9.3, tags: ['carbs', 'protein', 'vegan', 'fiber', 'حمص حب']),
    FoodModel(id: 'v12', name: 'Edamame (cooked)', emoji: '🫛', servingSize: '100g', calories: 121, protein: 11.9, carbs: 8.9, fat: 5.2, fiber: 0.0, gymScore: 9.6, tags: ['protein', 'vegan', 'soy', 'ادامامي']),

    // ==========================================
    // 🍎 FRUITS (الفواكه)
    // ==========================================
    FoodModel(id: 'fr1', name: 'Banana', emoji: '🍌', servingSize: '1 medium (118g)', calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 0.0, gymScore: 9.1, tags: ['carbs', 'fruit', 'pre-workout', 'موز', 'موزة']),
    FoodModel(id: 'fr2', name: 'Apple', emoji: '🍎', servingSize: '1 medium (182g)', calories: 95, protein: 0.5, carbs: 25, fat: 0.3, fiber: 0.0, gymScore: 8.8, tags: ['carbs', 'fruit', 'تفاح', 'تفاحة']),
    FoodModel(id: 'fr3', name: 'Dates (Medjool)', emoji: '🌴', servingSize: '2 dates (48g)', calories: 133, protein: 0.9, carbs: 36, fat: 0.1, fiber: 0.0, gymScore: 8.9, tags: ['carbs', 'fruit', 'sugar', 'pre-workout', 'تمر', 'تمور']),
    FoodModel(id: 'fr4', name: 'Watermelon', emoji: '🍉', servingSize: '200g', calories: 60, protein: 1.2, carbs: 15, fat: 0.3, fiber: 0.0, gymScore: 8.5, tags: ['carbs', 'fruit', 'بطيخ']),
    FoodModel(id: 'fr5', name: 'Strawberries', emoji: '🍓', servingSize: '100g', calories: 32, protein: 0.7, carbs: 7.7, fat: 0.3, fiber: 0.0, gymScore: 9.5, tags: ['carbs', 'fruit', 'antioxidants', 'فراولة']),
    FoodModel(id: 'fr6', name: 'Orange', emoji: '🍊', servingSize: '1 medium (131g)', calories: 62, protein: 1.2, carbs: 15.4, fat: 0.2, fiber: 0.0, gymScore: 8.9, tags: ['carbs', 'fruit', 'vitamin c', 'برتقال']),
    FoodModel(id: 'fr7', name: 'Blueberries', emoji: '🫐', servingSize: '100g', calories: 57, protein: 0.7, carbs: 14.5, fat: 0.3, fiber: 0.0, gymScore: 9.8, tags: ['carbs', 'fruit', 'antioxidants', 'توت أزرق']),
    FoodModel(id: 'fr8', name: 'Pineapple', emoji: '🍍', servingSize: '100g', calories: 50, protein: 0.5, carbs: 13.1, fat: 0.1, fiber: 0.0, gymScore: 8.6, tags: ['carbs', 'fruit', 'أناناس']),
    FoodModel(id: 'fr9', name: 'Mango', emoji: '🥭', servingSize: '100g', calories: 60, protein: 0.8, carbs: 15, fat: 0.4, fiber: 0.0, gymScore: 8.4, tags: ['carbs', 'fruit', 'مانجو']),
    FoodModel(id: 'fr10', name: 'Grapes', emoji: '🍇', servingSize: '100g', calories: 69, protein: 0.7, carbs: 18, fat: 0.2, fiber: 0.0, gymScore: 8.2, tags: ['carbs', 'fruit', 'عنب']),

    // ==========================================
    // 💊 SUPPLEMENTS (المكملات الغذائية الرياضية)
    // ==========================================
    FoodModel(id: 'sup1', name: 'Whey Protein Isolate', emoji: '🥛', servingSize: '1 scoop (30g)', calories: 110, protein: 25, carbs: 1, fat: 0.5, fiber: 0.0, gymScore: 9.9, tags: ['protein', 'supplement', 'post-workout', 'واي بروتين ايزوليت']),
    FoodModel(id: 'sup2', name: 'Whey Protein Concentrate', emoji: '🥛', servingSize: '1 scoop (30g)', calories: 120, protein: 24, carbs: 3, fat: 1.5, fiber: 0.0, gymScore: 9.5, tags: ['protein', 'supplement', 'واي بروتين كونسنتريت']),
    FoodModel(id: 'sup3', name: 'Casein Protein', emoji: '🥛', servingSize: '1 scoop (30g)', calories: 115, protein: 24, carbs: 3, fat: 1, fiber: 0.0, gymScore: 9.6, tags: ['protein', 'supplement', 'night', 'كازين']),
    FoodModel(id: 'sup4', name: 'Mass Gainer', emoji: '🛢️', servingSize: '1 scoop (165g)', calories: 650, protein: 25, carbs: 125, fat: 5, fiber: 0.0, gymScore: 7.0, tags: ['carbs', 'protein', 'supplement', 'bulking', 'ماس جينر']),
    FoodModel(id: 'sup5', name: 'Creatine Monohydrate', emoji: '🥄', servingSize: '1 scoop (5g)', calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0.0, gymScore: 10.0, tags: ['supplement', 'strength', 'كرياتين']),
    FoodModel(id: 'sup6', name: 'Pre-Workout', emoji: '⚡', servingSize: '1 scoop (10g)', calories: 5, protein: 0, carbs: 1, fat: 0, fiber: 0.0, gymScore: 8.5, tags: ['supplement', 'energy', 'caffeine', 'بري وورك اوت']),
    FoodModel(id: 'sup7', name: 'BCAA', emoji: '🥤', servingSize: '1 scoop (7g)', calories: 5, protein: 1, carbs: 0, fat: 0, fiber: 0.0, gymScore: 5.0, tags: ['supplement', 'recovery', 'بي سي ايه ايه']),

    // ==========================================
    // 🥘 ARABIC CUISINE & TRADITIONAL DISHES (المطبخ العربي)
    // ==========================================
    FoodModel(id: 'ar1', name: 'Hummus (dip)', emoji: '🧆', servingSize: '100g', calories: 166, protein: 7.9, carbs: 14.3, fat: 9.6, fiber: 0.0, gymScore: 8.5, tags: ['arabic', 'fat', 'carbs', 'dip', 'حمص بالطحينة']),
    FoodModel(id: 'ar2', name: 'Falafel (fried)', emoji: '🧆', servingSize: '3 pieces (50g)', calories: 166, protein: 6.5, carbs: 16, fat: 9, fiber: 0.0, gymScore: 6.0, tags: ['arabic', 'carbs', 'fat', 'فلافل']),
    FoodModel(id: 'ar3', name: 'Foul Medames', emoji: '🥣', servingSize: '150g', calories: 165, protein: 10, carbs: 28, fat: 2.5, fiber: 0.0, gymScore: 8.8, tags: ['arabic', 'protein', 'carbs', 'fiber', 'فول مدمس']),
    FoodModel(id: 'ar4', name: 'Shawarma (Chicken only)', emoji: '🌯', servingSize: '100g', calories: 180, protein: 28, carbs: 2, fat: 6, fiber: 0.0, gymScore: 8.0, tags: ['arabic', 'protein', 'شاورما دجاج']),
    FoodModel(id: 'ar5', name: 'Shawarma (Beef only)', emoji: '🌯', servingSize: '100g', calories: 230, protein: 25, carbs: 3, fat: 14, fiber: 0.0, gymScore: 7.0, tags: ['arabic', 'protein', 'شاورما لحم']),
    FoodModel(id: 'ar6', name: 'Tabbouleh', emoji: '🥗', servingSize: '100g', calories: 85, protein: 2, carbs: 9, fat: 5, fiber: 0.0, gymScore: 9.2, tags: ['arabic', 'salad', 'vegetable', 'تبولة']),
    FoodModel(id: 'ar7', name: 'Fattoush', emoji: '🥗', servingSize: '100g', calories: 75, protein: 1.5, carbs: 8, fat: 4.5, fiber: 0.0, gymScore: 8.9, tags: ['arabic', 'salad', 'vegetable', 'فتوش']),
    FoodModel(id: 'ar8', name: 'Mansaf (Meat, Rice, Jameed)', emoji: '🥘', servingSize: '300g', calories: 650, protein: 35, carbs: 45, fat: 35, fiber: 0.0, gymScore: 6.5, tags: ['arabic', 'heavy', 'cheat', 'منسف']),
    FoodModel(id: 'ar9', name: 'Kabsa (Chicken & Rice)', emoji: '🥘', servingSize: '300g', calories: 500, protein: 30, carbs: 65, fat: 12, fiber: 0.0, gymScore: 7.5, tags: ['arabic', 'heavy', 'كبسة']),
    FoodModel(id: 'ar10', name: 'Mutabal / Baba Ghanoush', emoji: '🍆', servingSize: '100g', calories: 110, protein: 2, carbs: 8, fat: 8, fiber: 0.0, gymScore: 8.5, tags: ['arabic', 'dip', 'متبل', 'بابا غنوج']),
    FoodModel(id: 'ar11', name: 'Mujadara (Lentils & Rice)', emoji: '🍲', servingSize: '200g', calories: 290, protein: 11, carbs: 50, fat: 5, fiber: 0.0, gymScore: 8.5, tags: ['arabic', 'vegan', 'carbs', 'مجدّرة', 'مجدرة']),
    FoodModel(id: 'ar12', name: 'Shish Taouk (Grilled Chicken Skewers)', emoji: '🍢', servingSize: '150g', calories: 210, protein: 35, carbs: 4, fat: 5, fiber: 0.0, gymScore: 9.5, tags: ['arabic', 'protein', 'lean', 'شيش طاووق']),
    FoodModel(id: 'ar13', name: 'Kofta / Kebab (Beef/Lamb)', emoji: '🍢', servingSize: '150g', calories: 350, protein: 25, carbs: 5, fat: 25, fiber: 0.0, gymScore: 6.5, tags: ['arabic', 'protein', 'كفتة', 'كباب']),

    // ==========================================
    // 🍔 CHEAT MEALS, FAST FOOD & SWEETS (الوجبات السريعة والحلويات)
    // ==========================================
    FoodModel(id: 'w1', name: 'Glazed Donut', emoji: '🍩', servingSize: '1 piece (60g)', calories: 260, protein: 3, carbs: 31, fat: 14, fiber: 0.0, gymScore: 1.2, tags: ['cheat', 'sugar', 'junk', 'دونات']),
    FoodModel(id: 'w2', name: 'Pepperoni Pizza', emoji: '🍕', servingSize: '1 slice (100g)', calories: 298, protein: 12, carbs: 32, fat: 13, fiber: 0.0, gymScore: 3.5, tags: ['cheat', 'junk', 'بيتزا']),
    FoodModel(id: 'w3', name: 'Potato Chips', emoji: '🍟', servingSize: '1 small bag (28g)', calories: 152, protein: 2, carbs: 15, fat: 10, fiber: 0.0, gymScore: 2.0, tags: ['cheat', 'snack', 'junk', 'شيبس', 'بطاطس مقلية']),
    FoodModel(id: 'w4', name: 'Cola', emoji: '🥤', servingSize: '1 can (330ml)', calories: 139, protein: 0, carbs: 35, fat: 0, fiber: 0.0, gymScore: 1.0, tags: ['cheat', 'drink', 'sugar', 'كولا', 'مشروب غازي']),
    FoodModel(id: 'w5', name: 'Chocolate Bar (Milk)', emoji: '🍫', servingSize: '1 bar (45g)', calories: 240, protein: 3, carbs: 27, fat: 13, fiber: 0.0, gymScore: 1.5, tags: ['cheat', 'sugar', 'snack', 'شوكولاتة']),
    FoodModel(id: 'w6', name: 'Ice Cream (Vanilla)', emoji: '🍦', servingSize: '1/2 cup (66g)', calories: 137, protein: 2.3, carbs: 16, fat: 7, fiber: 0.0, gymScore: 2.5, tags: ['cheat', 'sugar', 'dessert', 'ايس كريم', 'بوظة']),
    FoodModel(id: 'w7', name: 'Cheeseburger (Fast Food)', emoji: '🍔', servingSize: '1 burger (150g)', calories: 420, protein: 20, carbs: 35, fat: 22, fiber: 0.0, gymScore: 3.0, tags: ['cheat', 'junk', 'برجر', 'همبرجر']),
    FoodModel(id: 'w8', name: 'Fried Chicken (Breast)', emoji: '🍗', servingSize: '1 piece (160g)', calories: 380, protein: 32, carbs: 15, fat: 21, fiber: 0.0, gymScore: 4.5, tags: ['cheat', 'junk', 'بروستد', 'دجاج مقلي']),
    FoodModel(id: 'w9', name: 'Kunafa', emoji: '🥮', servingSize: '1 piece (100g)', calories: 350, protein: 6, carbs: 45, fat: 15, fiber: 0.0, gymScore: 1.5, tags: ['arabic', 'cheat', 'sugar', 'كنافة']),
    FoodModel(id: 'w10', name: 'Baklava', emoji: '🍯', servingSize: '1 piece (50g)', calories: 210, protein: 3, carbs: 25, fat: 12, fiber: 0.0, gymScore: 1.5, tags: ['arabic', 'cheat', 'sugar', 'بقلاوة']),
  ];
}
