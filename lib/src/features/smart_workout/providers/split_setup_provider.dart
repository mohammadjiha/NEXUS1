import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../services/plan_generator.dart';
import 'routines_provider.dart';

class SplitSetupStatusNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('appData')
          .doc('split_setup')
          .get()
          .timeout(const Duration(seconds: 5));
      return doc.data()?['isComplete'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error loading split setup status: $e');
      return false; // Fail gracefully
    }
  }

  Future<void> completeSetup() async {
    state = const AsyncValue.loading();

    // Anchor the plan to today so it doesn't shift
    ref.read(splitSetupDataProvider.notifier).setPlanStartDate(DateTime.now());

    final user = ref.read(authStateProvider).asData?.value;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('appData')
            .doc('split_setup')
            .set({
              'isComplete': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error saving split setup: $e');
      }
    }

    state = const AsyncValue.data(true);
  }
  Future<void> resetSetup() async {
    state = const AsyncValue.loading();
    final user = ref.read(authStateProvider).asData?.value;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('appData')
            .doc('split_setup')
            .set({
              'isComplete': false,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error resetting split setup: $e');
      }
    }
    state = const AsyncValue.data(false);
  }
}

final splitSetupStatusProvider =
    AsyncNotifierProvider<SplitSetupStatusNotifier, bool>(() {
      return SplitSetupStatusNotifier();
    });

class WorkoutDay {
  final String dayName;
  final String date;
  final String? fullDate;
  final String title;
  final List<String> categories;
  final String? assignedRoutineId;
  final String? assignedRoutineName;
  final bool isRest;

  WorkoutDay({
    required this.dayName,
    required this.date,
    this.fullDate,
    required this.title,
    required this.categories,
    this.assignedRoutineId,
    this.assignedRoutineName,
    this.isRest = false,
  });
}

// A simple provider to hold the wizard state in memory
class SplitSetupData {
  final int daysPerWeek;
  final String splitType;
  final List<String> trainingDays;
  final DateTime? planStartDate;
  final Map<String, String> swappedDates;

  SplitSetupData({
    this.daysPerWeek = 4,
    this.splitType = '',
    this.trainingDays = const ['MON', 'WED', 'FRI', 'SAT'],
    this.planStartDate,
    this.swappedDates = const {},
  });

  SplitSetupData copyWith({
    int? daysPerWeek,
    String? splitType,
    List<String>? trainingDays,
    DateTime? planStartDate,
    Map<String, String>? swappedDates,
  }) {
    return SplitSetupData(
      daysPerWeek: daysPerWeek ?? this.daysPerWeek,
      splitType: splitType ?? this.splitType,
      trainingDays: trainingDays ?? this.trainingDays,
      planStartDate: planStartDate ?? this.planStartDate,
      swappedDates: swappedDates ?? this.swappedDates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daysPerWeek': daysPerWeek,
      'splitType': splitType,
      'trainingDays': trainingDays,
      'planStartDate': planStartDate?.toIso8601String(),
      'swappedDates': swappedDates,
    };
  }

  factory SplitSetupData.fromJson(Map<String, dynamic> json) {
    return SplitSetupData(
      daysPerWeek: json['daysPerWeek'] as int? ?? 4,
      splitType: json['splitType'] as String? ?? '',
      trainingDays:
          (json['trainingDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['MON', 'WED', 'FRI', 'SAT'],
      planStartDate: json['planStartDate'] != null
          ? DateTime.parse(json['planStartDate'] as String)
          : null,
      swappedDates:
          (json['swappedDates'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          const {},
    );
  }
}

class SplitSetupDataNotifier extends AsyncNotifier<SplitSetupData> {
  @override
  Future<SplitSetupData> build() async {
    final user = ref.watch(authStateProvider).asData?.value;
    if (user == null) return SplitSetupData(planStartDate: DateTime.now());

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appData')
        .doc('split_setup')
        .get();
    final data = doc.data()?['setupData'];
    if (data is Map<String, dynamic>) {
      final setupData = SplitSetupData.fromJson(data);
      return setupData.planStartDate == null
          ? setupData.copyWith(planStartDate: DateTime.now())
          : setupData;
    }
    return SplitSetupData(planStartDate: DateTime.now());
  }

  Future<void> _saveData(SplitSetupData data) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appData')
        .doc('split_setup')
        .set({
          'setupData': data.toJson(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void setDaysPerWeek(int days) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final defaultDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final newTrainingDays = defaultDays.take(days).toList();
    final data = current.copyWith(
      daysPerWeek: days,
      trainingDays: newTrainingDays,
      splitType: '',
    );
    state = AsyncData(data);
    _saveData(data);
  }

  void setSplitType(String type) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final data = current.copyWith(splitType: type);
    state = AsyncData(data);
    _saveData(data);
  }

  void toggleTrainingDay(String day) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final days = List<String>.from(current.trainingDays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      if (days.length < current.daysPerWeek) {
        days.add(day);
        final week = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
        days.sort((a, b) => week.indexOf(a).compareTo(week.indexOf(b)));
      }
    }
    final data = current.copyWith(trainingDays: days);
    state = AsyncData(data);
    _saveData(data);
  }

  void setPlanStartDate(DateTime date) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final data = current.copyWith(planStartDate: date);
    state = AsyncData(data);
    _saveData(data);
  }

  void addSwap(String date1, String date2) {
    final current =
        state.value ?? SplitSetupData(planStartDate: DateTime.now());
    final newSwaps = Map<String, String>.from(current.swappedDates);
    newSwaps[date1] = date2;
    newSwaps[date2] = date1;
    final data = current.copyWith(swappedDates: newSwaps);
    state = AsyncData(data);
    _saveData(data);
  }
}

final splitSetupDataProvider =
    AsyncNotifierProvider<SplitSetupDataNotifier, SplitSetupData>(() {
      return SplitSetupDataNotifier();
    });

final generatedPlanProvider = Provider<List<WorkoutDay>>((ref) {
  final setupData =
      ref.watch(splitSetupDataProvider).value ??
      SplitSetupData(planStartDate: DateTime.now());
  final catalog = ref.watch(routineCatalogProvider).value ?? {};

  return PlanGenerator.generatePlan(
    daysPerWeek: setupData.daysPerWeek,
    splitType: setupData.splitType,
    trainingDays: setupData.trainingDays,
    catalog: catalog,
    startDate: setupData.planStartDate ?? DateTime.now(),
  );
});
