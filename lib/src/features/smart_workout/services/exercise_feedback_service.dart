import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';

final exerciseFeedbackServiceProvider = Provider<ExerciseFeedbackService>((ref) {
  return ExerciseFeedbackService(ref);
});

class ExerciseFeedbackService {
  final Ref _ref;

  ExerciseFeedbackService(this._ref);

  Future<void> submitFeedback({
    required String originalExercise,
    required String alternativeExercise,
    required String reason,
    String? additionalNotes,
  }) async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('exercise_feedback').add({
        'userId': user.uid,
        'originalExercise': originalExercise,
        'alternativeExercise': alternativeExercise,
        'reason': reason,
        'additionalNotes': additionalNotes ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving exercise feedback: $e');
    }
  }
}
