import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';

class BodyMetrics {
  final double weight;
  final double previousWeight;
  final double height;
  final double previousHeight;
  final double bodyFat;
  final double previousBodyFat;
  final double muscleMass;
  final double previousMuscleMass;
  final double waist;
  final double previousWaist;
  final double initialWeight;
  final int age;
  final String dateOfBirth;
  final String goal;
  final String gender;
  final String experienceLevel;

  // New AI InBody Fields
  final double bmr;
  final double visceralFat;
  final double fatFreeMass;
  final double water;
  final double metabolicAge;

  BodyMetrics({
    this.weight = 0.0,
    this.previousWeight = 0.0,
    this.height = 0.0,
    this.previousHeight = 0.0,
    this.bodyFat = 0.0,
    this.previousBodyFat = 0.0,
    this.muscleMass = 0.0,
    this.previousMuscleMass = 0.0,
    this.waist = 0.0,
    this.previousWaist = 0.0,
    this.initialWeight = 0.0,
    this.age = 0,
    this.dateOfBirth = '',
    this.goal = '',
    this.gender = '',
    this.experienceLevel = 'Intermediate',
    this.bmr = 0.0,
    this.visceralFat = 0.0,
    this.fatFreeMass = 0.0,
    this.water = 0.0,
    this.metabolicAge = 0.0,
  });

  double get bmi {
    if (height <= 0 || weight <= 0) return 0.0;
    final hMeters = height / 100;
    return weight / (hMeters * hMeters);
  }

