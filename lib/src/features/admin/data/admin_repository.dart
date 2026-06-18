import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/models/user_model.dart';

// ─── Payment Record ───────────────────────────────────────────────────────────

class PaymentRecord {
  final String id;
  final String type;
  final String planName;
  final double amount;
  final String paymentMethod;
  final DateTime date;
  final String playerName;
  final String playerId;

  PaymentRecord({
    required this.id,
    required this.type,
    required this.planName,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    required this.playerName,
    required this.playerId,
  });

  /// Used when fetching per-user subcollection (legacy path).
  factory PaymentRecord.fromFirestore(
      DocumentSnapshot doc, String playerName, String playerId) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = (data['paymentDate'] ?? data['createdAt']) as Timestamp?;
    return PaymentRecord(
      id: doc.id,
      type: data['type'] as String? ?? 'subscription',
      planName: data['planName'] as String? ?? 'Custom',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      date: ts?.toDate() ?? DateTime.now(),
      playerName: playerName,
      playerId: playerId,
    );
  }

  /// Used when fetching via collectionGroup — playerUid and playerName
  /// are embedded directly in the payment document.
  factory PaymentRecord.fromFirestoreGroup(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = (data['paymentDate'] ?? data['createdAt']) as Timestamp?;
    // Derive playerUid from the document path: users/{uid}/payments/{paymentId}
    final playerUid = doc.reference.parent.parent?.id ?? '';
    return PaymentRecord(
      id: doc.id,
      type: data['type'] as String? ?? 'subscription',
      planName: data['planName'] as String? ?? 'Custom',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      date: ts?.toDate() ?? DateTime.now(),
      playerName: data['playerName'] as String? ?? '',
      playerId: data['playerUid'] as String? ?? playerUid,
    );
  }
}

// ─── Admin Repository ─────────────────────────────────────────────────────────

