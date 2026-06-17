import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../profile/providers/body_metrics_provider.dart';
import '../domain/models/ai_coach_report.dart';
import '../services/ai_coach_service.dart';

enum AICoachStateStatus { idle, analyzing, success, error }

class AICoachState {
  final AICoachStateStatus status;
  final AICoachReport? report;
  final String? errorMessage;
  final double progress;

  AICoachState({
    this.status = AICoachStateStatus.idle,
    this.report,
    this.errorMessage,
    this.progress = 0.0,
  });

  AICoachState copyWith({
    AICoachStateStatus? status,
    AICoachReport? report,
    String? errorMessage,
    double? progress,
  }) {
    return AICoachState(
      status: status ?? this.status,
      report: report ?? this.report,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

final aiCoachProvider = NotifierProvider<AICoachNotifier, AICoachState>(AICoachNotifier.new);

class AICoachNotifier extends Notifier<AICoachState> {
  @override
  AICoachState build() {
    return AICoachState();
  }

  Future<void> analyzeVideo(String videoPath, String exerciseName) async {
    state = state.copyWith(status: AICoachStateStatus.analyzing, progress: 0.1);

    try {
      // Simulate some processing steps
      await Future.delayed(AppDurations.shortDelay);
      state = state.copyWith(progress: 0.3);

      final file = File(videoPath);
      final bytes = await file.readAsBytes();
      state = state.copyWith(progress: 0.6);
      
      final aiService = ref.read(aiCoachServiceProvider);
      final bodyMetrics = await ref.read(bodyMetricsProvider.future);
      String mimeType = videoPath.toLowerCase().endsWith('.mp4') ? 'video/mp4' : 'image/jpeg';
      final report = await aiService.analyzeVideo(
        bytes, 
        mimeType, 
        exerciseName: exerciseName,
        experienceLevel: bodyMetrics.experienceLevel,
      );

      state = state.copyWith(progress: 1.0);
      await Future.delayed(AppDurations.aiStepDelay);

      if (report != null) {
        state = state.copyWith(status: AICoachStateStatus.success, report: report);
      } else {
        state = state.copyWith(status: AICoachStateStatus.error, errorMessage: 'Could not generate report.');
      }
    } catch (e) {
      state = state.copyWith(status: AICoachStateStatus.error, errorMessage: e.toString());
    }
  }

  void reset() {
    state = AICoachState();
  }
}
