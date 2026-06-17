import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/services/remote_config_service.dart';

final aiFoodServiceProvider = Provider<AIFoodService>((ref) {
  final remoteConfig = ref.watch(remoteConfigProvider);
  return AIFoodService(remoteConfig);
});

class AIFoodService {
  final RemoteConfigService _remoteConfig;

  AIFoodService(this._remoteConfig);

  Future<Map<String, dynamic>?> analyzeFoodImage(Uint8List imageBytes) async {
    final apiKey = _remoteConfig.getString('gemini_api_key');
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key not found. Please contact support.');
    }

    final modelName = _remoteConfig.getString('gemini_model');
    // For vision, if gemini-2.5-flash is not available, we fallback to gemini-1.5-flash
    final model = GenerativeModel(
      model: modelName.isNotEmpty ? modelName : 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    const prompt = '''
You are an expert nutritionist. Analyze this image of food.
Identify the food and estimate its nutritional values.
If there are reference objects in the image, use them to estimate the total weight in grams.
Provide the output strictly in the following JSON format without markdown wrapping:
{
  "food_name": "Name of the food in English",
  "estimated_weight_g": 250,
  "per_100g": {
    "calories": 150,
    "protein_g": 10.5,
    "carbs_g": 20.0,
    "fat_g": 5.0
  },
  "total_estimated": {
    "calories": 375,
    "protein_g": 26.25,
    "carbs_g": 50.0,
    "fat_g": 12.5
  }
}
If it is not food, return an error JSON: {"error": "No food detected"}
''';

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', imageBytes),
      ])
    ];

    try {
      final response = await model.generateContent(content);
      final text = response.text;
      if (text != null && text.isNotEmpty) {
        // Parse JSON
        return jsonDecode(text);
      }
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
    return null;
  }
}
