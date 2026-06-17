import 'dart:io';

import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  final Health _health = Health();

  Future<bool> requestPermissions() async {
    final types = [
      HealthDataType.HEART_RATE,
      HealthDataType.STEPS,
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];

    final permissions = types.map((e) => HealthDataAccess.READ).toList();

    if (Platform.isAndroid) {
      final activityPermission = await Permission.activityRecognition.request();
      if (activityPermission.isDenied) return false;
    }

    bool requested = await _health.requestAuthorization(types, permissions: permissions);
    return requested;
  }

  Future<int?> getLatestHeartRate() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    try {
      List<HealthDataPoint> healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: yesterday,
        endTime: now,
      );

      if (healthData.isEmpty) return null;

      // Sort to get the most recent
      healthData.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final latest = healthData.first.value;
      
      // newer health package versions use NumericHealthValue
      if (latest is NumericHealthValue) {
        return latest.numericValue.toInt();
      }
      return int.tryParse(latest.toString());
    } catch (e) {
      return null;
    }
  }

  Future<int> getTodaySteps() async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      return 0;
    }
  }
}

final healthService = HealthService();