  double get previousBmi {
    if (previousHeight <= 0 || previousWeight <= 0) return 0.0;
    final hMeters = previousHeight / 100;
    return previousWeight / (hMeters * hMeters);
  }

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'previousWeight': previousWeight,
    'height': height,
    'previousHeight': previousHeight,
    'bodyFat': bodyFat,
    'previousBodyFat': previousBodyFat,
    'muscleMass': muscleMass,
    'previousMuscleMass': previousMuscleMass,
    'waist': waist,
    'previousWaist': previousWaist,
    'initialWeight': initialWeight,
    'age': age,
    'dateOfBirth': dateOfBirth,
    'goal': goal,
    'gender': gender,
    'experienceLevel': experienceLevel,
    'bmr': bmr,
    'visceralFat': visceralFat,
    'fatFreeMass': fatFreeMass,
    'water': water,
    'metabolicAge': metabolicAge,
  };

  factory BodyMetrics.fromJson(Map<String, dynamic> json) => BodyMetrics(
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    previousWeight:
        (json['previousWeight'] as num?)?.toDouble() ??
        ((json['weight'] as num?)?.toDouble() ?? 0.0),
    height: (json['height'] as num?)?.toDouble() ?? 0.0,
    previousHeight:
        (json['previousHeight'] as num?)?.toDouble() ??
        ((json['height'] as num?)?.toDouble() ?? 0.0),
    bodyFat: (json['bodyFat'] as num?)?.toDouble() ?? 0.0,
    previousBodyFat:
        (json['previousBodyFat'] as num?)?.toDouble() ??
        ((json['bodyFat'] as num?)?.toDouble() ?? 0.0),
    muscleMass: (json['muscleMass'] as num?)?.toDouble() ?? 0.0,
    previousMuscleMass:
        (json['previousMuscleMass'] as num?)?.toDouble() ??
        ((json['muscleMass'] as num?)?.toDouble() ?? 0.0),
    waist: (json['waist'] as num?)?.toDouble() ?? 0.0,
    previousWaist:
        (json['previousWaist'] as num?)?.toDouble() ??
        ((json['waist'] as num?)?.toDouble() ?? 0.0),
    initialWeight: (json['initialWeight'] as num?)?.toDouble() ?? 0.0,
    age: (json['age'] as num?)?.toInt() ?? 0,
    dateOfBirth: json['dateOfBirth'] as String? ?? '',
    goal: json['goal'] as String? ?? '',
    gender: json['gender'] as String? ?? '',
    experienceLevel: json['experienceLevel'] as String? ?? 'Intermediate',
    bmr: (json['bmr'] as num?)?.toDouble() ?? 0.0,
    visceralFat: (json['visceralFat'] as num?)?.toDouble() ?? 0.0,
    fatFreeMass: (json['fatFreeMass'] as num?)?.toDouble() ?? 0.0,
    water: (json['water'] as num?)?.toDouble() ?? 0.0,
    metabolicAge: (json['metabolicAge'] as num?)?.toDouble() ?? 0.0,
  );

  BodyMetrics copyWith({
    double? weight,
    double? height,
    double? bodyFat,
    double? muscleMass,
    double? waist,
    double? initialWeight,
    int? age,
    String? dateOfBirth,
    String? goal,
    String? gender,
    String? experienceLevel,
    double? bmr,
    double? visceralFat,
    double? fatFreeMass,
    double? water,
    double? metabolicAge,
  }) {
    return BodyMetrics(
      weight: weight ?? this.weight,
      previousWeight: weight != null ? this.weight : previousWeight,
      height: height ?? this.height,
      previousHeight: height != null ? this.height : previousHeight,
      bodyFat: bodyFat ?? this.bodyFat,
      previousBodyFat: bodyFat != null ? this.bodyFat : previousBodyFat,
      muscleMass: muscleMass ?? this.muscleMass,
      previousMuscleMass: muscleMass != null
          ? this.muscleMass
          : previousMuscleMass,
      waist: waist ?? this.waist,
      previousWaist: waist != null ? this.waist : previousWaist,
      initialWeight: initialWeight ?? this.initialWeight,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      goal: goal ?? this.goal,
      gender: gender ?? this.gender,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      bmr: bmr ?? this.bmr,
      visceralFat: visceralFat ?? this.visceralFat,
      fatFreeMass: fatFreeMass ?? this.fatFreeMass,
      water: water ?? this.water,
      metabolicAge: metabolicAge ?? this.metabolicAge,
    );
  }

  bool get hasRequiredProfileData =>
      weight > 0 &&
      height > 0 &&
      bodyFat > 0 &&
      muscleMass > 0 &&
      age > 0 &&
      dateOfBirth.trim().isNotEmpty &&
      goal.trim().isNotEmpty &&
      gender.trim().isNotEmpty;

  List<String> get missingRequiredLabels {
    final missing = <String>[];
    if (weight <= 0) missing.add('Weight');
    if (height <= 0) missing.add('Height');
    if (bodyFat <= 0) missing.add('Body Fat');
    if (muscleMass <= 0) missing.add('Muscle');
    if (dateOfBirth.trim().isEmpty) missing.add('Birth Date');
    if (age <= 0) missing.add('Age');
    if (goal.trim().isEmpty) missing.add('Goal');
    if (gender.trim().isEmpty) missing.add('Gender');
    return missing;
  }

  BodyMetrics withCalculatedDefaults() {
    if (weight <= 0 || height <= 0) return this;

    final normalizedGender = gender.trim().toLowerCase();
    final isFemale = normalizedGender == 'female';
    final safeAge = age > 0 ? age : 25;
    final safeBodyFat = bodyFat > 0 ? bodyFat : (isFemale ? 25.0 : 18.0);
    final safeFatFreeMass = fatFreeMass > 0
        ? fatFreeMass
        : weight * (1 - safeBodyFat / 100);
    final safeWater = water > 0 ? water : weight * (isFemale ? 0.50 : 0.55);
    final safeBmr = bmr > 0
        ? bmr
        : (10 * weight) +
              (6.25 * height) -
              (5 * safeAge) +
              (isFemale ? -161 : 5);
    final safeVisceralFat = visceralFat > 0
        ? visceralFat
        : safeBodyFat < 18
        ? 6.0
        : safeBodyFat < 25
        ? 9.0
        : 12.0;
    final safeMetabolicAge = metabolicAge > 0
        ? metabolicAge
        : (safeAge + (safeBodyFat > (isFemale ? 30 : 22) ? 3 : 0)).toDouble();
    final safeWaist = waist > 0
        ? waist
        : (height * (isFemale ? 0.43 : 0.46)) + (safeBodyFat * 0.35);

    return copyWith(
      bodyFat: safeBodyFat,
      fatFreeMass: _roundOne(safeFatFreeMass),
      water: _roundOne(safeWater),
      bmr: safeBmr.roundToDouble(),
      visceralFat: _roundOne(safeVisceralFat),
      metabolicAge: safeMetabolicAge.roundToDouble(),
      waist: _roundOne(safeWaist),
      initialWeight: initialWeight > 0 ? initialWeight : weight,
    );
  }

  static double _roundOne(double value) => (value * 10).roundToDouble() / 10;
}

class BodyMetricsNotifier extends AsyncNotifier<BodyMetrics> {
  @override
  Future<BodyMetrics> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return BodyMetrics();

    // 1. Show local cache immediately for instant UI
    BodyMetrics cached = BodyMetrics();
    try {
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString('local_body_metrics_${user.uid}');
      if (localData != null) {
        cached = BodyMetrics.fromJson(jsonDecode(localData));
      }
    } catch (_) {}

