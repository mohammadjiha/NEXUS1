import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class UserModel {
  final String uid;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? gymId;
  final String? gymCode;
  final String? role; // 'player', 'coach', 'owner', 'independent'
  final String? photoUrl;
  final String? authProvider;
  final double? weight;
  final double? height;
  final int? age;
  final String? goal;
  final String? gender;
  final double? bodyFat;
  final DateTime? dateOfBirth;
  final double? muscleMass;
  final String? fitnessLevel;
  final String? trainingMode;
  final String? assignedCoachUid;
  final String? assignedCoachName;
  final String? subscriptionPlan;
  final double? discountAmount;
  final String? paymentMethod;
  final bool temporaryPasswordSet;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // New Admin/Coach fields
  final DateTime? subscriptionStart;
  final DateTime? subscriptionEnd;
  final double? totalAmount;
  final double? amountPaid;
  final double? amountRemaining;
  final String? registeredBy;
  final DateTime? lastLogin;
  final String? deviceInfo;
  final bool isActive;
  final int trophies;
  
  // Stats
  final int currentStreak;
  final int totalSessionsCompleted;
  final double adherenceScore;
  final double weightProgress;

  // Subscription freeze
  final bool isFrozen;
  final DateTime? frozenAt;
  final int freezeDays;
  final String? freezeReason;

  bool get isSubscriptionExpired =>
      subscriptionEnd != null && subscriptionEnd!.isBefore(DateTime.now());

  UserModel({
    required this.uid,
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.gymId,
    this.gymCode,
    this.role,
    this.photoUrl,
    this.authProvider,
    this.weight,
    this.height,
    this.age,
    this.goal,
    this.gender,
    this.bodyFat,
    this.dateOfBirth,
    this.muscleMass,
    this.fitnessLevel,
    this.trainingMode,
    this.assignedCoachUid,
    this.assignedCoachName,
    this.subscriptionPlan,
    this.discountAmount = 0.0,
    this.paymentMethod,
    this.temporaryPasswordSet = false,
    this.emailVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.subscriptionStart,
    this.subscriptionEnd,
    this.totalAmount = 0.0,
    this.amountPaid = 0.0,
    this.amountRemaining = 0.0,
    this.registeredBy,
    this.lastLogin,
    this.deviceInfo,
    this.isActive = true,
    this.trophies = 0,
    this.currentStreak = 0,
    this.totalSessionsCompleted = 0,
    this.adherenceScore = 0.0,
    this.weightProgress = 0.0,
    this.isFrozen = false,
    this.frozenAt,
    this.freezeDays = 0,
    this.freezeReason,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'gymId': gymId,
    'gymCode': gymCode,
    'role': role,
    'photoUrl': photoUrl,
    'authProvider': authProvider,
    'weight': weight,
    'height': height,
    'age': age,
    'goal': goal,
    'gender': gender,
    'bodyFat': bodyFat,
    'dateOfBirth': dateOfBirth == null
        ? null
        : Timestamp.fromDate(dateOfBirth!),
    'muscleMass': muscleMass,
    'fitnessLevel': fitnessLevel,
    'trainingMode': trainingMode,
    'assignedCoachUid': assignedCoachUid,
    'assignedCoachName': assignedCoachName,
    'subscriptionPlan': subscriptionPlan,
    'discountAmount': discountAmount,
    'paymentMethod': paymentMethod,
    'temporaryPasswordSet': temporaryPasswordSet,
    'emailVerified': emailVerified,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    'subscriptionStart': subscriptionStart == null
        ? null
        : Timestamp.fromDate(subscriptionStart!),
    'subscriptionEnd': subscriptionEnd == null
        ? null
        : Timestamp.fromDate(subscriptionEnd!),
    'totalAmount': totalAmount,
    'amountPaid': amountPaid,
    'amountRemaining': amountRemaining,
    'registeredBy': registeredBy,
    'lastLogin': lastLogin == null ? null : Timestamp.fromDate(lastLogin!),
    'deviceInfo': deviceInfo,
    'isActive': isActive,
    'trophies': trophies,
    'cups': trophies,
    'currentStreak': currentStreak,
    'totalSessionsCompleted': totalSessionsCompleted,
    'adherenceScore': adherenceScore,
    'weightProgress': weightProgress,
    'isFrozen': isFrozen,
    'frozenAt': frozenAt == null ? null : Timestamp.fromDate(frozenAt!),
    'freezeDays': freezeDays,
    'freezeReason': freezeReason,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) {
    try {
      return UserModel(
        uid: map['uid'] as String,
        email: map['email'] as String? ?? '',
        firstName: map['firstName'] as String?,
        lastName: map['lastName'] as String?,
        phone: map['phone'] as String?,
        gymId: map['gymId'] as String?,
        gymCode: map['gymCode']?.toString(),
        role: map['role'] as String?,
        photoUrl: map['photoUrl'] as String?,
        authProvider: map['authProvider'] as String?,
        weight: (map['weight'] as num?)?.toDouble(),
        height: (map['height'] as num?)?.toDouble(),
        age: (map['age'] as num?)?.toInt(),
        goal: map['goal'] as String?,
        gender: map['gender'] as String?,
        bodyFat: (map['bodyFat'] as num?)?.toDouble(),
        dateOfBirth: _parseDate(map['dateOfBirth']),
        muscleMass: (map['muscleMass'] as num?)?.toDouble(),
        fitnessLevel: map['fitnessLevel'] as String?,
        trainingMode: map['trainingMode'] as String?,
        assignedCoachUid: map['assignedCoachUid'] as String?,
        assignedCoachName: map['assignedCoachName'] as String?,
        subscriptionPlan: map['subscriptionPlan'] as String?,
        discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
        paymentMethod: map['paymentMethod'] as String?,
        temporaryPasswordSet: map['temporaryPasswordSet'] as bool? ?? false,
        emailVerified: map['emailVerified'] as bool? ?? false,
        createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
        updatedAt: _parseDate(map['updatedAt']),
        subscriptionStart: _parseDate(map['subscriptionStart']),
        subscriptionEnd: _parseDate(map['subscriptionEnd']),
        totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
        amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
        amountRemaining: (map['amountRemaining'] as num?)?.toDouble() ?? 0.0,
        registeredBy: map['registeredBy'] as String?,
        lastLogin: _parseDate(map['lastLogin']),
        deviceInfo: map['deviceInfo'] as String?,
        isActive: map['isActive'] as bool? ?? true,
        trophies:
            _parseInt(map['trophies']) ??
            _parseInt(map['cups']) ??
            _parseInt(map['rank']) ??
            _parseInt(map['rankPoints']) ??
            0,
        currentStreak: _parseInt(map['currentStreak']) ?? 0,
        totalSessionsCompleted: _parseInt(map['totalSessionsCompleted']) ?? 0,
        adherenceScore: (map['adherenceScore'] as num?)?.toDouble() ?? 0.0,
        weightProgress: (map['weightProgress'] as num?)?.toDouble() ?? 0.0,
        isFrozen: map['isFrozen'] as bool? ?? false,
        frozenAt: _parseDate(map['frozenAt']),
        freezeDays: _parseInt(map['freezeDays']) ?? 0,
        freezeReason: map['freezeReason'] as String?,
      );
    } catch (e, stack) {
      // Log parse failures to Crashlytics / debug console — no local file I/O.

      debugPrint('UserModel.fromMap error: $e\n$stack');
      rethrow;
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? gymId,
    String? gymCode,
    String? role,
    String? photoUrl,
    String? authProvider,
    double? weight,
    double? height,
    int? age,
    String? goal,
    String? gender,
    double? bodyFat,
    DateTime? dateOfBirth,
    double? muscleMass,
    String? fitnessLevel,
    String? trainingMode,
    String? assignedCoachUid,
    String? assignedCoachName,
    String? subscriptionPlan,
    double? discountAmount,
    String? paymentMethod,
    bool? temporaryPasswordSet,
    bool? emailVerified,
    DateTime? updatedAt,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    double? totalAmount,
    double? amountPaid,
    double? amountRemaining,
    String? registeredBy,
    DateTime? lastLogin,
    String? deviceInfo,
    bool? isActive,
    int? trophies,
    // ── Stats (were missing — fixed) ──────────────────────────────────────
    int? currentStreak,
    int? totalSessionsCompleted,
    double? adherenceScore,
    double? weightProgress,
    bool? isFrozen,
    DateTime? frozenAt,
    int? freezeDays,
    String? freezeReason,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      gymId: gymId ?? this.gymId,
      gymCode: gymCode ?? this.gymCode,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      authProvider: authProvider ?? this.authProvider,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      age: age ?? this.age,
      goal: goal ?? this.goal,
      gender: gender ?? this.gender,
      bodyFat: bodyFat ?? this.bodyFat,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      muscleMass: muscleMass ?? this.muscleMass,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      trainingMode: trainingMode ?? this.trainingMode,
      assignedCoachUid: assignedCoachUid ?? this.assignedCoachUid,
      assignedCoachName: assignedCoachName ?? this.assignedCoachName,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      discountAmount: discountAmount ?? this.discountAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      temporaryPasswordSet: temporaryPasswordSet ?? this.temporaryPasswordSet,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscriptionStart: subscriptionStart ?? this.subscriptionStart,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPaid: amountPaid ?? this.amountPaid,
      amountRemaining: amountRemaining ?? this.amountRemaining,
      registeredBy: registeredBy ?? this.registeredBy,
      lastLogin: lastLogin ?? this.lastLogin,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      isActive: isActive ?? this.isActive,
      trophies: trophies ?? this.trophies,
      currentStreak: currentStreak ?? this.currentStreak,
      totalSessionsCompleted: totalSessionsCompleted ?? this.totalSessionsCompleted,
      adherenceScore: adherenceScore ?? this.adherenceScore,
      weightProgress: weightProgress ?? this.weightProgress,
      isFrozen: isFrozen ?? this.isFrozen,
      frozenAt: frozenAt ?? this.frozenAt,
      freezeDays: freezeDays ?? this.freezeDays,
      freezeReason: freezeReason ?? this.freezeReason,
    );
  }
}
