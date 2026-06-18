import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

class PendingGymIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? gymId) => state = gymId;
}

final pendingGymIdProvider = NotifierProvider<PendingGymIdNotifier, String?>(
  PendingGymIdNotifier.new,
);

class PendingGymCodeNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? gymCode) => state = gymCode;
}

final pendingGymCodeProvider =
    NotifierProvider<PendingGymCodeNotifier, String?>(
      PendingGymCodeNotifier.new,
    );

class GymLookupResult {
  final String id;
  final String code;
  final String? name;

  const GymLookupResult({required this.id, required this.code, this.name});
}

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  String emailKey(String email) => email.trim().toLowerCase();

  Future<void> createUser(UserModel user) async {
    try {
      await _users.doc(user.uid).set(user.toMap());
      debugPrint('User created in Firestore: ${user.uid}');
    } catch (e) {
      debugPrint('Error creating user in Firestore: $e');
      rethrow;
    }
  }

  Future<void> createOrUpdateUser(UserModel user) async {
    try {
      final docRef = _users.doc(user.uid);
      final existingDoc = await docRef.get();
      final data = <String, dynamic>{
        'uid': user.uid,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingDoc.exists) {
        data.remove('createdAt');
      }
      if (user.firstName != null && user.firstName!.trim().isNotEmpty) {
        data['firstName'] = user.firstName!.trim();
      }
      if (user.lastName != null && user.lastName!.trim().isNotEmpty) {
        data['lastName'] = user.lastName!.trim();
      }
      if (user.phone != null && user.phone!.trim().isNotEmpty) {
        data['phone'] = user.phone!.trim();
      }
      if (user.gymId != null && user.gymId!.trim().isNotEmpty) {
        data['gymId'] = user.gymId!.trim();
      }
      if (user.role != null && user.role!.trim().isNotEmpty) {
        data['role'] = user.role!.trim();
      }
      if (user.photoUrl != null && user.photoUrl!.trim().isNotEmpty) {
        data['photoUrl'] = user.photoUrl!.trim();
      }
      if (user.authProvider != null && user.authProvider!.trim().isNotEmpty) {
        data['authProvider'] = user.authProvider!.trim();
      }
      await docRef.set(data, SetOptions(merge: true));
      debugPrint('User synced in Firestore: ${user.uid}');
    } catch (e) {
      debugPrint('Error syncing user in Firestore: $e');
      rethrow;
    }
  }

  Future<void> updateProfileData({
    required String uid,
    String? firstName,
    String? lastName,
    String? phone,
    String? gymId,
    String? role,
    String? photoUrl,
    String? authProvider,
    bool? emailVerified,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (firstName != null && firstName.trim().isNotEmpty) {
        updates['firstName'] = firstName.trim();
      }
      if (lastName != null && lastName.trim().isNotEmpty) {
        updates['lastName'] = lastName.trim();
      }
      if (phone != null && phone.trim().isNotEmpty) {
        updates['phone'] = phone.trim();
      }
      if (gymId != null && gymId.trim().isNotEmpty) {
        updates['gymId'] = gymId.trim();
      }
      if (role != null && role.trim().isNotEmpty) {
        updates['role'] = role.trim();
      }
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        updates['photoUrl'] = photoUrl.trim();
      }
      if (authProvider != null && authProvider.trim().isNotEmpty) {
        updates['authProvider'] = authProvider.trim();
      }
      if (emailVerified != null) {
        updates['emailVerified'] = emailVerified;
      }

      await _users.doc(uid).set(updates, SetOptions(merge: true));
      debugPrint('Profile data updated for: $uid');
    } catch (e) {
      debugPrint('Error updating profile data: $e');
      rethrow;
    }
  }

  Future<void> updateOnboardingData({
    required String uid,
    String? gymId,
    String? role,
  }) {
    return updateProfileData(uid: uid, gymId: gymId, role: role);
  }

  Future<void> updateLastLogin(String uid) async {
    try {
      await _users.doc(uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
        'deviceInfo': kIsWeb ? 'Web Browser' : defaultTargetPlatform.name,
      }, SetOptions(merge: true));
      debugPrint('Updated last login for user: $uid');
    } catch (e) {
      debugPrint('Error updating last login: $e');
    }
  }

  Future<void> updateFcmToken(String uid, String? token) async {
    try {
      if (token == null || token.isEmpty) {
        await _users.doc(uid).update({
          'fcmToken': FieldValue.delete(),
        });
        return;
      }
      await _users.doc(uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<GymLookupResult?> findGymByCode(String gymCode) async {
    try {
      final normalizedCode = gymCode.trim();
      if (normalizedCode.isEmpty) return null;

      // Try int first, then string — handles both storage types in Firestore
      final candidates = <Object>[
        if (int.tryParse(normalizedCode) != null) int.parse(normalizedCode),
        normalizedCode,
      ];

      for (final codeValue in candidates) {
        try {
          final query = await _firestore
              .collection('gyms')
              .where('gymCode', isEqualTo: codeValue)
              .limit(1)
              .get()
              .timeout(const Duration(seconds: 10));

          if (query.docs.isNotEmpty) {
            final doc  = query.docs.first;
            final data = doc.data();
            final status = data['status'];
            // Accept gyms with no status field, or status == 'active'
            if (status != null && status != 'active') return null;
            return GymLookupResult(
              id:   doc.id,
              code: normalizedCode,
              name: data['name'] as String?,
            );
          }
        } catch (e) {
          // Log per-attempt errors but continue to next candidate type.
          debugPrint('findGymByCode attempt ($codeValue / ${codeValue.runtimeType}): $e');
        }
      }

      // Last resort: direct document get in case gymCode == document ID.
      try {
        final doc = await _firestore
            .collection('gyms')
            .doc(normalizedCode)
            .get()
            .timeout(const Duration(seconds: 10));
        if (doc.exists) {
          final data = doc.data()!;
          final status = data['status'];
          if (status != null && status != 'active') return null;
          return GymLookupResult(
            id:   doc.id,
            code: normalizedCode,
            name: data['name'] as String?,
          );
        }
      } catch (e) {
        debugPrint('findGymByCode direct-id attempt ($normalizedCode): $e');
      }

      return null;
    } catch (e) {
      debugPrint('findGymByCode outer error: $e');
      return null;
    }
  }

  Future<bool> gymExists(String gymId) async {
    try {
      final normalizedGymId = gymId.trim();
      if (normalizedGymId.isEmpty) return false;

      final doc = await _firestore
          .collection('gyms')
          .doc(normalizedGymId)
          .get();
      final data = doc.data();
      return doc.exists &&
          (data?['status'] == null || data?['status'] == 'active');
    } catch (e) {
      debugPrint('Error checking gym: $e');
      return false;
    }
  }

  Future<bool> gymAllowsEmail({
    required String gymId,
    required String email,
    String? role,
  }) async {
    try {
      final normalizedGymId = gymId.trim();
      final normalizedEmail = emailKey(email);
      if (normalizedGymId.isEmpty || normalizedEmail.isEmpty) return false;

      final doc = await _firestore
          .collection('gyms')
          .doc(normalizedGymId)
          .collection('memberEmails')
          .doc(normalizedEmail)
          .get();
      final data = doc.data();
      final allowedRole = data?['role'] as String?;
      return doc.exists &&
          (data?['status'] == null || data?['status'] == 'active') &&
          (role == null ||
              role.trim().isEmpty ||
              allowedRole == null ||
              allowedRole == role.trim());
    } catch (e) {
      debugPrint('Error checking gym member email: $e');
      return false;
    }
  }

  Future<void> linkUserToGymMembership({
    required String uid,
    required String gymId,
    required String email,
    String? role,
    String? firstName,
    String? lastName,
  }) async {
    final normalizedGymId = gymId.trim();
    final normalizedEmail = emailKey(email);
    if (normalizedGymId.isEmpty || normalizedEmail.isEmpty) return;

    final displayName = [
      firstName?.trim(),
      lastName?.trim(),
    ].where((part) => part != null && part.isNotEmpty).join(' ');

    await _firestore
        .collection('gyms')
        .doc(normalizedGymId)
        .collection('members')
        .doc(uid)
        .set({
          'uid': uid,
          'email': normalizedEmail,
          'gymId': normalizedGymId,
          if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
          if (displayName.isNotEmpty) 'displayName': displayName,
          'status': 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> ensureDefaultBodyMetrics(String uid) async {
    final docRef = _users
        .doc(uid)
        .collection('metrics')
        .doc('body_composition');
    final existingDoc = await docRef.get();
    if (existingDoc.exists) return;

    await docRef.set({
      'userId': uid,
      'weight': 0.0,
      'previousWeight': 0.0,
      'height': 0.0,
      'previousHeight': 0.0,
      'bodyFat': 0.0,
      'previousBodyFat': 0.0,
      'muscleMass': 0.0,
      'previousMuscleMass': 0.0,
      'waist': 0.0,
      'previousWaist': 0.0,
      'initialWeight': 0.0,
      'age': 0,
      'dateOfBirth': '',
      'goal': '',
      'gender': '',
      'bmr': 0.0,
      'visceralFat': 0.0,
      'fatFreeMass': 0.0,
      'water': 0.0,
      'metabolicAge': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  /// Real-time stream of a user document — used by [currentUserModelProvider].
  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  /// Returns true if the gym exists and its [isActive] field is not false.
  /// Defaults to true on any error or if the gym doc does not exist yet,
  /// so we never accidentally block users during transient network issues.
  Future<bool> isGymActive(String gymId) async {
    try {
      final normalizedId = gymId.trim();
      if (normalizedId.isEmpty) return true;
      final doc =
          await _firestore.collection('gyms').doc(normalizedId).get();
      if (!doc.exists) return true; // gym not found → don't block
      final isActive = doc.data()?['isActive'];
      return isActive != false; // null or true → active
    } catch (e) {
      debugPrint('Error checking gym active status: $e');
      return true; // on any error → don't block sign-in
    }
  }

  Future<bool> userBelongsToGym({
    required String uid,
    required String gymId,
  }) async {
    try {
      final normalizedGymId = gymId.trim();
      final doc = await _firestore.collection('gyms').doc(normalizedGymId).collection('members').doc(uid).get();
      if (doc.exists && doc.data()?['status'] == 'active') return true;
    } catch (_) {}

    final user = await getUser(uid);
    final userGymId = user?.gymId?.trim();
    if (userGymId == null || userGymId.isEmpty) return false;
    
    if (userGymId == gymId.trim()) return true;
    
    try {
      final gymDoc = await _firestore.collection('gyms').doc(gymId.trim()).get();
      if (gymDoc.exists) {
        final code = gymDoc.data()?['gymCode']?.toString();
        if (code != null && (userGymId == code || code == gymId.trim())) return true;
      }
    } catch (_) {}
    return false;
  }
}

