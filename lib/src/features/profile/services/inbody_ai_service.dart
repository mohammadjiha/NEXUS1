import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/services/remote_config_service.dart';

const String _geminiApiKeyOverride = String.fromEnvironment('GEMINI_API_KEY');

class InBodyAiService {
  final RemoteConfigService _remoteConfig;

  InBodyAiService(this._remoteConfig);

  Future<Map<String, dynamic>> parseInBodyFile({
    required Uint8List fileBytes,
    required String mimeType,
  }) async {
    try {
      final apiKey = _apiKey(_remoteConfig);
      if (apiKey.isEmpty) {
        throw Exception(
          'Gemini API key is missing. Please add it to Firebase Remote Config or as an environment variable.',
        );
      }

      final prompt = TextPart('''
        Analyze this body composition (InBody/TANITA) scan from an image, PDF, or document file.
        Extract the following data points exactly as numbers (no text, no units). 
        If a data point is missing, return 0.0.
        Respond ONLY with a valid JSON object matching this exact format:
        {
          "weight": 0.0,
          "height": 0.0,
          "bodyFat": 0.0,
          "muscleMass": 0.0,
          "fatFreeMass": 0.0,
          "water": 0.0,
          "bmr": 0.0,
          "visceralFat": 0.0,
          "metabolicAge": 0.0
        }
      ''');

      final filePart = DataPart(mimeType, fileBytes);
      final model = GenerativeModel(model: _modelName, apiKey: apiKey);

      final response = await model.generateContent([
        Content.multi([prompt, filePart]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('AI returned empty response');
      }

      String cleanedText = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> data = jsonDecode(cleanedText);
      return data;
    } catch (e) {
      throw Exception('Failed to parse InBody scan: $e');
    }
  }

  static String _apiKey(RemoteConfigService remoteConfig) {
    if (_geminiApiKeyOverride.isNotEmpty) return _geminiApiKeyOverride;
    return remoteConfig.getString('gemini_api_key').trim();
  }

  String get _modelName {
    final configured = _remoteConfig.getString('gemini_model').trim();
    return configured.isEmpty ? 'gemini-2.5-flash' : configured;
  }

  String mimeTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}

final inbodyAiServiceProvider = Provider<InBodyAiService>((ref) {
  return InBodyAiService(ref.watch(remoteConfigProvider));
});
