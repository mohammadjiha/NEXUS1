import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';

class PersonalRecord {
  final double weight;
  final String dateIso;

  PersonalRecord({required this.weight, required this.dateIso});

  Map<String, dynamic> toJson() => {'weight': weight, 'dateIso': dateIso};

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    dateIso: json['dateIso'] as String? ?? DateTime.now().toIso8601String(),
  );
}

class ExerciseHistoryNotifier
    extends AsyncNotifier<Map<String, PersonalRecord>> {
  @override
  Future<Map<String, PersonalRecord>> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) return {};

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('exerciseHistory')
        .doc('personal_records')
        .get();
    final data = doc.data();
    final records = data?['records'] as Map<String, dynamic>?;
    if (records == null) return {};

    return records.map(
      (key, value) =>
          MapEntry(key, PersonalRecord.fromJson(value as Map<String, dynamic>)),
    );
  }

  Future<void> updateWeight(String exerciseName, double weight) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    final currentState = state.value ?? {};

    final currentMax = currentState[exerciseName]?.weight ?? 0.0;
    if (weight > currentMax) {
      final newState = Map<String, PersonalRecord>.from(currentState);
      newState[exerciseName] = PersonalRecord(
        weight: weight,
        dateIso: DateTime.now().toIso8601String(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exerciseHistory')
          .doc('personal_records')
          .set({
            'userId': user.uid,
            'records': newState.map((k, v) => MapEntry(k, v.toJson())),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      state = AsyncData(newState);
    }
  }

  double getPreviousWeight(String exerciseName) {
    return state.value?[exerciseName]?.weight ?? 0.0;
  }
}

final exerciseHistoryProvider =
    AsyncNotifierProvider<ExerciseHistoryNotifier, Map<String, PersonalRecord>>(
      () {
        return ExerciseHistoryNotifier();
      },
    );
