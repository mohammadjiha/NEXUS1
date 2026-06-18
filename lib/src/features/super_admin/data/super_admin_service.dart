import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GymCreationResult {
  final String gymId;
  final String gymName;
  final String adminEmail;
  final String adminPassword;
  final String adminUid;

  const GymCreationResult({
    required this.gymId,
    required this.gymName,
    required this.adminEmail,
    required this.adminPassword,
    required this.adminUid,
  });
}

class SuperAdminService {
  final FirebaseFirestore _db;

  const SuperAdminService(this._db);

  // ── Helpers ──────────────────────────────────────────────────────────────

  String generatePassword() {
    const chars =
        'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789@#!';
    final rng = Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String generateGymId() {
    // 6-digit ID based on timestamp
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    return ts.substring(ts.length - 6);
  }

  // ── Create Firebase Auth user via secondary app ───────────────────────────
  // Uses a secondary FirebaseApp instance so the current super admin session
  // is not affected (createUserWithEmailAndPassword would otherwise sign out
  // the current user on a single app instance).

  Future<String> _createAuthUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    const secondaryName = 'nexus_sa_secondary';
    FirebaseApp secondaryApp;

    try {
      secondaryApp = Firebase.app(secondaryName);
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryName,
        options: Firebase.app().options,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    final credential = await secondaryAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    final uid = credential.user!.uid;
    await secondaryAuth.signOut();
    return uid;
  }

  // ── Main: create a full gym with admin ──────────────────────────────────

  Future<GymCreationResult> createGym({
    required String gymName,
    required String gymCity,
    required String gymId,
    required String adminFirstName,
    required String adminLastName,
    required String adminEmail,
    required String adminPhone,
    required String adminPassword,
    required String superAdminUid,
  }) async {
    final normalizedEmail = adminEmail.trim().toLowerCase();
    final displayName =
        '${adminFirstName.trim()} ${adminLastName.trim()}'.trim();

    // 1. Firebase Auth user (secondary app)
    final uid = await _createAuthUser(
      email: normalizedEmail,
      password: adminPassword,
      displayName: displayName,
    );

    // 2. Gym document
    await _db.collection('gyms').doc(gymId).set({
      'id': gymId,
      'gymCode': gymId,
      'name': gymName.trim(),
      'city': gymCity.trim(),
      'ownerId': uid,
      'ownerEmail': normalizedEmail,
      'createdBy': superAdminUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'plan': 'standard',
    });

    // 3. Admin Firestore user doc
    // emailVerified:true in Firestore so login bypass works (isPrelinkedVerifiedUser)
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': normalizedEmail,
      'firstName': adminFirstName.trim(),
      'lastName': adminLastName.trim(),
      'phone': adminPhone.trim(),
      'gymId': gymId,
      'gymCode': gymId,
      'role': 'owner',
      'isActive': true,
      'emailVerified': true,
      'authProvider': 'password',
      'temporaryPasswordSet': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 4. memberEmails (auth gate for signup)
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('memberEmails')
        .doc(normalizedEmail)
        .set({
      'role': 'owner',
      'status': 'active',
      'firstName': adminFirstName.trim(),
      'lastName': adminLastName.trim(),
      'phone': adminPhone.trim(),
      'addedBy': superAdminUid,
      'addedAt': FieldValue.serverTimestamp(),
    });

    // 5. members
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('members')
        .doc(uid)
        .set({
      'uid': uid,
      'email': normalizedEmail,
      'gymId': gymId,
      'role': 'owner',
      'displayName': displayName,
      'status': 'active',
      'joinedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return GymCreationResult(
      gymId: gymId,
      gymName: gymName.trim(),
      adminEmail: normalizedEmail,
      adminPassword: adminPassword,
      adminUid: uid,
    );
  }

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getGymsStream() {
    return _db
        .collection('gyms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Future<int> getGymMemberCount(String gymId) async {
    final snap =
        await _db.collection('gyms').doc(gymId).collection('members').get();
    return snap.size;
  }

  /// All messages ever sent by Super Admin across all gyms (collectionGroup).
  Stream<List<Map<String, dynamic>>> getSentMessagesStream() {
    return _db
        .collectionGroup('super_admin_messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ── Send message to a gym owner ─────────────────────────────────────────────

  /// Writes to gyms/{gymId}/super_admin_messages AND users/{ownerUid}/notifications
  Future<void> sendMessageToGym({
    required String gymId,
    required String gymName,
    required String ownerUid,
    required String title,
    required String body,
    required String type, // 'info' | 'warning' | 'alert' | 'update'
    required String superAdminUid,
  }) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();

    // 1. Inbox message in gym's super_admin_messages
    final msgRef = _db
        .collection('gyms')
        .doc(gymId)
        .collection('super_admin_messages')
        .doc();
    batch.set(msgRef, {
      'title':          title,
      'body':           body,
      'type':           type,
      'gymId':          gymId,
      'gymName':        gymName,
      'senderUid':      superAdminUid,
      'senderRole':     'super_admin',
      'read':           false,
      'sentAt':         now,
    });

    // 2. Push to owner's notifications subcollection
    if (ownerUid.isNotEmpty) {
      final notifRef = _db
          .collection('users')
          .doc(ownerUid)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'title':     title,
        'body':      body,
        'type':      'super_admin_message',
        'senderId':  superAdminUid,
        'gymId':     gymId,
        'isRead':    false,
        'createdAt': now,
      });
    }

    await batch.commit();
  }

  /// Broadcast to all gyms at once
  Future<void> broadcastToAllGyms({
    required List<Map<String, dynamic>> gyms,
    required String title,
    required String body,
    required String type,
    required String superAdminUid,
  }) async {
    for (final gym in gyms) {
      await sendMessageToGym(
        gymId:         gym['id'] as String? ?? '',
        gymName:       gym['name'] as String? ?? '',
        ownerUid:      gym['ownerId'] as String? ?? '',
        title:         title,
        body:          body,
        type:          type,
        superAdminUid: superAdminUid,
      );
    }
  }
}

final superAdminServiceProvider = Provider<SuperAdminService>(
  (ref) => SuperAdminService(FirebaseFirestore.instance),
);

final allGymsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superAdminServiceProvider).getGymsStream();
});

final superAdminSentMessagesProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(superAdminServiceProvider).getSentMessagesStream();
});

/// Coaches for a specific gym (role == 'coach' AND gymId == gymId)
final gymCoachesStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('gymId', isEqualTo: gymId)
      .where('role', isEqualTo: 'coach')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => {'uid': d.id, ...d.data()})
          .toList());
});

/// Players for a specific gym
final gymPlayersStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('gymId', isEqualTo: gymId)
      .where('role', isEqualTo: 'player')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => {'uid': d.id, ...d.data()})
          .toList());
});