    // 2. Real-time stream — auto-updates whenever admin/coach/superAdmin
    //    edits the player's body metrics in Firestore.
    final sub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('metrics')
        .doc('body_composition')
        .snapshots()
        .listen((doc) async {
          if (doc.exists && doc.data() != null) {
            final fbMetrics  = BodyMetrics.fromJson(doc.data()!);
            final normalized = fbMetrics.withCalculatedDefaults();
            state = AsyncValue.data(normalized);
            // Update local cache so next cold-start is instant
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(
                'local_body_metrics_${user.uid}',
                jsonEncode(normalized.toJson()),
              );
            } catch (_) {}
            // Backfill computed fields if Firestore doc is missing them
            if (normalized.toJson().toString() != fbMetrics.toJson().toString()) {
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('metrics')
                  .doc('body_composition')
                  .set({
                    ...normalized.toJson(),
                    'userId': user.uid,
                    'updatedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true))
                  .ignore();
            }
          } else {
            await _ensureBodyCompositionDocument(user.uid);
          }
        });

    // Cancel stream when provider is disposed / user signs out
    ref.onDispose(sub.cancel);

    return cached; // Show cache while first stream event loads
  }

  Future<void> _ensureBodyCompositionDocument(String uid) async {
    final json = BodyMetrics().toJson();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('metrics')
        .doc('body_composition')
        .set({
          ...json,
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> updateMetrics({
    double? weight,
    double? height,
    double? bodyFat,
    double? muscleMass,
    double? waist,
    int? age,
    String? dateOfBirth,
    String? goal,
    String? gender,
    String? experienceLevel,
    double? bmr,
    double? visceralFat,
    double? fatFreeMass,
    double? water,
    double? metabolicAge,
  }) async {
    final current = state.value ?? BodyMetrics();
    final updated = current.copyWith(
      weight: weight,
      height: height,
      bodyFat: bodyFat,
      muscleMass: muscleMass,
      waist: waist,
      age: age,
      dateOfBirth: dateOfBirth,
      goal: goal,
      gender: gender,
      experienceLevel: experienceLevel,
      bmr: bmr,
      visceralFat: visceralFat,
      fatFreeMass: fatFreeMass,
      water: water,
      metabolicAge: metabolicAge,
    );
    final normalized = updated.withCalculatedDefaults();
    state = AsyncValue.data(normalized);
    await _saveData(normalized);
  }

  Future<void> updateProfileMetrics({
    required double weight,
    required double height,
    required double bodyFat,
    required double muscleMass,
    required int age,
    required String dateOfBirth,
    required String goal,
    required String gender,
    required String experienceLevel,
  }) async {
    final updated = (state.value ?? BodyMetrics())
        .copyWith(
          weight: weight,
          height: height,
          bodyFat: bodyFat,
          muscleMass: muscleMass,
          age: age,
          dateOfBirth: dateOfBirth,
          goal: goal,
          gender: gender,
          experienceLevel: experienceLevel,
        )
        .withCalculatedDefaults();
    state = AsyncValue.data(updated);
    await _saveData(updated);
  }

  Future<void> updateWeight(double newWeight) async {
    final current = state.value ?? BodyMetrics();
    final updated = current
        .copyWith(weight: newWeight)
        .withCalculatedDefaults();
    state = AsyncValue.data(updated);
    await _saveData(updated);
  }

  Future<void> replaceEntireMetrics(BodyMetrics newMetrics) async {
    final normalized = newMetrics.withCalculatedDefaults();
    state = AsyncValue.data(normalized);
    await _saveData(normalized);
  }

  Future<void> _saveData(BodyMetrics metrics) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    final json = metrics.toJson();

    // 1. Save locally instantly
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_body_metrics_${user.uid}', jsonEncode(json));
    } catch (_) {}

    // 2. Save to metrics subcollection — triggers the real-time stream above
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('metrics')
          .doc('body_composition')
          .set({
            ...json,
            'userId': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }

    // 3. Mirror body fields to users/{uid} main doc so admin/coach/superAdmin
    //    see the latest metrics without querying the subcollection.
    try {
      final dateOfBirthTs = metrics.dateOfBirth.isNotEmpty
          ? Timestamp.fromDate(
              DateTime.tryParse(metrics.dateOfBirth) ?? DateTime.now())
          : null;
      final userUpdate = <String, dynamic>{
        'weight':      metrics.weight,
        'height':      metrics.height,
        'bodyFat':     metrics.bodyFat,
        'muscleMass':  metrics.muscleMass,
        'goal':        metrics.goal,
        'fitnessLevel': metrics.experienceLevel,
        'age':         metrics.age,
        'updatedAt':   FieldValue.serverTimestamp(),
      };
      if (dateOfBirthTs != null) userUpdate['dateOfBirth'] = dateOfBirthTs;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(userUpdate);
    } catch (_) {
      // Non-fatal — metrics subcollection is the source of truth
    }
  }
}

final bodyMetricsProvider =
    AsyncNotifierProvider<BodyMetricsNotifier, BodyMetrics>(() {
      return BodyMetricsNotifier();
    });
