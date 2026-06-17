import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';

class CompletedSession {
  final String date;
  final String dayName;
  final String routineName;
  final int durationMinutes;
  final int completedSets;
  final int totalSets;
  final String category;
  final String? timestampIso;
  final List<dynamic>? exercisesLog;

  CompletedSession({
    required this.date,
    required this.dayName,
    required this.routineName,
    required this.durationMinutes,
    required this.completedSets,
    required this.totalSets,
    required this.category,
    this.timestampIso,
    this.exercisesLog,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'dayName': dayName,
      'routineName': routineName,
      'durationMinutes': durationMinutes,
      'completedSets': completedSets,
      'totalSets': totalSets,
      'category': category,
      'timestampIso': timestampIso ?? DateTime.now().toIso8601String(),
      if (exercisesLog != null) 'exercisesLog': exercisesLog,
    };
  }

  factory CompletedSession.fromJson(Map<String, dynamic> json) {
    return CompletedSession(
      date: json['date'] as String,
      dayName: json['dayName'] as String,
      routineName: json['routineName'] as String,
      durationMinutes: json['durationMinutes'] as int,
      completedSets: json['completedSets'] as int,
      totalSets: json['totalSets'] as int,
      category: json['category'] as String,
      timestampIso: json['timestampIso'] as String?,
      exercisesLog: json['exercisesLog'] as List<dynamic>?,
    );
  }
}

class WorkoutHistoryNotifier extends Notifier<List<CompletedSession>> {
  @override
  List<CompletedSession> build() {
    ref.listen(authStateProvider, (previous, next) {
      if (next.asData?.value != null) {
        _loadData();
      } else {
        state = [];
      }
    }, fireImmediately: true);
    return [];
  }

  Future<void> _loadData() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      state = [];
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('workoutHistory')
        .orderBy('timestampIso', descending: true)
        .get();

    state = snapshot.docs
        .map((doc) => CompletedSession.fromJson(doc.data()))
        .toList();
  }

  Future<void> addSession(CompletedSession session) async {
    state = [session, ...state];
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('workoutHistory')
        .add({
          ...session.toJson(),
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}

final workoutHistoryProvider =
    NotifierProvider<WorkoutHistoryNotifier, List<CompletedSession>>(
      WorkoutHistoryNotifier.new,
    );

final recoveryScoreProvider = Provider.family<int, String>((ref, category) {
  final history = ref.watch(workoutHistoryProvider);
  final categoryHistory = history.where((h) => h.category == category).toList();
  if (categoryHistory.isEmpty) return 100;

  final lastSession = categoryHistory.first;
  if (lastSession.timestampIso == null) return 84;

  try {
    final lastTime = DateTime.parse(lastSession.timestampIso!);
    final diffHours = DateTime.now().difference(lastTime).inHours;
    final recovery = (diffHours * 2.08).round();
    return recovery.clamp(0, 100);
  } catch (e) {
    return 84;
  }
});
