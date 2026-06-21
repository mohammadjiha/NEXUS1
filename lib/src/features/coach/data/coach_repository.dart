import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';

import '../../user/models/user_model.dart';
import '../models/payment_record.dart';

class AddPlayerInput {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String phone;
  final DateTime dateOfBirth;
  final String assignedCoachName;
  final String? assignedCoachUid; // null → caller's own UID (coach flow)
  final double weight;
  final double height;
  final double bodyFat;
  final double muscleMass;
  final String goal;
  final String gender;
  final String fitnessLevel;
  final String trainingMode;
  final String subscriptionPlan;
  final DateTime subscriptionStart;
  final int durationMonths;
  final DateTime? subscriptionEnd; // if set, overrides the months-based calculation
  final double totalAmount;
  final double discountAmount;
  final double amountPaid;
  final String paymentMethod;
  final String? gymCode;

  const AddPlayerInput({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.phone,
    required this.dateOfBirth,
    required this.assignedCoachName,
    this.assignedCoachUid,
    required this.weight,
    required this.height,
    required this.bodyFat,
    required this.muscleMass,
    required this.goal,
    required this.gender,
    required this.fitnessLevel,
    required this.trainingMode,
    required this.subscriptionPlan,
    required this.subscriptionStart,
    required this.durationMonths,
    this.subscriptionEnd,
    required this.totalAmount,
    required this.discountAmount,
    required this.amountPaid,
    required this.paymentMethod,
    this.gymCode,
  });
}

class CoachSentNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final List<String> targetNames;
  final int targetCount;
  final DateTime createdAt;

  const CoachSentNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.targetNames,
    required this.targetCount,
    required this.createdAt,
  });

  factory CoachSentNotification.fromMap(String id, Map<String, dynamic> map) {
    return CoachSentNotification(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'feedback',
      targetNames: List<String>.from(map['targetNames'] ?? const []),
      targetCount: (map['targetCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseSafeDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseSafeDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }
}

class CoachRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _normalizePhone(String input) {
    var value = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (value.startsWith('+')) return value;
    if (value.startsWith('962')) return '+$value';
    if (value.startsWith('0')) return '+962${value.substring(1)}';
    return '+962$value';
  }

  String _phoneKey(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  Stream<List<UserModel>> getMembers(String uid, String? gymId) {
    Query query = _firestore
        .collection('users')
        .where('role', isEqualTo: 'player');

    if (gymId != null && gymId.trim().isNotEmpty) {
      query = query.where('gymId', isEqualTo: gymId.trim());
    }

    return query.snapshots().map((snapshot) {
      final gymScopedMembers = snapshot.docs
          .map((doc) {
            try {
              return UserModel.fromMap(doc.data() as Map<String, dynamic>);
            } catch (e) {
              return null;
            }
          })
          .where((m) => m != null)
          .cast<UserModel>()
          .toList();
      final members = gymId != null && gymId.trim().isNotEmpty
          ? gymScopedMembers
          : gymScopedMembers
                .where(
                  (m) => m.registeredBy == uid || m.assignedCoachUid == uid,
                )
                .toList();
      members.sort((a, b) => (b.createdAt).compareTo(a.createdAt));
      return members;
    });
  }

  Future<String?> _resolveGymIdForAddPlayer(
    Map<String, dynamic>? currentUserData,
    String? inputGymCode,
  ) async {
    final fallbackGymId = (currentUserData?['gymId'] as String?)?.trim();
    final code = inputGymCode?.trim();
    if (code == null || code.isEmpty) return fallbackGymId;
    if (fallbackGymId == null || fallbackGymId.isEmpty) {
      throw Exception('Coach is not linked to a gym.');
    }

    if (code.toUpperCase().startsWith('GYM-')) {
      final gymDoc = await _firestore.collection('gyms').doc(code).get();
      if (!gymDoc.exists) throw Exception('Gym $code was not found.');
      if (gymDoc.id != fallbackGymId) {
        throw Exception('Gym code does not match your gym.');
      }
      final status = gymDoc.data()?['status'];
      if (status != null && status != 'active') {
        throw Exception('Gym $code is not active.');
      }
      return gymDoc.id;
    }

    final codeValue = int.tryParse(code) ?? code;
    final query = await _firestore
        .collection('gyms')
        .where('gymCode', isEqualTo: codeValue)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      throw Exception('Gym code $code was not found.');
    }

    final gymDoc = query.docs.first;
    if (gymDoc.id != fallbackGymId) {
      throw Exception('Gym code does not match your gym.');
    }
    final status = gymDoc.data()['status'];
    if (status != null && status != 'active') {
      throw Exception('Gym code $code is not active.');
    }

    return gymDoc.id;
  }

  Future<void> addPlayer(AddPlayerInput input) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final currentUserData = currentUserDoc.data();
    final gymId = await _resolveGymIdForAddPlayer(
      currentUserData,
      input.gymCode,
    );
    if (gymId == null || gymId.isEmpty) {
      throw Exception('Coach is not linked to a gym.');
    }
    final coachName = input.assignedCoachName.trim().isNotEmpty
        ? input.assignedCoachName.trim()
        : [
            currentUserData?['firstName'] as String?,
            currentUserData?['lastName'] as String?,
          ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    final recoveryPhone = _normalizePhone(input.phone);
    final recoveryRef = _firestore
        .collection('accountRecovery')
        .doc(_phoneKey(recoveryPhone));
    if ((await recoveryRef.get()).exists) {
      throw Exception('This phone number is already registered.');
    }

    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'AddPlayerApp_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: input.email.trim(),
        password: input.password,
      );

      final newUid = userCredential.user!.uid;
      final now = DateTime.now();
      await userCredential.user!.updateDisplayName(
        '${input.firstName.trim()} ${input.lastName.trim()}'.trim(),
      );
      final end = input.subscriptionEnd ?? DateTime(
        input.subscriptionStart.year,
        input.subscriptionStart.month + input.durationMonths,
        input.subscriptionStart.day,
      );
      final amountRemaining =
          (input.totalAmount - input.discountAmount - input.amountPaid)
              .clamp(0, double.infinity)
              .toDouble();

      final newUser = UserModel(
        uid: newUid,
        email: input.email.trim().toLowerCase(),
        firstName: input.firstName.trim(),
        lastName: input.lastName.trim(),
        phone: input.phone.trim(),
        gymId: gymId,
        role: 'player',
        weight: input.weight,
        height: input.height,
        bodyFat: input.bodyFat,
        muscleMass: input.muscleMass,
        goal: input.goal,
        gender: input.gender,
        dateOfBirth: input.dateOfBirth,
        fitnessLevel: input.fitnessLevel,
        trainingMode: input.trainingMode,
        assignedCoachUid: input.assignedCoachUid ?? currentUser.uid,
        assignedCoachName: coachName,
        subscriptionPlan: input.subscriptionPlan,
        discountAmount: input.discountAmount,
        paymentMethod: input.paymentMethod,
        temporaryPasswordSet: true,
        authProvider: 'password',
        emailVerified: true,
        createdAt: now,
        updatedAt: now,
        subscriptionStart: input.subscriptionStart,
        subscriptionEnd: end,
        totalAmount: input.totalAmount,
        amountPaid: input.amountPaid,
        amountRemaining: amountRemaining,
        registeredBy: currentUser.uid,
      );

      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(newUid);
      final memberEmailRef = _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('memberEmails')
          .doc(input.email.trim().toLowerCase());
      final memberRef = _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(newUid);
      final metricsRef = userRef.collection('metrics').doc('body_composition');
      final paymentRef = userRef.collection('payments').doc();
      final resolvedGymCode = input.gymCode?.trim().isNotEmpty ?? false
          ? input.gymCode!.trim()
          : null;

      batch.set(userRef, {
        ...newUser.toMap(),
        'gymCode': resolvedGymCode,
      }, SetOptions(merge: true));
      batch.set(memberEmailRef, {
        'role': 'player',
        'status': 'active',
        'firstName': input.firstName.trim(),
        'lastName': input.lastName.trim(),
        'phone': input.phone.trim(),
        'assignedCoachUid': input.assignedCoachUid ?? currentUser.uid,
        'assignedCoachName': coachName,
        'gymCode': resolvedGymCode,
        'addedBy': currentUser.uid,
        'addedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(memberRef, {
        'uid': newUid,
        'email': input.email.trim().toLowerCase(),
        'gymId': gymId,
        'gymCode': resolvedGymCode,
        'role': 'player',
        'displayName': '${input.firstName.trim()} ${input.lastName.trim()}'
            .trim(),
        'phone': input.phone.trim(),
        'status': 'active',
        'assignedCoachUid': input.assignedCoachUid ?? currentUser.uid,
        'assignedCoachName': coachName,
        'subscriptionPlan': input.subscriptionPlan,
        'subscriptionStart': Timestamp.fromDate(input.subscriptionStart),
        'subscriptionEnd': Timestamp.fromDate(end),
        'totalAmount': input.totalAmount,
        'discountAmount': input.discountAmount,
        'amountPaid': input.amountPaid,
        'amountRemaining': amountRemaining,
        'paymentMethod': input.paymentMethod,
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(metricsRef, {
        'userId': newUid,
        'weight': input.weight,
        'previousWeight': 0.0,
        'height': input.height,
        'previousHeight': 0.0,
        'bodyFat': input.bodyFat,
        'previousBodyFat': 0.0,
        'muscleMass': input.muscleMass,
        'previousMuscleMass': 0.0,
        'waist': 0.0,
        'previousWaist': 0.0,
        'initialWeight': input.weight,
        'age': _ageFromDate(input.dateOfBirth),
        'dateOfBirth': _dateText(input.dateOfBirth),
        'goal': input.goal,
        'fitnessLevel': input.fitnessLevel,
        'gender': input.gender,
        'trainingMode': input.trainingMode,
        'bmr': 0.0,
        'visceralFat': 0.0,
        'fatFreeMass': 0.0,
        'water': 0.0,
        'metabolicAge': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(recoveryRef, {
        'uid': newUid,
        'email': input.email.trim().toLowerCase(),
        'phone': recoveryPhone,
        'gymId': gymId,
        'role': 'player',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(
        paymentRef,
        _paymentHistoryData(
          input: input,
          endDate: end,
          amountRemaining: amountRemaining,
          type: 'player_added',
          actorUid: currentUser.uid,
        ),
      );

      await batch.commit();
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> updatePlayer({
    required String playerUid,
    required AddPlayerInput input,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final currentUserData = currentUserDoc.data();
    final gymId = (currentUserData?['gymId'] as String?)?.trim();
    if (gymId == null || gymId.isEmpty) {
      throw Exception('Coach is not linked to a gym.');
    }

    final playerRef = _firestore.collection('users').doc(playerUid);
    final playerDoc = await playerRef.get();
    final playerData = playerDoc.data();
    if (!playerDoc.exists ||
        (playerData?['role'] as String?) != 'player' ||
        (playerData?['gymId'] as String?)?.trim() != gymId) {
      throw Exception('Player is not linked to your gym.');
    }

    final coachName = input.assignedCoachName.trim().isNotEmpty
        ? input.assignedCoachName.trim()
        : [
            currentUserData?['firstName'] as String?,
            currentUserData?['lastName'] as String?,
          ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    final end = DateTime(
      input.subscriptionStart.year,
      input.subscriptionStart.month + input.durationMonths,
      input.subscriptionStart.day,
    );
    final amountRemaining =
        (input.totalAmount - input.discountAmount - input.amountPaid)
            .clamp(0, double.infinity)
            .toDouble();
    final displayName = '${input.firstName.trim()} ${input.lastName.trim()}'
        .trim();
    final resolvedGymCode = input.gymCode?.trim().isNotEmpty ?? false
        ? input.gymCode!.trim()
        : null;

    final batch = _firestore.batch();
    final memberEmailRef = _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('memberEmails')
        .doc(
          (playerData?['email'] as String? ?? input.email).trim().toLowerCase(),
        );
    final memberRef = _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(playerUid);
    final metricsRef = playerRef.collection('metrics').doc('body_composition');
    final recoveryPhone = _normalizePhone(input.phone);
    final recoveryRef = _firestore
        .collection('accountRecovery')
        .doc(_phoneKey(recoveryPhone));
    final paymentRef = playerRef.collection('payments').doc();
    final previousPaid = (playerData?['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final previousTotal =
        (playerData?['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final previousRemaining =
        (playerData?['amountRemaining'] as num?)?.toDouble() ?? 0.0;
    final previousPlan = (playerData?['subscriptionPlan'] as String?) ?? '';
    final previousMethod = (playerData?['paymentMethod'] as String?) ?? '';
    final paidDelta = input.amountPaid - previousPaid;
    final financeChanged =
        paidDelta > 0 ||
        input.totalAmount != previousTotal ||
        amountRemaining != previousRemaining ||
        input.subscriptionPlan != previousPlan ||
        input.paymentMethod != previousMethod;
    final oldPhone = (playerData?['phone'] as String?)?.trim();
    final oldRecoveryKey = oldPhone == null || oldPhone.isEmpty
        ? null
        : _phoneKey(_normalizePhone(oldPhone));
    final newRecoveryKey = _phoneKey(recoveryPhone);
    if (oldRecoveryKey != newRecoveryKey) {
      final existingRecovery = await recoveryRef.get();
      if (existingRecovery.exists &&
          existingRecovery.data()?['uid'] != playerUid) {
        throw Exception('This phone number is already registered.');
      }
    }
    if (oldRecoveryKey != null && oldRecoveryKey != newRecoveryKey) {
      batch.delete(
        _firestore.collection('accountRecovery').doc(oldRecoveryKey),
      );
    }

    batch.set(playerRef, {
      'firstName': input.firstName.trim(),
      'lastName': input.lastName.trim(),
      'phone': input.phone.trim(),
      'gymCode': resolvedGymCode,
      'weight': input.weight,
      'height': input.height,
      'bodyFat': input.bodyFat,
      'muscleMass': input.muscleMass,
      'goal': input.goal,
      'gender': input.gender,
      'dateOfBirth': Timestamp.fromDate(input.dateOfBirth),
      'fitnessLevel': input.fitnessLevel,
      'trainingMode': input.trainingMode,
      'assignedCoachUid': playerData?['assignedCoachUid'] ?? currentUser.uid,
      'assignedCoachName': coachName,
      'subscriptionPlan': input.subscriptionPlan,
      'discountAmount': input.discountAmount,
      'paymentMethod': input.paymentMethod,
      'subscriptionStart': Timestamp.fromDate(input.subscriptionStart),
      'subscriptionEnd': Timestamp.fromDate(end),
      'totalAmount': input.totalAmount,
      'amountPaid': input.amountPaid,
      'amountRemaining': amountRemaining,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(memberEmailRef, {
      'role': 'player',
      'status': 'active',
      'firstName': input.firstName.trim(),
      'lastName': input.lastName.trim(),
      'phone': input.phone.trim(),
      'gymCode': resolvedGymCode,
      'assignedCoachUid': playerData?['assignedCoachUid'] ?? currentUser.uid,
      'assignedCoachName': coachName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(memberRef, {
      'uid': playerUid,
      'email': (playerData?['email'] as String? ?? input.email)
          .trim()
          .toLowerCase(),
      'gymId': gymId,
      'gymCode': resolvedGymCode,
      'role': 'player',
      'displayName': displayName,
      'phone': input.phone.trim(),
      'status': 'active',
      'assignedCoachUid': playerData?['assignedCoachUid'] ?? currentUser.uid,
      'assignedCoachName': coachName,
      'subscriptionPlan': input.subscriptionPlan,
      'subscriptionStart': Timestamp.fromDate(input.subscriptionStart),
      'subscriptionEnd': Timestamp.fromDate(end),
      'totalAmount': input.totalAmount,
      'discountAmount': input.discountAmount,
      'amountPaid': input.amountPaid,
      'amountRemaining': amountRemaining,
      'paymentMethod': input.paymentMethod,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(metricsRef, {
      'userId': playerUid,
      'weight': input.weight,
      'height': input.height,
      'bodyFat': input.bodyFat,
      'muscleMass': input.muscleMass,
      'age': _ageFromDate(input.dateOfBirth),
      'dateOfBirth': _dateText(input.dateOfBirth),
      'goal': input.goal,
      'fitnessLevel': input.fitnessLevel,
      'gender': input.gender,
      'trainingMode': input.trainingMode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(recoveryRef, {
      'uid': playerUid,
      'email': (playerData?['email'] as String? ?? input.email)
          .trim()
          .toLowerCase(),
      'phone': recoveryPhone,
      'gymId': gymId,
      'role': 'player',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // Only create a payment record when new money was actually paid (delta > 0).
    // A plan change / total change alone does NOT create a payment entry —
    // that prevents duplicate / phantom payments on every edit.
    if (paidDelta > 0) {
      batch.set(
        paymentRef,
        _paymentHistoryData(
          input: input,
          endDate: end,
          amountRemaining: amountRemaining,
          type: 'payment_update',
          actorUid: currentUser.uid,
          amountOverride: paidDelta, // record only the NEW money, not total
        ),
      );
    }

    await batch.commit();
  }

  int _ageFromDate(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Map<String, dynamic> _paymentHistoryData({
    required AddPlayerInput input,
    required DateTime endDate,
    required double amountRemaining,
    required String type,
    required String actorUid,
    double? amountOverride,
  }) {
    return {
      'type': type,
      'planName': input.subscriptionPlan,
      'amount': amountOverride ?? input.amountPaid,
      'totalAmount': input.totalAmount,
      'discountAmount': input.discountAmount,
      'amountRemaining': amountRemaining,
      'paymentMethod': input.paymentMethod,
      'paymentDate': FieldValue.serverTimestamp(),
      'startDate': Timestamp.fromDate(input.subscriptionStart),
      'endDate': Timestamp.fromDate(endDate),
      'durationDays': endDate.difference(input.subscriptionStart).inDays,
      'createdBy': actorUid,
    };
  }

  // Send a manual alert to a single player.
  // [type] drives the Cloud Function's FCM category and the deep-link route.
  // Common values: 'payment_reminder', 'subscription_alert', 'general'.
  Future<void> sendAlert(
    String targetUid,
    String title,
    String body, {
    String type = 'general',
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final batch = _firestore.batch();

    // Notification doc → triggers onNotificationCreated Cloud Function, which
    // reads the player's fcmToken and sends the FCM push to their device.
    final notifRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .doc();

    batch.set(notifRef, {
      'title': title,
      'body': body,
      'type': type,
      'route': _routeForType(type),
      'read': false,
      'senderId': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Rate-limit stamp so Firestore rules enforce the 5-second cooldown.
    batch.update(_firestore.collection('users').doc(targetUid), {
      'lastNotifAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> sendQuickNotification({
    required List<UserModel> targets,
    required String title,
    required String body,
    required String type,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');
    if (targets.isEmpty) throw Exception('Select at least one player.');

    final currentUserDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final currentUserData = currentUserDoc.data();
    final gymId = (currentUserData?['gymId'] as String?)?.trim();
    if (gymId == null || gymId.isEmpty) {
      throw Exception('Coach is not linked to a gym.');
    }

    final batch = _firestore.batch();
    final historyRef = _firestore.collection('coachNotifications').doc();
    final targetNames = targets.map(_displayName).toList();

    batch.set(historyRef, {
      'gymId': gymId,
      'senderId': currentUser.uid,
      'senderName': _displayName(UserModel.fromMap(currentUserData!)),
      'targetUids': targets.map((player) => player.uid).toList(),
      'targetNames': targetNames,
      'targetCount': targets.length,
      'type': type,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final player in targets) {
      final notificationRef = _firestore
          .collection('users')
          .doc(player.uid)
          .collection('notifications')
          .doc();
      batch.set(notificationRef, {
        'gymId': gymId,
        'title': title,
        'body': body,
        'type': type,
        'route': _routeForType(
          type,
        ), // FCM deep-link: Cloud Function reads this
        'read': false,
        'senderId': currentUser.uid,
        'senderName': _displayName(UserModel.fromMap(currentUserData)),
        'historyId': historyRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Stamp lastNotifAt on the player's user doc so the Firestore security
      // rule can enforce the 5-second notification cooldown per recipient.
      // This prevents a coach from flooding a player with notifications.
      batch.update(_firestore.collection('users').doc(player.uid), {
        'lastNotifAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Stream<List<CoachSentNotification>> getSentNotifications(String? uid) {
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('coachNotifications')
        .where('senderId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => CoachSentNotification.fromMap(doc.id, doc.data()))
              .toList();
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  String _displayName(UserModel user) {
    final name = [user.firstName, user.lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .join(' ');
    if (name.isNotEmpty) return name;
    return user.email.split('@').first;
  }

  // --- Finance & Subscription Methods ---

  Future<void> toggleAccountStatus(String uid, bool isActive) async {
    await _firestore.collection('users').doc(uid).update({
      'isActive': isActive,
    });
  }

  Future<void> renewSubscription({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
    required double totalAmount,
    required double amountPaid,
    required double amountRemaining,
    required String planName,
    required String paymentMethod,
  }) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(uid);

    // Update UserModel
    batch.update(userRef, {
      'subscriptionPlan': planName,
      'subscriptionStart': Timestamp.fromDate(startDate),
      'subscriptionEnd': Timestamp.fromDate(endDate),
      'amountPaid': FieldValue.increment(amountPaid),
      'totalAmount': FieldValue.increment(totalAmount),
      'amountRemaining': FieldValue.increment(amountRemaining),
      'isActive': true, // Activate if suspended
    });

    // Add Payment History Record
    final paymentRef = userRef.collection('payments').doc();
    batch.set(paymentRef, {
      'type': 'renewal',
      'planName': planName,
      'amount': amountPaid,
      'totalAmount': totalAmount,
      'discountAmount': 0.0,
      'amountRemaining': amountRemaining,
      'paymentMethod': paymentMethod,
      'paymentDate': FieldValue.serverTimestamp(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'durationDays': endDate.difference(startDate).inDays,
    });

    await batch.commit();
  }

  Stream<List<PaymentRecord>> getPaymentHistory(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('payments')
        .orderBy('paymentDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentRecord.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> deletePaymentRecord(String uid, String paymentId) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('payments')
        .doc(paymentId)
        .delete();
  }

  /// Edit an existing subscription in-place (SET, not increment).
  /// Creates a payment record ONLY if new money was paid (delta > 0).
  /// Safe to call for date/plan/price changes — no phantom records.
  Future<void> editSubscription({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
    required double totalAmount,
    required double amountPaid,
    required String planName,
    required String paymentMethod,
    String gymId = '',
    String coachUid = '',
  }) async {
    // Compute delta vs existing paid amount
    final doc = await _firestore.collection('users').doc(uid).get();
    final previousPaid =
        (doc.data()?['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final paidDelta = amountPaid - previousPaid;
    final remaining =
        (totalAmount - amountPaid).clamp(0.0, double.infinity);

    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(uid);

    // 1. SET subscription fields (replace, not increment)
    batch.update(userRef, {
      'subscriptionPlan': planName,
      'subscriptionStart': Timestamp.fromDate(startDate),
      'subscriptionEnd': Timestamp.fromDate(endDate),
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'amountRemaining': remaining,
      'paymentMethod': paymentMethod,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Payment record only if new money paid
    if (paidDelta > 0) {
      final paymentRef = userRef.collection('payments').doc();
      batch.set(paymentRef, {
        'type': 'payment_update',
        'planName': planName,
        'amount': paidDelta,
        'totalAmount': totalAmount,
        'discountAmount': 0.0,
        'amountRemaining': remaining,
        'paymentMethod': paymentMethod,
        'paymentDate': FieldValue.serverTimestamp(),
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'durationDays': endDate.difference(startDate).inDays,
        if (gymId.isNotEmpty) 'gymId': gymId,
        if (coachUid.isNotEmpty) 'registeredBy': coachUid,
        'playerUid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ── Training Plan ──────────────────────────────────────────────────────────

  /// Saves (or overwrites) a player's split setup from the coach side.
  /// Writes to users/{playerUid}/appData/split_setup — same path the player app reads.
  Future<void> savePlayerSplitSetup({
    required String playerUid,
    required int daysPerWeek,
    required String splitType,
    required List<String> trainingDays,
    required DateTime planStartDate,
  }) async {
    final setupData = {
      'daysPerWeek': daysPerWeek,
      'splitType': splitType,
      'trainingDays': trainingDays,
      'planStartDate': planStartDate.toIso8601String(),
      'swappedDates': <String, String>{},
    };

    await _firestore
        .collection('users')
        .doc(playerUid)
        .collection('appData')
        .doc('split_setup')
        .set({
      'setupData': setupData,
      'isComplete': true,
      'setByCoach': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Reads a player's current split setup. Returns null if not set.
  Future<Map<String, dynamic>?> getPlayerSplitSetup(String playerUid) async {
    final doc = await _firestore
        .collection('users')
        .doc(playerUid)
        .collection('appData')
        .doc('split_setup')
        .get();
    final data = doc.data()?['setupData'];
    return data is Map<String, dynamic> ? data : null;
  }

  /// Maps a notification [type] to its GoRouter deep-link path.
  ///
  /// The Cloud Function (functions/src/index.ts) embeds this in the FCM
  /// message's data payload so the Flutter app can navigate directly to the
  /// relevant screen when the user taps the notification.
  static String _routeForType(String type) {
    switch (type) {
      case 'new_message':
        return '/dashboard'; // player opens dashboard → chat tab visible
      case 'payment_reminder':
        return '/dashboard'; // player sees payment badge on dashboard
      case 'subscription_alert':
        return '/dashboard'; // player sees subscription expiry on dashboard
      case 'feedback':
      case 'workout_plan':
      case 'reminder':
      default:
        return '/dashboard';
    }
  }
}

final coachRepositoryProvider = Provider((ref) => CoachRepository());

final coachMembersProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  final user = ref.watch(currentUserModelProvider).asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(coachRepositoryProvider).getMembers(user.uid, user.gymId);
});

final coachSentNotificationsProvider =
    StreamProvider.autoDispose<List<CoachSentNotification>>((ref) {
      final user = ref.watch(authStateProvider).asData?.value;
      if (user == null) return Stream.value([]);
      return ref.watch(coachRepositoryProvider).getSentNotifications(user.uid);
    });

final coachPaymentsProvider =
    StreamProvider.family<List<PaymentRecord>, String>((ref, uid) {
      return ref.read(coachRepositoryProvider).getPaymentHistory(uid);
    });
