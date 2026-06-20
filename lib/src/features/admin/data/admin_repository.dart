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
        .map((snap) => snap.docs
            .where((doc) => doc.data()['deleted'] != true) // filter soft-deleted
            .map((doc) {
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
      'senderId': senderUid,
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

  // ── Delete Player ──────────────────────────────────────────────────────────

  /// Permanently deletes a player from Firestore and removes them from the
  /// gym's memberEmails allowlist.
  /// Also sets deleted:true as a soft-delete marker so any cached/stream
  /// queries that filter by that field also stop showing the player.
  Future<void> deletePlayer({
    required String gymId,
    required String playerUid,
    required String playerEmail,
  }) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(playerUid);

    // 1. Mark as deleted first (handles soft-delete case and stream filters)
    batch.update(userRef, {
      'deleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // 2. Remove from gym memberEmails allowlist
    final normalizedEmail = playerEmail.trim().toLowerCase();
    if (normalizedEmail.isNotEmpty) {
      batch.delete(
        _firestore
            .collection('gyms')
            .doc(gymId)
            .collection('memberEmails')
            .doc(normalizedEmail),
      );
    }

    // 3. Remove from gym members sub-collection (if present)
    batch.delete(
      _firestore
          .collection('gyms')
          .doc(gymId)
          .collection('members')
          .doc(playerUid),
    );

    await batch.commit();

    // 4. Hard delete the user document after marking
    await userRef.delete();
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
    double? discount,
    String? paymentMethod,
    double? weight,
    double? height,
    double? muscleMass,
    double? fatPercentage,
  }) async {
    final first = firstName.trim();
    final last  = lastName.trim();
    final now   = DateTime.now();

    // Generate email if missing.
    // Format: firstname.lastname.XXXXXX@gmail.com (all ASCII, readable)
    final normalizedEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim().toLowerCase()
        : _generatePlayerEmail(first, last);

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

    final remaining = (totalAmount ?? 0) - (amountPaid ?? 0);

    // ── 1. Critical: write the user document (must succeed) ───────────────
    await _firestore.collection('users').doc(uid).set({
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
      'temporaryPassword':    password,
      'authProvider':         'password',
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
      if (discount      != null) 'discountAmount': discount,
      if (paymentMethod != null && paymentMethod.trim().isNotEmpty) 'paymentMethod': paymentMethod.trim(),
      if (weight        != null) 'weight':        weight,
      if (height        != null) 'height':        height,
      if (muscleMass    != null) 'muscleMass':    muscleMass,
      if (fatPercentage != null) 'fatPercentage': fatPercentage,
      'createdAt':        Timestamp.fromDate(now),
      'updatedAt':        Timestamp.fromDate(now),
    });

    // ── 1b. Payment record (best-effort) — shows up in finance stream ────
    if ((amountPaid ?? 0) > 0) {
      try {
        await _firestore
            .collection('users').doc(uid)
            .collection('payments').doc()
            .set({
          'type':         'subscription',
          'planName':     subscriptionPlan?.trim().isNotEmpty == true
                              ? subscriptionPlan!.trim() : 'standard',
          'amount':       amountPaid,
          'paymentMethod': paymentMethod?.trim().isNotEmpty == true
                              ? paymentMethod!.trim() : 'cash',
          'paymentDate':  Timestamp.fromDate(now),
          'createdAt':    Timestamp.fromDate(now),
          'gymId':        gymId,
          'playerUid':    uid,
          'playerName':   '$first $last'.trim(),
          'registeredBy': addedByUid,
        });
      } catch (_) { /* non-critical */ }
    }

    // ── 2. Secondary: gym member record (best-effort) ─────────────────────
    try {
      await _firestore
          .collection('gyms').doc(gymId)
          .collection('members').doc(uid)
          .set({
        'uid':        uid,
        'email':      normalizedEmail,
        'role':       'player',
        'gymId':      gymId,
        'firstName':  first,
        'lastName':   last,
        'phone':      phone?.trim() ?? '',
        'status':     'active',
        'joinedAt':   Timestamp.fromDate(now),
      });
    } catch (_) { /* non-critical — user doc already saved */ }

    // ── 3. Secondary: invite allowlist entry (best-effort) ────────────────
    try {
      await _firestore
          .collection('gyms').doc(gymId)
          .collection('memberEmails').doc(normalizedEmail)
          .set({
        'role':       'player',
        'status':     'active',
        'firstName':  first,
        'lastName':   last,
        'phone':      phone?.trim() ?? '',
        'addedBy':    addedByUid,
        'addedAt':    Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    } catch (_) { /* non-critical */ }

    return {'uid': uid, 'email': normalizedEmail, 'password': password};
  }

  /// Smart upsert from a CSV row:
  /// – If a player with this email/phone exists in the gym → update only the
  ///   non-null fields (never clears existing data).
  /// – If no match is found → create a brand-new player account.
  /// Returns a record: (name, wasCreated).
  Future<({String name, bool wasCreated, bool wasUpdated, String uid})> upsertPlayerFromCsv({
    required String gymId,
    required String addedByUid,
    // Identifiers
    String? email,
    String? phone,
    // New-player fields (needed only when creating)
    String? firstName,
    String? lastName,
    // Subscription / payment
    String? subscriptionPlan,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    double? totalAmount,
    double? amountPaid,
    double? discount,
    String? paymentMethod,
    // Physical / extra
    double? weight,
    double? height,
    double? muscleMass,
    double? fatPercentage,
  }) async {
    // ── 1. Try to find existing player ──────────────────────────────────────
    QuerySnapshot? snap;

    if (email != null && email.trim().isNotEmpty) {
      snap = await _firestore
          .collection('users')
          .where('gymId', isEqualTo: gymId)
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
    }

    if ((snap == null || snap.docs.isEmpty) &&
        phone != null && phone.trim().isNotEmpty) {
      // Normalize: digits only, and try with/without leading zero
      final rawPhone    = phone.trim();
      final digitsOnly  = rawPhone.replaceAll(RegExp(r'\D'), '');
      final withZero    = digitsOnly.startsWith('0') ? digitsOnly : '0$digitsOnly';
      final withoutZero = digitsOnly.startsWith('0') ? digitsOnly.substring(1) : digitsOnly;

      for (final candidate in {rawPhone, digitsOnly, withZero, withoutZero}) {
        snap = await _firestore
            .collection('users')
            .where('gymId', isEqualTo: gymId)
            .where('phone', isEqualTo: candidate)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) break;
      }
    }

    // ── Fallback: lookup by full name (covers players with no phone/email) ──
    // Two equality filters (gymId + firstName) — no composite index required.
    // lastName is filtered client-side to avoid a third equality field.
    if ((snap == null || snap.docs.isEmpty) &&
        firstName != null && firstName.trim().isNotEmpty) {
      final first = firstName.trim();
      final last  = (lastName ?? '').trim().toLowerCase();
      final nameSnap = await _firestore
          .collection('users')
          .where('gymId',     isEqualTo: gymId)
          .where('firstName', isEqualTo: first)
          .get();
      final match = nameSnap.docs.where((doc) {
        final d  = doc.data() as Map<String, dynamic>;
        final lg = (d['lastName'] as String? ?? '').trim().toLowerCase();
        return lg == last;
      }).toList();
      if (match.isNotEmpty) {
        snap = nameSnap; // reuse the QuerySnapshot type
        // Replace docs with single match by re-querying by uid
        final uid = match.first.id;
        final docSnap = await _firestore.collection('users').doc(uid).get();
        if (docSnap.exists) {
          // Wrap in a minimal-work approach: just use match.first directly
          final doc  = match.first;
          final data = doc.data() as Map<String, dynamic>;
          final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
          final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
          void maybeSet(String key, dynamic value) { if (value != null) updates[key] = value; }
          maybeSet('subscriptionPlan', subscriptionPlan?.trim().isNotEmpty == true ? subscriptionPlan!.trim() : null);
          if (subscriptionStart != null) updates['subscriptionStart'] = Timestamp.fromDate(subscriptionStart);
          if (subscriptionEnd   != null) updates['subscriptionEnd']   = Timestamp.fromDate(subscriptionEnd);
          maybeSet('totalAmount',     totalAmount);
          maybeSet('discountAmount',  discount);
          maybeSet('paymentMethod',   paymentMethod?.trim().isNotEmpty == true ? paymentMethod!.trim() : null);
          maybeSet('weight',          weight);
          maybeSet('height',          height);
          maybeSet('muscleMass',      muscleMass);
          maybeSet('fatPercentage',   fatPercentage);
          if (amountPaid != null) {
            updates['amountPaid'] = amountPaid;
            final total = totalAmount ?? (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
            final disc  = discount    ?? (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
            final remaining = total - disc - amountPaid;
            updates['amountRemaining'] = remaining < 0 ? 0.0 : remaining;
          }
          final wasUpdated =
            _fieldChanged(subscriptionPlan?.trim().isNotEmpty == true ? subscriptionPlan!.trim() : null, data['subscriptionPlan']) ||
            _fieldChanged(subscriptionStart, data['subscriptionStart']) ||
            _fieldChanged(subscriptionEnd,   data['subscriptionEnd']) ||
            _fieldChanged(totalAmount,       data['totalAmount']) ||
            _fieldChanged(amountPaid,        data['amountPaid']) ||
            _fieldChanged(discount,          data['discountAmount']) ||
            _fieldChanged(paymentMethod?.trim().isNotEmpty == true ? paymentMethod!.trim() : null, data['paymentMethod']) ||
            _fieldChanged(weight,            data['weight']) ||
            _fieldChanged(height,            data['height']) ||
            _fieldChanged(muscleMass,        data['muscleMass']) ||
            _fieldChanged(fatPercentage,     data['fatPercentage']);
          if (wasUpdated && updates.length > 1) {
            await _firestore.collection('users').doc(doc.id).update(updates);
          }
          return (name: name.isEmpty ? first : name, wasCreated: false, wasUpdated: wasUpdated, uid: doc.id);
        }
      }
    }

    // ── 2. Player exists → merge non-null fields ──────────────────────────
    if (snap != null && snap.docs.isNotEmpty) {
      final doc  = snap.docs.first;
      final uid  = doc.id;
      final data = doc.data() as Map<String, dynamic>;
      final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();

      final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

      void maybeSet(String key, dynamic value) {
        if (value != null) updates[key] = value;
      }

      maybeSet('subscriptionPlan', subscriptionPlan?.trim().isNotEmpty == true ? subscriptionPlan!.trim() : null);
      if (subscriptionStart != null) updates['subscriptionStart'] = Timestamp.fromDate(subscriptionStart);
      if (subscriptionEnd   != null) updates['subscriptionEnd']   = Timestamp.fromDate(subscriptionEnd);
      maybeSet('totalAmount',     totalAmount);
      maybeSet('discountAmount',  discount);
      maybeSet('paymentMethod',   paymentMethod?.trim().isNotEmpty == true ? paymentMethod!.trim() : null);
      maybeSet('weight',          weight);
      maybeSet('height',          height);
      maybeSet('muscleMass',      muscleMass);
      maybeSet('fatPercentage',   fatPercentage);

      if (amountPaid != null) {
        updates['amountPaid'] = amountPaid;
        final total = totalAmount ?? (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final disc  = discount    ?? (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
        final remaining = total - disc - amountPaid;
        updates['amountRemaining'] = remaining < 0 ? 0.0 : remaining;
      }

      final wasUpdated =
        _fieldChanged(subscriptionPlan?.trim().isNotEmpty == true ? subscriptionPlan!.trim() : null, data['subscriptionPlan']) ||
        _fieldChanged(subscriptionStart, data['subscriptionStart']) ||
        _fieldChanged(subscriptionEnd,   data['subscriptionEnd']) ||
        _fieldChanged(totalAmount,       data['totalAmount']) ||
        _fieldChanged(amountPaid,        data['amountPaid']) ||
        _fieldChanged(discount,          data['discountAmount']) ||
        _fieldChanged(paymentMethod?.trim().isNotEmpty == true ? paymentMethod!.trim() : null, data['paymentMethod']) ||
        _fieldChanged(weight,            data['weight']) ||
        _fieldChanged(height,            data['height']) ||
        _fieldChanged(muscleMass,        data['muscleMass']) ||
        _fieldChanged(fatPercentage,     data['fatPercentage']);
      if (wasUpdated && updates.length > 1) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
      return (name: name.isEmpty ? (email ?? phone ?? '?') : name, wasCreated: false, wasUpdated: wasUpdated, uid: uid);
    }

    // ── 3. Player not found → create new ─────────────────────────────────
    final first = (firstName ?? '').trim();
    final last  = (lastName  ?? '').trim();
    if (first.isEmpty) {
      throw Exception('لاعب غير موجود ولا يوجد اسم لإضافته (email: $email)');
    }

    final res = await importPlayer(
      gymId: gymId,
      addedByUid: addedByUid,
      firstName: first,
      lastName:  last,
      email:     email,
      phone:     phone,
      subscriptionPlan:  subscriptionPlan,
      subscriptionStart: subscriptionStart,
      subscriptionEnd:   subscriptionEnd,
      totalAmount:   totalAmount ?? 0,
      amountPaid:    amountPaid  ?? 0,
      discount:      discount,
      paymentMethod: paymentMethod,
      weight:        weight,
      height:        height,
      muscleMass:    muscleMass,
      fatPercentage: fatPercentage,
    );
    return (name: '$first $last'.trim(), wasCreated: true, wasUpdated: true, uid: res['uid'] ?? '');
  }

  /// Read-only lookup — checks if a player exists without writing anything.
  /// Returns (exists, uid, existingName).
  Future<({bool exists, String uid, String existingName})> checkPlayerExists({
    required String gymId,
    String? email,
    String? phone,
    String? firstName,
    String? lastName,
  }) async {
    QuerySnapshot? snap;

    if (email != null && email.trim().isNotEmpty) {
      snap = await _firestore
          .collection('users')
          .where('gymId',  isEqualTo: gymId)
          .where('email',  isEqualTo: email.trim().toLowerCase())
          .limit(1).get();
    }

    if ((snap == null || snap.docs.isEmpty) &&
        phone != null && phone.trim().isNotEmpty) {
      final raw     = phone.trim();
      final digits  = raw.replaceAll(RegExp(r'\D'), '');
      final withZ   = digits.startsWith('0') ? digits : '0$digits';
      final withoutZ = digits.startsWith('0') ? digits.substring(1) : digits;
      for (final c in {raw, digits, withZ, withoutZ}) {
        snap = await _firestore.collection('users')
            .where('gymId',  isEqualTo: gymId)
            .where('phone',  isEqualTo: c)
            .limit(1).get();
        if (snap.docs.isNotEmpty) break;
      }
    }

    // Name fallback: gymId + firstName (two equality filters, no composite index).
    // lastName is filtered client-side.
    if ((snap == null || snap.docs.isEmpty) &&
        firstName != null && firstName.trim().isNotEmpty) {
      final first  = firstName.trim();
      final last   = (lastName ?? '').trim().toLowerCase();
      final nSnap  = await _firestore.collection('users')
          .where('gymId',     isEqualTo: gymId)
          .where('firstName', isEqualTo: first)
          .get();
      final match = nSnap.docs.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return (d['lastName'] as String? ?? '').trim().toLowerCase() == last;
      }).toList();
      if (match.isNotEmpty) {
        final doc = match.first;
        final d   = doc.data() as Map<String, dynamic>;
        return (
          exists:       true,
          uid:          doc.id,
          existingName: '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
        );
      }
    }

    if (snap != null && snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final d   = doc.data() as Map<String, dynamic>;
      return (
        exists:       true,
        uid:          doc.id,
        existingName: '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim(),
      );
    }
    return (exists: false, uid: '', existingName: '');
  }

  /// Manually update arbitrary fields on a player document.
  Future<void> updatePlayerFields(String uid, Map<String, dynamic> fields) async {
    await _firestore.collection('users').doc(uid).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns duplicate groups (same full name, ≥2 records) without deleting.
  /// Each entry: { 'name': String, 'docs': List<Map> } where each doc map has
  /// id, firstName, lastName, phone, email, subscriptionPlan, updatedAt.
  Future<List<Map<String, dynamic>>> getDuplicateGroups(String gymId) async {
    final snap = await _firestore
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .where('role',  isEqualTo: 'player')
        .get();

    final byName = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in snap.docs) {
      final d     = doc.data() as Map<String, dynamic>;
      final first = (d['firstName'] ?? '').toString().trim();
      final last  = (d['lastName']  ?? '').toString().trim();
      final key   = '$first $last'.trim().toLowerCase();
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => []).add(doc);
    }

    final groups = <Map<String, dynamic>>[];
    for (final entry in byName.entries) {
      if (entry.value.length < 2) continue;
      // Sort newest first
      int ts(QueryDocumentSnapshot d) {
        final m = d.data() as Map<String, dynamic>;
        return ((m['updatedAt'] ?? m['createdAt']) as Timestamp?)
                ?.millisecondsSinceEpoch ?? 0;
      }
      entry.value.sort((a, b) => ts(b).compareTo(ts(a)));

      final docs = entry.value.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return {
          'id':               doc.id,
          'firstName':        d['firstName'] ?? '',
          'lastName':         d['lastName']  ?? '',
          'phone':            d['phone']     ?? '',
          'email':            d['email']     ?? '',
          'subscriptionPlan': d['subscriptionPlan'] ?? '',
          'updatedAt':        d['updatedAt'] ?? d['createdAt'],
        };
      }).toList();

      groups.add({
        'name': '${entry.value.first.get('firstName')} ${entry.value.first.get('lastName')}'.trim(),
        'count': entry.value.length,
        'docs':  docs,
      });
    }
    return groups;
  }

  /// Deduplicates players by name: keeps the newest record (most recently
  /// created/updated) and merges any non-null fields from the older duplicates
  /// into it, then deletes the older duplicates.
  /// Returns the number of documents deleted.
  Future<int> deduplicatePlayers(String gymId) async {
    final snap = await _firestore
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .where('role',  isEqualTo: 'player')
        .get();

    // Group docs by normalised full name
    final byName = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in snap.docs) {
      final d     = doc.data() as Map<String, dynamic>;
      final first = (d['firstName'] ?? '').toString().trim();
      final last  = (d['lastName']  ?? '').toString().trim();
      final key   = '$first $last'.trim().toLowerCase();
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => []).add(doc);
    }

    int deleted = 0;

    for (final group in byName.values) {
      if (group.length < 2) continue;

      // Sort newest first (by updatedAt, then createdAt)
      int ts(QueryDocumentSnapshot d) {
        final m = d.data() as Map<String, dynamic>;
        return ((m['updatedAt'] ?? m['createdAt']) as Timestamp?)
                ?.millisecondsSinceEpoch ??
            0;
      }
      group.sort((a, b) => ts(b).compareTo(ts(a)));

      final keeper     = group.first;
      final keeperData = Map<String, dynamic>.from(
          keeper.data() as Map<String, dynamic>);

      // Merge non-null fields from older records that the keeper is missing
      for (final old in group.skip(1)) {
        final oldData = old.data() as Map<String, dynamic>;
        for (final e in oldData.entries) {
          final v = e.value;
          if (v == null) continue;
          if (v is String && v.isEmpty) continue;
          // Only fill in fields the keeper doesn't have
          if (keeperData[e.key] == null ||
              (keeperData[e.key] is String &&
                  (keeperData[e.key] as String).isEmpty)) {
            keeperData[e.key] = v;
          }
        }
      }

      // Persist merged data
      keeperData['uid'] = keeper.id;
      await _firestore
          .collection('users')
          .doc(keeper.id)
          .set(keeperData);

      // Delete older duplicates
      for (final old in group.skip(1)) {
        await _firestore.collection('users').doc(old.id).delete();
        deleted++;
      }
    }

    return deleted;
  }

  /// Update an existing player's subscription/payment data from a CSV row.
  /// Looks up the player by email (falls back to phone).
  /// Returns the player's name if found, throws if not found.
  Future<String> updatePlayerFromCsv({
    required String gymId,
    required String email,
    String? phone,
    String? subscriptionPlan,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    double? totalAmount,
    double? amountPaid,
    double? discount,
    String? paymentMethod,
  }) async {
    // Find player by email in this gym
    QuerySnapshot snap = await _firestore
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();

    // Fallback: search by phone
    if (snap.docs.isEmpty && phone != null && phone.trim().isNotEmpty) {
      snap = await _firestore
          .collection('users')
          .where('gymId', isEqualTo: gymId)
          .where('phone', isEqualTo: phone.trim())
          .limit(1)
          .get();
    }

    if (snap.docs.isEmpty) {
      throw Exception('لم يُعثر على لاعب بهذا الإيميل أو الرقم');
    }

    final doc  = snap.docs.first;
    final uid  = doc.id;
    final data = doc.data() as Map<String, dynamic>;
    final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();

    final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

    if (subscriptionPlan != null && subscriptionPlan.trim().isNotEmpty) {
      updates['subscriptionPlan'] = subscriptionPlan.trim();
    }
    if (subscriptionStart != null) {
      updates['subscriptionStart'] = Timestamp.fromDate(subscriptionStart);
    }
    if (subscriptionEnd != null) {
      updates['subscriptionEnd'] = Timestamp.fromDate(subscriptionEnd);
    }
    if (totalAmount != null) {
      updates['totalAmount'] = totalAmount;
    }
    if (amountPaid != null) {
      updates['amountPaid'] = amountPaid;
      final total = totalAmount ?? (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final disc  = discount   ?? (data['discountAmount'] as num?)?.toDouble() ?? 0.0;
      final remaining = total - disc - amountPaid;
      updates['amountRemaining'] = remaining < 0 ? 0.0 : remaining;
    }
    if (discount != null) {
      updates['discountAmount'] = discount;
    }
    if (paymentMethod != null && paymentMethod.trim().isNotEmpty) {
      updates['paymentMethod'] = paymentMethod.trim();
    }

    await _firestore.collection('users').doc(uid).update(updates);
    return name;
  }

  /// Returns true if the CSV [csv] value meaningfully differs from [stored].
  /// Returns false when [csv] is null (field not in CSV → don't touch it).
  bool _fieldChanged(dynamic csv, dynamic stored) {
    if (csv == null) return false;
    if (stored == null) return true;
    if (csv is double && stored is num) return (csv - stored.toDouble()).abs() > 0.01;
    if (csv is DateTime && stored is Timestamp) {
      final d = stored.toDate();
      return csv.year != d.year || csv.month != d.month || csv.day != d.day;
    }
    if (csv is String && stored is String) return csv.trim() != stored.trim();
    return csv != stored;
  }

  // ── Email generation ─────────────────────────────────────────────────────
  static const _arabicMap = {
    'ا': 'a', 'أ': 'a', 'إ': 'a', 'آ': 'a',
    'ب': 'b', 'ت': 't', 'ث': 'th',
    'ج': 'j', 'ح': 'h', 'خ': 'kh',
    'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z',
    'س': 's', 'ش': 'sh', 'ص': 's', 'ض': 'd',
    'ط': 't', 'ظ': 'z', 'ع': 'a', 'غ': 'gh',
    'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l',
    'م': 'm', 'ن': 'n', 'ه': 'h', 'و': 'w',
    'ي': 'y', 'ى': 'a', 'ة': 'h', 'ئ': 'y',
    'ء': '', 'ؤ': 'w', 'لا': 'la', 'ال': 'al',
  };

  /// Converts Arabic (or mixed) name part to lowercase ASCII letters only.
  String _transliterate(String input) {
    // Strip Arabic diacritics (tashkeel) and tatweel before processing
    final stripped = input.replaceAll(
      RegExp(r'[ؐ-ًؚ-ٰٟـ]'),
      '',
    );

    final buf = StringBuffer();
    for (var i = 0; i < stripped.length; i++) {
      final ch = stripped[i];
      // Check two-char sequence first (لا, ال)
      if (i + 1 < stripped.length) {
        final two = stripped.substring(i, i + 2);
        if (_arabicMap.containsKey(two)) {
          buf.write(_arabicMap[two]);
          i++;
          continue;
        }
      }
      if (_arabicMap.containsKey(ch)) {
        buf.write(_arabicMap[ch]);
      } else if (RegExp(r'[a-zA-Z]').hasMatch(ch)) {
        buf.write(ch.toLowerCase());
      }
      // skip spaces, digits, symbols, unknown chars
    }
    final result = buf.toString().replaceAll(RegExp(r'[^a-z]'), '');
    return result.isEmpty ? 'player' : result;
  }

  /// Generates a unique-ish email: firstname.lastname.XXXXXX@gmail.com
  String _generatePlayerEmail(String firstName, String lastName) {
    final f    = _transliterate(firstName);
    final l    = _transliterate(lastName);
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final seed  = DateTime.now().microsecondsSinceEpoch;
    final rand  = List.generate(6, (i) => chars[(seed + i * 7919) % chars.length]).join();
    final local = [f, l, rand].where((s) => s.isNotEmpty).join('.');
    return '$local@gmail.com';
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

  // ── Backfill payment records for existing players ─────────────────────────
  /// For every player who has amountPaid > 0 but no payment record yet,
  /// creates a single payment record so the finance view shows correct revenue.
  Future<Map<String, int>> backfillPaymentRecords(String gymId) async {
    // 1. Get all players
    final playersSnap = await _firestore
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .where('role',  isEqualTo: 'player')
        .get();

    int created = 0, skipped = 0;

    for (final playerDoc in playersSnap.docs) {
      final data      = playerDoc.data() as Map<String, dynamic>;
      final amountPaid = (data['amountPaid'] as num?)?.toDouble() ?? 0;
      if (amountPaid <= 0) { skipped++; continue; }

      // 2. Check if payment record already exists
      final existing = await _firestore
          .collection('users')
          .doc(playerDoc.id)
          .collection('payments')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) { skipped++; continue; }

      // 3. Create backfill record
      final createdAt = (data['createdAt'] as Timestamp?) ?? Timestamp.now();
      final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
      try {
        await _firestore
            .collection('users')
            .doc(playerDoc.id)
            .collection('payments')
            .doc()
            .set({
          'type':         'subscription',
          'planName':     data['subscriptionPlan'] ?? 'standard',
          'amount':       amountPaid,
          'paymentMethod': data['paymentMethod'] ?? 'cash',
          'paymentDate':  createdAt,
          'createdAt':    createdAt,
          'gymId':        gymId,
          'playerUid':    playerDoc.id,
          'playerName':   name,
          'registeredBy': data['addedBy'] ?? '',
          'isBackfill':   true,
        });
        created++;
      } catch (_) { skipped++; }
    }

    return {'created': created, 'skipped': skipped};
  }

  // ── Migrate old .nexus emails → firstname.lastname.XXXX@gmail.com ─────────
  /// Returns a summary: { migrated, skipped, failed }
  Future<Map<String, int>> migratePlayerEmails(String gymId) async {
    final snap = await _firestore
        .collection('users')
        .where('gymId', isEqualTo: gymId)
        .where('role',  isEqualTo: 'player')
        .get();

    int migrated = 0, skipped = 0, failed = 0;

    for (final doc in snap.docs) {
      final data       = doc.data() as Map<String, dynamic>;
      final oldEmail   = (data['email'] as String? ?? '').trim().toLowerCase();
      final firstName  = (data['firstName'] as String? ?? '').trim();
      final lastName   = (data['lastName']  as String? ?? '').trim();

      // Migrate if: .nexus domain, timestamp-based, or contains non-ASCII (Arabic) chars
      final hasArabic = RegExp(r'[؀-ۿ]').hasMatch(oldEmail);
      final isAutoGenerated = oldEmail.contains('.nexus') ||
          RegExp(r'^u\d{10,}@').hasMatch(oldEmail) ||
          RegExp(r'^p09\d+@').hasMatch(oldEmail) ||
          hasArabic;
      if (!isAutoGenerated) {
        skipped++;
        continue;
      }

      final newEmail = _generatePlayerEmail(firstName, lastName);

      try {
        // Update Firestore display email only.
        // Firebase Auth email stays the same (login still works with old email).
        await _firestore.collection('users').doc(doc.id).update({
          'email':     newEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update memberEmails allowlist
        try {
          final gymRef = _firestore.collection('gyms').doc(gymId);
          await gymRef.collection('memberEmails').doc(oldEmail).delete();
          await gymRef.collection('memberEmails').doc(newEmail).set({
            'role':      'player',
            'status':    'active',
            'firstName': firstName,
            'lastName':  lastName,
            'phone':     data['phone'] ?? '',
            'addedAt':   FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          await gymRef.collection('members').doc(doc.id)
              .update({'email': newEmail});
        } catch (_) { /* best-effort */ }

        migrated++;
      } catch (e) {
        failed++;
      }
    }

    return {'migrated': migrated, 'skipped': skipped, 'failed': failed};
  }

  // ── Import History ───────────────────────────────────────────────────────────

  /// Saves a summary record after each CSV/Excel import.
  Future<void> saveImportHistory({
    required String gymId,
    required String addedByUid,
    required String fileName,
    required int newCount,
    required int updatedCount,
    required int existingCount,
    required int failedCount,
  }) async {
    await _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('importHistory')
        .add({
      'gymId':        gymId,
      'addedByUid':   addedByUid,
      'fileName':     fileName,
      'uploadedAt':   FieldValue.serverTimestamp(),
      'newCount':     newCount,
      'updatedCount': updatedCount,
      'existingCount':existingCount,
      'failedCount':  failedCount,
      'totalCount':   newCount + updatedCount + existingCount + failedCount,
    });
  }

  /// Streams the 20 most recent import history records for this gym.
  Stream<List<ImportHistoryEntry>> getImportHistoryStream(String gymId) {
    return _firestore
        .collection('gyms')
        .doc(gymId)
        .collection('importHistory')
        .orderBy('uploadedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ImportHistoryEntry.fromFirestore(d))
            .toList());
  }
}

// ─── Import History Model ─────────────────────────────────────────────────────

class ImportHistoryEntry {
  final String id;
  final String fileName;
  final DateTime uploadedAt;
  final String addedByUid;
  final int newCount;
  final int updatedCount;
  final int existingCount;
  final int failedCount;
  final int totalCount;

  const ImportHistoryEntry({
    required this.id,
    required this.fileName,
    required this.uploadedAt,
    required this.addedByUid,
    required this.newCount,
    required this.updatedCount,
    required this.existingCount,
    required this.failedCount,
    required this.totalCount,
  });

  factory ImportHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['uploadedAt'] as Timestamp?;
    return ImportHistoryEntry(
      id:            doc.id,
      fileName:      d['fileName']      as String? ?? '—',
      uploadedAt:    ts?.toDate()       ?? DateTime.now(),
      addedByUid:    d['addedByUid']    as String? ?? '',
      newCount:      (d['newCount']     as num?)?.toInt() ?? 0,
      updatedCount:  (d['updatedCount'] as num?)?.toInt() ?? 0,
      existingCount: (d['existingCount'] as num?)?.toInt() ?? 0,
      failedCount:   (d['failedCount']  as num?)?.toInt() ?? 0,
      totalCount:    (d['totalCount']   as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final adminRepositoryProvider = Provider((ref) => AdminRepository());

final adminPlayersProvider =
    StreamProvider.family<List<UserModel>, String>((ref, gymId) {
  return ref.watc