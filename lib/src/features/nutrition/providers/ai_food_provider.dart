import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_food_service.dart';

final aiFoodScanStateProvider = AsyncNotifierProvider<AIFoodScanNotifier, Map<String, dynamic>?>(() {
  return AIFoodScanNotifier();
});

class AIFoodScanNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    return null;
  }

  Future<void> scanImage(Uint8List imageBytes) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(aiFoodServiceProvider);
      final result = await service.analyzeFoodImage(imageBytes);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
