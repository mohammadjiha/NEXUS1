import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../core/services/remote_config_service.dart';
import '../../smart_workout/services/exercise_substitution_service.dart';
import '../domain/models/ai_coach_plan.dart';
import '../domain/models/ai_coach_report.dart';

final aiCoachServiceProvider = Provider<AICoachService>((ref) {
  final remoteConfig = ref.watch(remoteConfigProvider);
  return AICoachService(remoteConfig);
});

class AICoachService {
  final RemoteConfigService _remoteConfig;

  AICoachService(this._remoteConfig);

  Future<AICoachReport?> analyzeVideo(Uint8List videoBytes, String mimeType, {String? exerciseName, String? experienceLevel}) async {
    final apiKey = _remoteConfig.getString('gemini_api_key');
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key not found. Please contact support.');
    }

    final modelName = _remoteConfig.getString('gemini_model');
    final model = GenerativeModel(
      model: modelName.isNotEmpty ? modelName : 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    String prompt = '''
  You are an elite, highly critical AI personal trainer. Analyze the attached video (or image) of the user performing an exercise.
  Wait, the user's experience level is: ${experienceLevel ?? 'Unknown'}. Keep this in mind when providing feedback and recommending alternatives.
  If they are a Beginner, recommend simpler, safer variations (e.g. machines or bodyweight).
  If they are Advanced, recommend challenging free-weight alternatives.

  You MUST provide a 100% realistic, dynamic, and brutally honest biomechanical analysis based ONLY on what you actually see in the video. Do NOT use generic or static feedback.
  Count the total number of repetitions you see ("totalReps") and how many of those were performed with perfect form ("correctReps").

  Provide a JSON report following EXACTLY this structure:
  {
    "formScore": 85,
    "totalReps": 8,
    "correctReps": 6,
    "exerciseName": "Barbell Squat",
    "coachFeedback": "Detailed, specific paragraph about their biomechanics in this exact video.",
    "issues": [
      {
        "title": "Knees caving in",
        "severity": "Critical",
        "description": "Your knees are buckling inwards on the way up during reps 2 and 4.",
        "fix": "Push your knees out actively against an imaginary band.",
        "reps": [2, 4]
      }
    ],
  "goodPoints": [
    "Depth was excellent on the first 3 reps",
    "Bar path was perfectly vertical"
  ],
  "recommendedAlternative": "Optional: Only include if formScore < 70. Must be EXACTLY one of the provided database alternatives."
}

  IMPORTANT: ALWAYS return a valid JSON in the exact format above. Do not return any error messages outside of the JSON. 
  If you cannot clearly see an exercise being performed (for example, if the user is just sitting, talking, or the camera is pointing at nothing), DO NOT invent an exercise. Instead:
  - Set "exerciseName" to "No Exercise Detected"
  - Set "formScore" to 0
  - Set "totalReps" to 0
  - Set "correctReps" to 0
  - Set "coachFeedback" to "I couldn't detect any exercise in the video. Please record yourself performing a clear movement so I can analyze it."
  - Leave "issues" and "goodPoints" empty.
  ''';

    if (exerciseName != null && exerciseName.isNotEmpty && exerciseName != 'Standing') {
      final info = ExerciseSubstitutionService.getAlternatives(exerciseName);
      if (info != null && info.alternatives.isNotEmpty) {
        final altNames = info.alternatives.map((a) => a.name).join(', ');
        prompt += '\n\nAvailable alternative exercises in our database for ${info.targetPortion}: [$altNames]. If the user\'s formScore is less than 70, you MUST select one of these EXACT alternatives that best fits their experience level ($experienceLevel) and include it in the "recommendedAlternative" field. DO NOT invent or suggest any other exercise outside this list.';
      } else {
        prompt += '\n\nWe do not have specific alternatives for $exerciseName. You MUST set "recommendedAlternative" to null. DO NOT invent or suggest ANY alternative exercise.';
      }
    } else {
        prompt += '\n\nYou MUST set "recommendedAlternative" to null. DO NOT invent or suggest ANY alternative exercise.';
    }

    try {
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, videoBytes),
        ])
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) return null;

      // Extract JSON if it's wrapped in markdown
      String jsonStr = text;
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final jsonMap = jsonDecode(jsonStr);
      final report = AICoachReport.fromJson(jsonMap);
      
      if (report.exerciseName == 'No Exercise Detected') {
        throw Exception('No Exercise Detected');
      }

      return report;
    } catch (e) {
      debugPrint('Error parsing Gemini response: $e');
      rethrow;
    }
  }

  ChatSession startChatSession(String userContext) {
    final apiKey = _remoteConfig.getString('gemini_api_key');
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key not found. Please contact support.');
    }

    final modelName = _remoteConfig.getString('gemini_model');
    final model = GenerativeModel(
      model: modelName.isNotEmpty ? modelName : 'gemini-1.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system('''
You are NEXUS AI, a friendly, highly knowledgeable, and human-like fitness and nutrition coach.
You converse naturally like a real human trainer. If the user asks about ANY detail related to the gym, exercises, anatomy, diet, or fitness science, you explain it clearly, patiently, and conversationally.

CRITICAL RULE: If the user asks you about ANY topic that is NOT directly related to fitness, gym, anatomy, sports, or nutrition (for example: physics theories like the butterfly effect, history, politics, coding, math, general trivia), you MUST absolutely refuse to answer it. 
DO NOT explain the unrelated topic at all. DO NOT try to be helpful about the unrelated topic. 
Immediately and politely apologize, state that you are strictly a fitness and nutrition coach, and ask how you can help them with their health goals today.

Be encouraging, empathetic, and use emojis naturally like a human texting.

Here is the user's current data:
$userContext
'''),
    );

    return model.startChat();
  }

  Future<AICoachPlan?> generateNutritionPlan(Map<String, dynamic> userData) async {
    final apiKey = _remoteConfig.getString('gemini_api_key');
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key not found. Please contact support.');
    }

    final modelName = _remoteConfig.getString('gemini_model');
    final model = GenerativeModel(
      model: modelName.isNotEmpty ? modelName : 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    String prompt = '''
  You are an elite, highly critical AI personal trainer and nutritionist. Create a personalized daily nutrition and workout plan based on the following detailed user data:
  User Data:
  Age: ${userData['age']} years
  Gender: ${userData['gender']}
  Weight: ${userData['weight']} kg
  Height: ${userData['height']} cm
  Body Fat: ${userData['bodyFat']}%
  Muscle Mass: ${userData['muscleMass']} kg
  Fat Free Mass: ${userData['fatFreeMass']} kg
  Body Water: ${userData['bodyWater']} L
  BMR: ${userData['bmr']} kcal
  Metabolic Age: ${userData['metabolicAge']} years
  Goal: ${userData['goal']}
  Fitness Level: ${userData['fitnessLevel']}
  Training Mode: ${userData['trainingMode']}

  CRITICAL INSTRUCTION: You MUST generate a FULL DAY of eating. This means you must provide at least 4 to 6 meals (e.g., Breakfast, Snack, Lunch, Pre-Workout, Post-Workout, Dinner). DO NOT just provide one meal. Each meal must have a specific time (e.g., "08:00 AM", "01:30 PM", "08:00 PM"). Generate UNIQUE and delicious food combinations every time.
  FOOD SELECTION: All foods MUST consist of simple, everyday, affordable ingredients commonly found in a standard Arab/Middle-Eastern household (e.g., eggs, rice, chicken breast, lentils, foul, hummus, oats, standard local vegetables/fruits). DO NOT suggest exotic, expensive, or hard-to-find ingredients like salmon, broccoli, or rare seeds.

  Provide a JSON report following EXACTLY this structure:
  {
    "summary": "Today is Push Day — I increased carbs to 320g for energy and kept protein at 150g to protect muscle. Deficit: −250 kcal for lean bulk. 💪",
    "totalCalories": 2700,
    "caloriesBurned": 480,
    "calorieDeficit": -250,
    "waterLiters": 3.5,
    "workoutFocus": "Push",
    "macros": {
      "protein": {"target": 150, "current": 0},
      "carbs": {"target": 320, "current": 0},
      "fat": {"target": 70, "current": 0}
    },
    "meals": [
      {
        "name": "Breakfast",
        "icon": "🌅",
        "time": "08:00 AM",
        "totalCalories": 450,
        "protein": 35,
        "carbs": 60,
        "fat": 10,
        "foods": [
          {"emoji": "🥣", "name": "Oats with Berries", "amount": "80g", "protein": 12, "carbs": 54, "fat": 6, "calories": 302}
        ]
      },
      // ADD AT LEAST 3 TO 5 MORE MEALS HERE (Lunch, Dinner, Snacks, etc.)
    ]
  }

  IMPORTANT: ALWAYS return a valid JSON in the exact format above. Ensure the meals add up to the total target calories. Set reasonable meal times spaced throughout the day based on standard eating habits. Be extremely creative with the foods and emojis!
  ''';

    try {
      final response = await model.generateContent([
        Content.multi([TextPart(prompt)]),
      ]);
      final text = response.text;
      if (text == null) return null;

      final cleanedText = text.replaceAll('```json', '').replaceAll('```', '').trim();
      final decoded = jsonDecode(cleanedText) as Map<String, dynamic>;
      
      return AICoachPlan.fromJson(decoded);
    } catch (e) {
      throw Exception('Error generating plan: $e');
    }
  }
}