class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Gym Settings ──────────────────────────────────────────────────────────

  /// Reads the gym document fields shown in Gym Settings.
  Future<Map<String, dynamic>> getGymSettings(String gymId) async {
    final doc = await _firestore.collection('gyms').doc(gymId).get();
    return doc.data() ?? {};
  }

  /// Updates editable gym fields (name, city, phone).
  Future<void> updateGymSettings({
    required String gymId,
    required String gymName,
    required String gymCity,
    String phone = '',
    String address = '',
  }) async {
    await _firestore.collection('gyms').doc(gymId).update({
      'gymName': gymName.trim(),
      'gymCity': gymCity.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Invite management ──────────────────────────────────────────────────────

  /// Real-time stream of all invited emails for the gym.
  Stream<List<Map<String, dynamic>>> getMemberEmailsStream(String gymId) {
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('memberEmails')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              data['email'] = d.id; // doc id IS the email
              return data;
            }).toList());
  }

  /// Removes an invite entry (revokes access for unsigned-up users).
  Future<void> removeInvite({
    required String gymId,
    required String email,
  }) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('memberEmails')
        .doc(email.trim().toLowerCase())
        .delete();
  }

  // ── Invitation ────────────────────────────────────────────────────────────

  /// Adds a pre-registration entry so the user can sign up.
  /// Writes to gyms/{gymId}/memberEmails/{email} — the auth gate checked on login.
  Future<void> inviteMember({
    required String gymId,
    required String email,
    required String role,
    String? firstName,
    String? lastName,
    String? phone,
    String? notes,
    required String addedByUid,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final batch = _firestore.batch();

    final emailRef = _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('memberEmails')
        .doc(normalizedEmail);

    batch.set(emailRef, {
      'role': role,
      'status': 'active',
      'firstName': firstName?.trim() ?? '',
      'lastName': lastName?.trim() ?? '',
      'phone': phone?.trim() ?? '',
      'notes': notes?.trim() ?? '',
      'addedBy': addedByUid,
      'addedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ── Coach management ──────────────────────────────────────────────────────

  /// Update a coach's basic profile fields.
  Future<void> updateCoachInfo({
    required String gymId,
    required String coachUid,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final displayName = '${firstName.trim()} ${lastName.trim()}'.trim();
    final batch = _firestore.batch();

    // 1. Top-level user doc
    batch.update(_firestore.collection('users').doc(coachUid), {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Gym members subcollection
    batch.update(
      _firestore.collection('gyms').doc(gymId).collection('members').doc(coachUid),
      {
        'displayName': displayName,
        'phone': phone.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  // ── Players / Coaches ─────────────────────────────────────────────────────

  /// Real-time stream of all players in the gym.
  Stream<List<UserModel>> getPlayersStream(String gymId) {
    return _firestore
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .where('role', isEqualTo: 'player')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return UserModel.fromMap(data);
            }).toList());
  }

  /// Real-time stream of all coaches in the gym.
  Stream<List<UserModel>> getCoachesStream(String gymId) {
    return _firestore
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .where('role', isEqualTo: 'coach')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return UserModel.fromMap(data);
            }).toList());
  }

  // ── Player management ──────────────────────────────────────────────────────

  /// Suspend or reactivate a player.
  /// Writes to BOTH users/{uid} AND gyms/{gymId}/members/{uid} so both
  /// sources stay in sync.
  Future<void> updatePlayerStatus({
    required String gymId,
    required String uid,
    required bool isActive,
  }) async {
    final status = isActive ? 'active' : 'suspended';
    final batch = _firestore.batch();

    // 1. Top-level user document
    batch.update(_firestore.collection('users').doc(uid), {
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Gym members subcollection
    batch.update(
      _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(uid),
      {'status': status, 'updatedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  /// Change a member's role.
  /// Syncs to BOTH users/{uid}.role AND gyms/{gymId}/members/{uid}.role.
  Future<void> updateMemberRole({
    required String gymId,
    required String uid,
    required String role,
  }) async {
    final batch = _firestore.batch();

    // 1. Top-level user document
    batch.update(_firestore.collection('users').doc(uid), {
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Gym members subcollection
    batch.update(
      _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(uid),
      {'role': role, 'updatedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  /// Assign a coach to a player.
  /// Syncs to BOTH users/{playerUid} AND gyms/{gymId}/members/{playerUid}.
  Future<void> assignCoachToPlayer({
    required String playerUid,
    required String coachUid,
    required String coachName,
    required String gymId,
  }) async {
    final batch = _firestore.batch();
    final update = {
      'assignedCoachUid': coachUid,
      'assignedCoachName': coachName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.update(_firestore.collection('users').doc(playerUid), update);
    batch.update(
      _firestore.collection('gyms').doc(gymId).collection('members').doc(playerUid),
      update,
    );
    await batch.commit();
  }

  /// Remove coach assignment from a player.
  /// Syncs to BOTH users/{playerUid} AND gyms/{gymId}/members/{playerUid}.
  Future<void> removeCoachFromPlayer({
    required String playerUid,
    required String gymId,
  }) async {
    final batch = _firestore.batch();
    final update = {
      'assignedCoachUid': FieldValue.delete(),
      'assignedCoachName': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.update(_firestore.collection('users').doc(playerUid), update);
    batch.update(
      _firestore.collection('gyms').doc(gymId).collection('members').doc(playerUid),
      update,
    );
    await batch.commit();
  }

  /// Update a player's subscription details.
  /// If [amountPaid] > 0 and [gymId] + [playerName] + [registeredByUid] are
  /// supplied, also writes a payment record so Finance history stays accurate.
  Future<void> updatePlayerSubscription({
    required String playerUid,
    required String plan,
    required DateTime startDate,
    required DateTime endDate,
    required double totalAmount,
    required double amountPaid,
    required String paymentMethod,
    // Optional — needed to write the payment history entry
    String gymId = '',
    String playerName = '',
    String registeredByUid = '',
  }) async {
    final remaining = (totalAmount - amountPaid).clamp(0.0, double.infinity);

    final batch = _firestore.batch();

    // 1. Update the user's subscription fields
    batch.update(_firestore.collection('users').doc(playerUid), {
      'subscriptionPlan': plan,
      'subscriptionStart': Timestamp.fromDate(startDate),
      'subscriptionEnd': Timestamp.fromDate(endDate),
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'amountRemaining': remaining,
      'paymentMethod': paymentMethod,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Write a payment history record if we have enough context and there's
    //    an amount to record.
    if (amountPaid > 0 && gymId.isNotEmpty && registeredByUid.isNotEmpty) {
      final paymentRef = _firestore
          .collection('users')
          .doc(playerUid)
          .collection('payments')
          .doc();
      batch.set(paymentRef, {
        'type': 'subscription',
        'planName': plan,
        'amount': amountPaid,
        'paymentMethod': paymentMethod,
        'paymentDate': FieldValue.serverTimestamp(),
        'registeredBy': registeredByUid,
        // Fields required for collectionGroup filtering & display
        'gymId': gymId,
        'playerUid': playerUid,
        'playerName': playerName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ── Payments ───────────────────────────────────────────────────────────────

  /// Real-time stream of all payments for the gym using a single
  /// collectionGroup query — replaces the old N+1 getAllPayments() approach.
  ///
  /// Requires payment documents to carry a `gymId` field. Documents written
  /// before this change won't have `gymId` and therefore won't appear here;
  /// use the one-time migration helper or rely on addPaymentRecord going
  /// forward which always writes the field.
  Stream<List<PaymentRecord>> getPaymentsStream(String gymId) {
    return _firestore
        .collectionGroup('payments')
        .where('gymId', isEqualTo: gymId)
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map((snap) =>
            snap.docs.map(PaymentRecord.fromFirestoreGroup).toList());
  }

  /// Record a new payment for a player.
  /// Writes to users/{uid}/payments (with gymId + playerName for collectionGroup
  /// queries) AND updates amountPaid/amountRemaining — all in one batch.
  Future<void> addPaymentRecord({
    required String playerUid,
    required String gymId,
    required String playerName,
    required double amount,
    required String planName,
    required String paymentMethod,
    required String registeredByUid,
    // Optional: pass current totals to recalculate remaining
    double currentAmountPaid = 0.0,
    double totalAmount = 0.0,
  }) async {
    final paymentRef = _firestore
        .collection('users')
        .doc(playerUid)
        .collection('payments')
        .doc();

    final newAmountPaid = currentAmountPaid + amount;
    final newRemaining =
        (totalAmount - newAmountPaid).clamp(0.0, double.infinity);

    final batch = _firestore.batch();

    // 1. New payment document — includes gymId + playerName so it's
    //    visible in collectionGroup queries filtered by gym.
    batch.set(paymentRef, {
      'type': 'subscription',
      'planName': planName,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'paymentDate': FieldValue.serverTimestamp(),
      'registeredBy': registeredByUid,
      // Fields required for collectionGroup filtering & display
      'gymId': gymId,
      'playerUid': playerUid,
      'playerName': playerName,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update player's running totals
    batch.update(_firestore.collection('users').doc(playerUid), {
      'amountPaid': newAmountPaid,
      'amountRemaining': newRemaining,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  /// Admin broadcasts a notification — written to gyms/{gymId}/admin_notifications.
  /// A Cloud Function should fan-out to FCM / users/{uid}/notifications.
  Future<void> sendNotification({
    required String gymId,
    required String title,
    required String body,
    required String type,
    required List<String> targetGroups,
    required String adminUid,
  }) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('admin_notifications')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'targetGroups': targetGroups,
      'sentBy': adminUid,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  /// Also writes a notification directly to users/{uid}/notifications
  /// so the player sees it in-app without needing a Cloud Function.
  Future<void> sendDirectNotificationToUser({
    required String targetUid,
    required String title,
    required String body,
    required String type,
    required String senderUid,
  }) async {
    final batch = _firestore.batch();

    // Write the notification document
    final notifRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('notifications')
        .doc();
    batch.set(notifRef, {
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'sentBy': senderUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update lastNotifAt on the user doc so notifCooldownPassed() in
    // Firestore rules actually enforces the rate limit.
    final userRef = _firestore.collection('users').doc(targetUid);
    batch.update(userRef, {
      'lastNotifAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Notification history for the gym.
  Stream<List<Map<String, dynamic>>> getNotificationHistory(String gymId) {
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('admin_notifications')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  // ── Super Admin Messages ───────────────────────────────────────────────────

  /// Messages sent from Super Admin to this gym owner.
  Stream<List<Map<String, dynamic>>> getSuperAdminMessagesStream(String gymId) {
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('super_admin_messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> markSuperAdminMessageRead(String gymId, String msgId) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('super_admin_messages')
        .doc(msgId)
        .update({'read': true});
  }

  // ── Expenses ───────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getExpensesStream(String gymId) {
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> addExpense({
    required String gymId,
    required String category,
    required String description,
    required double amount,
    required DateTime date,
    required String addedByUid,
  }) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('expenses')
        .add({
      'category': category,
      'description': description.trim(),
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'addedBy': addedByUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExpense({
    required String gymId,
    required String expenseId,
  }) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  // ── Subscription Plans ─────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getSubscriptionPlansStream(String gymId) {
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('plans')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  Future<void> addSubscriptionPlan({
    required String gymId,
    required String name,
    required int durationDays,
    required double price,
  }) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('plans')
        .add({
      'name': name.trim(),
      'durationDays': durationDays,
      'price': price,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSubscriptionPlan({
    required String gymId,
    required String planId,
    required String name,
    required int durationDays,
    required double price,
  }) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('plans')
        .doc(planId)
        .update({
      'name': name.trim(),
      'durationDays': durationDays,
      'price': price,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSubscriptionPlan({
    required String gymId,
    required String planId,
  }) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('plans')
        .doc(planId)
        .delete();
  }

  // ── Check-in ───────────────────────────────────────────────────────────────

  Future<void> checkInPlayer({
    required String gymId,
    required String playerUid,
    required String playerName,
    required String addedByUid,
  }) async {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Prevent duplicate check-in on same day
    final existing = await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('checkins')
        .where('playerUid', isEqualTo: playerUid)
        .where('dateKey', isEqualTo: dateKey)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return; // already checked in today

    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('checkins')
        .add({
      'playerUid': playerUid,
      'playerName': playerName,
      'timestamp': FieldValue.serverTimestamp(),
      'dateKey': dateKey,
      'addedBy': addedByUid,
    });
  }

  Stream<List<Map<String, dynamic>>> getTodayCheckInsStream(String gymId) {
    final now = DateTime.now();
    final dateKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('checkins')
        .where('dateKey', isEqualTo: dateKey)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  // ── Subscription Freeze ────────────────────────────────────────────────────

  /// Freeze a player's subscription — stops the day counter.
  Future<void> freezePlayerSubscription({
    required String gymId,
    required String playerUid,
    required int freezeDays,
    required String reason,
  }) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(playerUid);
    batch.update(userRef, {
      'isFrozen': true,
      'frozenAt': FieldValue.serverTimestamp(),
      'freezeDays': freezeDays,
      'freezeReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Also log in gym members
    final memberRef = _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(playerUid);
    batch.update(memberRef, {
      'isFrozen': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Unfreeze — extends subscriptionEnd by the frozen days.
  Future<void> unfreezePlayerSubscription({
    required String gymId,
    required String playerUid,
    required DateTime currentSubscriptionEnd,
    required int frozenDays,
  }) async {
    final newEnd = currentSubscriptionEnd.add(Duration(days: frozenDays));
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(playerUid);
    batch.update(userRef, {
      'isFrozen': false,
      'frozenAt': FieldValue.delete(),
      'freezeDays': FieldValue.delete(),
      'freezeReason': FieldValue.delete(),
      'subscriptionEnd': Timestamp.fromDate(newEnd),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final memberRef = _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(playerUid);
    batch.update(memberRef, {
      'isFrozen': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // ── Add Coach (full — creates Firebase Auth account immediately) ──────────

  /// Creates a Firebase Auth account for the coach using a secondary Firebase
  /// App (so the admin stays signed in), then writes all Firestore docs atomically.
  /// Returns the new coach's UID.
  Future<String> addCoach({
    required String gymId,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String addedByUid,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final now = DateTime.now();

    // 1. Create Auth account via secondary app so admin stays signed in
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'AddCoachApp_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    late String newUid;
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      newUid = cred.user!.uid;
    } finally {
      await secondaryApp.delete();
    }

    // 2. Write all Firestore docs atomically
    final batch = _firestore.batch();

    // users/{uid}
    batch.set(_firestore.collection('users').doc(newUid), {
      'uid': newUid,
      'email': normalizedEmail,
      'role': 'coach',
      'gymId': gymId,
      'gymCode': gymId,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phone': phone.trim(),
      'isActive': true,
      'emailVerified': true,
      'temporaryPasswordSet': true,
      'authProvider': 'password',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    // gyms/{gymId}/members/{uid}
    batch.set(
      _firestore.collection('gyms').doc(gymId).collection('members').doc(newUid),
      {
        'uid': newUid,
        'email': normalizedEmail,
        'role': 'coach',
        'gymId': gymId,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'status': 'active',
        'joinedAt': Timestamp.fromDate(now),
      },
    );

    // gyms/{gymId}/memberEmails/{email}
    batch.set(
      _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('memberEmails')
          .doc(normalizedEmail),
      {
        'role': 'coach',
        'status': 'active',
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'addedBy': addedByUid,
        'addedAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    // Also patch registeredBy on the user doc
    batch.update(_firestore.collection('users').doc(newUid), {
      'registeredBy': addedByUid,
    });

    // accountRecovery/{phoneKey} — enables phone-based account recovery
    if (phone.trim().isNotEmpty) {
      final normalizedPhone = _normalizePhone(phone.trim());
      final recoveryKey = _phoneKey(normalizedPhone);
      batch.set(
        _firestore.collection('accountRecovery').doc(recoveryKey),
        {
          'uid': newUid,
          'email': normalizedEmail,
          'phone': normalizedPhone,
          'gymId': gymId,
          'role': 'coach',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    return newUid;
  }

  // ── Import Player ─────────────────────────────────────────────────────────
  /// Creates a Firebase Auth account + all Firestore docs for one imported player.
  /// Returns a map with {uid, email, password}.
  Future<Map<String, String>> importPlayer({
    required String gymId,
    required String addedByUid,
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? subscriptionPlan,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    double? totalAmount,
    double? amountPaid,
  }) async {
    final first = firstName.trim();
    final last  = lastName.trim();
    final now   = DateTime.now();

    // Generate email if missing
    final normalizedEmail = email != null && email.trim().isNotEmpty
        ? email.trim().toLowerCase()
        : '${first.toLowerCase().replaceAll(' ', '.')}.${last.toLowerCase().replaceAll(' ', '.')}@$gymId.nexus';

    // Generate random 8-char password
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final rng = List.generate(8, (_) {
      final idx = DateTime.now().microsecondsSinceEpoch % chars.length;
      return chars[idx];
    });
    // Use a simple but varied approach
    final password = List.generate(8, (i) {
      final seed = DateTime.now().microsecondsSinceEpoch + i * 7919;
      return chars[seed % chars.length];
    }).join();

    // Create Auth account via secondary app (admin stays signed in)
    final secondaryApp = await Firebase.initializeApp(
      name: 'ImportPlayer_${DateTime.now().microsecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    late String uid;
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      uid = cred.user!.uid;
    } finally {
      await secondaryApp.delete();
    }

    final batch = _firestore.batch();
    final remaining = (totalAmount ?? 0) - (amountPaid ?? 0);

    // users/{uid}
    batch.set(_firestore.collection('users').doc(uid), {
      'uid':              uid,
      'email':            normalizedEmail,
      'firstName':        first,
      'lastName':         last,
      'phone':            phone?.trim() ?? '',
      'role':             'player',
      'gymId':            gymId,
      'gymCode':          gymId,
      'isActive':         true,
      'emailVerified':    true,
      'temporaryPasswordSet': true,
      'authProvider':     'password',
      'subscriptionPlan': subscriptionPlan?.trim() ?? 'standard',
      'subscriptionStart': subscriptionStart != null
          ? Timestamp.fromDate(subscriptionStart)
          : null,
      'subscriptionEnd':  subscriptionEnd != null
          ? Timestamp.fromDate(subscriptionEnd)
          : null,
      'totalAmount':      totalAmount ?? 0.0,
      'amountPaid':       amountPaid ?? 0.0,
      'amountRemaining':  remaining < 0 ? 0.0 : remaining,
      'createdAt':        Timestamp.fromDate(now),
      'updatedAt':        Timestamp.fromDate(now),
    });

    // gyms/{gymId}/members/{uid}
    batch.set(
      _firestore.collection('gyms').doc(gymId).collection('members').doc(uid),
      {
        'uid':        uid,
        'email':      normalizedEmail,
        'role':       'player',
        'gymId':      gymId,
        'firstName':  first,
        'lastName':   last,
        'phone':      phone?.trim() ?? '',
        'status':     'active',
        'joinedAt':   Timestamp.fromDate(now),
      },
    );

    // gyms/{gymId}/memberEmails/{email}
    batch.set(
      _firestore.collection('gyms').doc(gymId).collection('memberEmails').doc(normalizedEmail),
      {
        'role':       'player',
        'status':     'active',
        'firstName':  first,
        'lastName':   last,
        'phone':      phone?.trim() ?? '',
        'addedBy':    addedByUid,
        'addedAt':    Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    return {'uid': uid, 'email': normalizedEmail, 'password': password};
  }

  String _normalizePhone(String input) {
    var value = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (value.startsWith('+')) return value;
    if (value.startsWith('962')) return '+$value';
    if (value.startsWith('0')) return '+962${value.substring(1)}';
    return '+962$value';
  }

  String _phoneKey(String phone) => phone.replaceAll(RegExp(r'\D'), '');
}

// ─── Providers ────────────────────────────────────────────────────────────────

final adminRepositoryProvider = Provider((ref) => AdminRepository());

final adminPlayersProvider =
    StreamProvider.family<List<UserModel>, String>((ref, gymId) {
  return ref.watch(adminRepositoryProvider).getPlayersStream(gymId);
});

final adminCoachesProvider =
    StreamProvider.family<List<UserModel>, String>((ref, gymId) {
  return ref.watch(adminRepositoryProvider).getCoachesStream(gymId);
});

final adminPaymentsProvider =
    StreamProvider.family<List<PaymentRecord>, String>((ref, gymId) {
  return ref.watch(adminRepositoryProvider).getPaymentsStream(gymId);
});

/// Streams the gym document — provides gymName, city, etc.
final gymInfoProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, gymId) {
  return FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .snapshots()
      .map((doc) => doc.data() ?? {});
});

final adminExpensesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  return ref.watch(adminRepositoryProvider).getExpensesStream(gymId);
});

final subscriptionPlansProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  return ref.watch(adminRepositoryProvider).getSubscriptionPlansStream(gymId);
});

final todayCheckInsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  return ref.watch(adminRepositoryProvider).getTodayCheckInsStream(gymId);
});

final superAdminMessagesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  return ref.watch(adminRepositoryProvider).getSuperAdminMessagesStream(gymId);
});
