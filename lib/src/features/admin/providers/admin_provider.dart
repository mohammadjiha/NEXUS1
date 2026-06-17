import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
// currentUserModelProvider is imported via auth_repository.dart

// ─── Models ─────────────────────────────────────────────────────────────────

class GymMember {
  final String uid;
  final String email;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String role;
  final String status;
  final DateTime? joinedAt;

  const GymMember({
    required this.uid,
    required this.email,
    this.displayName,
    this.firstName,
    this.lastName,
    this.phone,
    this.role = 'player',
    this.status = 'active',
    this.joinedAt,
  });

  String get initials {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) {
      final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  String get fullName => displayName?.trim().isNotEmpty ?? false
      ? displayName!.trim()
      : [firstName, lastName].where((p) => p != null && p.trim().isNotEmpty).join(' ');

  factory GymMember.fromMap(String uid, Map<String, dynamic> data) => GymMember(
    uid: uid,
    email: data['email'] as String? ?? '',
    displayName: data['displayName'] as String?,
    firstName: data['firstName'] as String?,
    lastName: data['lastName'] as String?,
    phone: data['phone'] as String?,
    role: data['role'] as String? ?? 'player',
    status: data['status'] as String? ?? 'active',
    joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
  );
}

class GymInvitation {
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String role;
  final String status;
  final String? notes;
  final DateTime? addedAt;

  const GymInvitation({
    required this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.role = 'player',
    this.status = 'active',
    this.notes,
    this.addedAt,
  });

  String get initials {
    final name = [firstName, lastName].where((p) => p != null && p.trim().isNotEmpty).join(' ');
    if (name.isNotEmpty) {
      final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
    }
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  String get fullName {
    final name = [firstName, lastName].where((p) => p != null && p.trim().isNotEmpty).join(' ');
    return name.isNotEmpty ? name : email;
  }

  factory GymInvitation.fromMap(String email, Map<String, dynamic> data) => GymInvitation(
    email: email,
    firstName: data['firstName'] as String?,
    lastName: data['lastName'] as String?,
    phone: data['phone'] as String?,
    role: data['role'] as String? ?? 'player',
    status: data['status'] as String? ?? 'active',
    notes: data['notes'] as String?,
    addedAt: (data['addedAt'] as Timestamp?)?.toDate(),
  );
}

// ─── currentGymIdProvider / currentUserRoleProvider ──────────────────────────
// Moved to auth_repository.dart — imported above via auth_repository.dart.
// Both providers are available in this file without re-declaration.

// ─── Members Stream ──────────────────────────────────────────────────────────

final gymMembersStreamProvider = StreamProvider<List<GymMember>>((ref) {
  final gymId = ref.watch(currentGymIdProvider);
  if (gymId == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('members')
      .orderBy('joinedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => GymMember.fromMap(doc.id, doc.data())).toList());
});

// ─── Invitations Stream ───────────────────────────────────────────────────────

final gymInvitationsStreamProvider = StreamProvider<List<GymInvitation>>((ref) {
  final gymId = ref.watch(currentGymIdProvider);
  if (gymId == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('gyms')
      .doc(gymId)
      .collection('memberEmails')
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => GymInvitation.fromMap(doc.id, doc.data())).toList());
});

// ─── Admin Repository ─────────────────────────────────────────────────────────

class AdminRepository {
  final FirebaseFirestore _db;

  const AdminRepository(this._db);

  /// Adds a pre-registration entry so the user can sign up.
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
    final batch = _db.batch();

    // 1. memberEmails — auth gate
    final emailRef = _db
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
    debugPrint('Invited member: $normalizedEmail to gym $gymId');
  }

  /// Revokes an invitation (removes from memberEmails).
  Future<void> revokeInvitation({
    required String gymId,
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _db
        .collection('gyms')
        .doc(gymId)
        .collection('memberEmails')
        .doc(normalizedEmail)
        .delete();
  }

  /// Suspends or reactivates a member.
  /// Syncs status to BOTH users/{uid}.isActive AND gyms/{gymId}/members/{uid}.status.
  Future<void> updateMemberStatus({
    required String gymId,
    required String uid,
    required String status, // 'active' | 'suspended'
  }) async {
    final isActive = status == 'active';
    final batch = _db.batch();

    // 1. Top-level user document
    batch.update(_db.collection('users').doc(uid), {
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Gym members subcollection
    batch.update(
      _db.collection('gyms').doc(gymId).collection('members').doc(uid),
      {'status': status, 'updatedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }

  /// Updates the role of an active member.
  /// Syncs to BOTH users/{uid}.role AND gyms/{gymId}/members/{uid}.role.
  Future<void> updateMemberRole({
    required String gymId,
    required String uid,
    required String role,
  }) async {
    final batch = _db.batch();

    // 1. Top-level user document
    batch.update(_db.collection('users').doc(uid), {
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Gym members subcollection
    batch.update(
      _db.collection('gyms').doc(gymId).collection('members').doc(uid),
      {'role': role, 'updatedAt': FieldValue.serverTimestamp()},
    );

    await batch.commit();
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(FirebaseFirestore.instance);
});
