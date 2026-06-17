import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/health_service.dart';

final connectedWearableProvider = StateProvider<String?>((ref) => null);

final heartRateProvider = FutureProvider<int?>((ref) async {
  return healthService.getLatestHeartRate();
});

final stepsProvider = FutureProvider<int>((ref) async {
  return healthService.getTodaySteps();
});
