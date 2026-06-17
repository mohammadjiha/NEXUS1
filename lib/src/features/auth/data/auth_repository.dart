import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../user/data/user_repository.dart';
import '../../user/models/user_model.dart';

// Google Web Client ID — move to --dart-define or Remote Config before public release.
// Run: flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<your_id>
// Read with: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID')
const _kGoogleWebClientId =
    '266704213953-26b9088f9s27ues94pobpf2mes4otogv.apps.googleusercontent.com';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(userRepositoryProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).watchUser(user.uid);
});

/// Returns the signed-in user's first name (from displayName), or falls back
/// to the email prefix, or null if not signed in.
final currentUserFirstNameProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return null;
  final userModel = ref.watch(currentUserModelProvider).asData?.value;
  final firestoreName = userModel?.firstName?.trim();
  if (firestoreName != null && firestoreName.isNotEmpty) {
    return firestoreName;
  }
  final display = user.displayName;
  if (display != null && display.trim().isNotEmpty) {
    return display.trim().split(' ').first;
  }
  final email = user.email ?? '';
  if (email.isNotEmpty) return email.split('@').first;
  return null;
});

/// Returns the signed-in user's gym ID, or null if not assigned.
///
/// Derived from [currentUserModelProvider] — zero extra Firestore reads.
/// Lives here (not in admin_provider) so every feature can import it
/// without pulling in admin-specific code.
final currentGymIdProvider = Provider<String?>((ref) {
  final gymId =
      ref.watch(currentUserModelProvider).asData?.value?.gymId?.trim();
  return (gymId == null || gymId.isEmpty) ? null : gymId;
});

/// Returns the signed-in user's role string, or null if not signed in.
///
/// Derived from [currentUserModelProvider] — zero extra Firestore reads.
final currentUserRoleProvider = Provider<String?>((ref) {
  return ref.watch(currentUserModelProvider).asData?.value?.role;
});

/// Real-time stream of the current player's assigned coach user document.
///
/// Returns null when:
/// - The player has no [assignedCoachUid]
/// - The coach document doesn't exist in Firestore
///
/// Used on the player dashboard and profile to display coach info,
/// and to open the in-app chat with the coach.
final assignedCoachProvider = StreamProvider.autoDispose<UserModel?>((ref) {
  final coachUid = ref
      .watch(currentUserModelProvider)
      .asData
      ?.value
      ?.assignedCoachUid
      ?.trim();

  if (coachUid == null || coachUid.isEmpty) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(coachUid)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['uid'] = doc.id;
    return UserModel.fromMap(data);
  });
});

/// Returns the signed-in user's initials (up to 2 chars) for avatar display.
final currentUserInitialsProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return '?';
  final userModel = ref.watch(currentUserModelProvider).asData?.value;
  final nameParts = [
    userModel?.firstName?.trim(),
    userModel?.lastName?.trim(),
  ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();
  if (nameParts.length >= 2) {
    return '${nameParts.first[0]}${nameParts.last[0]}'.toUpperCase();
  }
  if (nameParts.length == 1) {
    final name = nameParts.first;
    return name.substring(0, name.length.clamp(1, 2)).toUpperCase();
  }
  final display = user.displayName?.trim() ?? '';
  if (display.isNotEmpty) {
    final parts = display.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return display.substring(0, display.length.clamp(1, 2)).toUpperCase();
  }
  final email = user.email ?? '';
  if (email.isNotEmpty) return email[0].toUpperCase();
  return '?';
});

class AuthProfileInput {
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? gymId;
  final String? role;

  const AuthProfileInput({
    this.firstName,
    this.lastName,
    this.phone,
    this.gymId,
    this.role,
  });
}

class AuthRepository {
  final FirebaseAuth _auth;
  final UserRepository _userRepo;

  AuthRepository(this._auth, this._userRepo);

  static Future<void>? _googleInitFuture;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(
    String email,
    String password, {
    String? requiredGymId,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _ensureCurrentUserBelongsToGym(
      credential.user,
      requiredGymId: requiredGymId,
    );
    await _ensureGymIsActive(credential.user);
    await _syncFirebaseUser(credential.user, authProvider: 'password');
    return credential;
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password, {
    AuthProfileInput profile = const AuthProfileInput(),
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final displayName = [
      profile.firstName?.trim(),
      profile.lastName?.trim(),
    ].where((part) => part != null && part.isNotEmpty).join(' ');
    if (displayName.isNotEmpty) {
      await credential.user?.updateDisplayName(displayName);
    }
    await credential.user?.sendEmailVerification();

    return credential;
  }

  Future<void> resendCurrentUserEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'No signed-in user was found.',
      );
    }
    if (!refreshedUser.emailVerified) {
      await refreshedUser.sendEmailVerification();
    }
  }

  Future<bool> syncCurrentUserAfterEmailVerified({
    AuthProfileInput profile = const AuthProfileInput(),
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser?.emailVerified != true) {
      return false;
    }

    await _ensureEmailCanJoinGym(
      refreshedUser!,
      gymId: profile.gymId,
      role: profile.role,
    );

    await _syncFirebaseUser(
      refreshedUser,
      authProvider: 'password',
      profile: profile,
    );
    return true;
  }

  Future<UserCredential> signInWithGoogle({
    AuthProfileInput profile = const AuthProfileInput(),
    String? requiredGymId,
  }) async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final credential = await _auth.signInWithPopup(provider);
      await _ensureCurrentUserBelongsToGym(
        credential.user,
        requiredGymId: requiredGymId,
      );
      await _ensureEmailCanJoinGym(
        credential.user,
        gymId: profile.gymId,
        role: profile.role,
      );
      await _ensureGymIsActive(credential.user);
      await _syncFirebaseUser(
        credential.user,
        authProvider: 'google',
        profile: profile,
      );
      return credential;
    }

    await _ensureGoogleInitialized();
    await GoogleSignIn.instance.signOut();

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;

    if (googleAuth.idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google did not return an ID token.',
      );
    }

    final credential = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: googleAuth.idToken),
    );

    await _ensureCurrentUserBelongsToGym(
      credential.user,
      requiredGymId: requiredGymId,
    );
    await _ensureEmailCanJoinGym(
      credential.user,
      gymId: profile.gymId,
      role: profile.role,
    );
    await _ensureGymIsActive(credential.user);

    await _syncFirebaseUser(
      credential.user,
      authProvider: 'google',
      profile: profile,
    );

    return credential;
  }

  Future<UserCredential> signInWithApple({
    AuthProfileInput profile = const AuthProfileInput(),
    String? requiredGymId,
  }) async {
    if (kIsWeb) {
      final credential = await _auth.signInWithPopup(AppleAuthProvider());
      await _ensureCurrentUserBelongsToGym(
        credential.user,
        requiredGymId: requiredGymId,
      );
      await _ensureEmailCanJoinGym(
        credential.user,
        gymId: profile.gymId,
        role: profile.role,
      );
      await _syncFirebaseUser(
        credential.user,
        authProvider: 'apple',
        profile: profile,
      );
      return credential;
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider(
      'apple.com',
    ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

    final credential = await _auth.signInWithCredential(oauthCredential);

    await _ensureCurrentUserBelongsToGym(
      credential.user,
      requiredGymId: requiredGymId,
    );

    final appleProfile = AuthProfileInput(
      firstName: profile.firstName ?? appleCredential.givenName,
      lastName: profile.lastName ?? appleCredential.familyName,
      phone: profile.phone,
      gymId: profile.gymId,
      role: profile.role,
    );
    await _ensureEmailCanJoinGym(
      credential.user,
      gymId: appleProfile.gymId,
      role: appleProfile.role,
    );
    await _ensureGymIsActive(credential.user);

    await _syncFirebaseUser(
      credential.user,
      authProvider: 'apple',
      profile: appleProfile,
    );

    return credential;
  }

  Future<void> updateCurrentUserProfile(AuthProfileInput profile) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (profile.gymId != null && profile.gymId!.trim().isNotEmpty) {
      await _ensureEmailCanJoinGym(
        refreshedUser,
        gymId: profile.gymId,
        role: profile.role,
      );
    }

    await _userRepo.updateProfileData(
      uid: refreshedUser?.uid ?? user.uid,
      firstName: profile.firstName,
      lastName: profile.lastName,
      phone: profile.phone,
      gymId: profile.gymId,
      role: profile.role,
    );

    final displayName = [
      profile.firstName?.trim(),
      profile.lastName?.trim(),
    ].where((part) => part != null && part.isNotEmpty).join(' ');
    if (displayName.isNotEmpty) {
      await refreshedUser?.updateDisplayName(displayName);
    }
    if (profile.gymId != null && profile.gymId!.trim().isNotEmpty) {
      await _userRepo.linkUserToGymMembership(
        uid: refreshedUser?.uid ?? user.uid,
        gymId: profile.gymId!,
        email: refreshedUser?.email ?? user.email ?? '',
        role: profile.role,
        firstName: profile.firstName,
        lastName: profile.lastName,
      );
    }
  }

  Future<void> updateCurrentUserPhotoUrl(String photoUrl) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'No signed-in user was found.',
      );
    }

    await user.updatePhotoURL(photoUrl);
    await _userRepo.updateProfileData(uid: user.uid, photoUrl: photoUrl);
  }

  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _userRepo.updateFcmToken(user.uid, null);
      }
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> _syncFirebaseUser(
    User? user, {
    required String authProvider,
    AuthProfileInput profile = const AuthProfileInput(),
  }) async {
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Firebase Auth did not return a user.',
      );
    }
    final existingUser = await _userRepo.getUser(user.uid);
    final isPrelinkedVerifiedUser =
        (existingUser?.emailVerified ?? false) &&
        (existingUser?.gymId?.trim().isNotEmpty ?? false);
    if (authProvider == 'password' &&
        !user.emailVerified &&
        !isPrelinkedVerifiedUser) {
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email before saving your profile.',
      );
    }
    final effectiveEmailVerified =
        user.emailVerified || isPrelinkedVerifiedUser;

    await _userRepo.createOrUpdateUser(
      UserModel(
        uid: user.uid,
        email: user.email ?? '',
        firstName: profile.firstName,
        lastName: profile.lastName,
        phone: profile.phone,
        gymId: profile.gymId,
        role: profile.role,
        photoUrl: user.photoURL,
        authProvider: authProvider,
        emailVerified: effectiveEmailVerified,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await _userRepo.ensureDefaultBodyMetrics(user.uid);

    final gymId = profile.gymId?.trim();
    if (gymId != null && gymId.isNotEmpty) {
      await _userRepo.linkUserToGymMembership(
        uid: user.uid,
        gymId: gymId,
        email: user.email ?? '',
        role: profile.role,
        firstName: profile.firstName,
        lastName: profile.lastName,
      );
    }
    await _userRepo.updateLastLogin(user.uid);
    // FCM: register token so backend can push notifications to this device.
    _saveFcmToken(user.uid); // fire-and-forget — never blocks sign-in
  }

  Future<void> _saveFcmToken(String uid) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      await _userRepo.updateFcmToken(uid, token);
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  Future<void> _ensureEmailCanJoinGym(
    User? user, {
    String? gymId,
    String? role,
  }) async {
    final normalizedGymId = gymId?.trim();
    if (normalizedGymId == null || normalizedGymId.isEmpty) return;
    if (user == null || user.email == null || user.email!.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-user-email',
        message: 'This account does not have an email address.',
      );
    }
    if (!user.emailVerified) {
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email before joining a gym.',
      );
    }

    final isAllowed = await _userRepo.gymAllowsEmail(
      gymId: normalizedGymId,
      email: user.email!,
      role: role,
    );
    if (isAllowed) return;

    throw FirebaseAuthException(
      code: 'email-not-in-gym',
      message:
          'This email is not registered for this role in $normalizedGymId.',
    );
  }

  Future<void> _ensureCurrentUserBelongsToGym(
    User? user, {
    String? requiredGymId,
  }) async {
    final normalizedGymId = requiredGymId?.trim();
    if (normalizedGymId == null || normalizedGymId.isEmpty) return;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Firebase Auth did not return a user.',
      );
    }

    final belongsToGym = await _userRepo.userBelongsToGym(
      uid: user.uid,
      gymId: normalizedGymId,
    );
    if (belongsToGym) return;

    await _auth.signOut();
    throw FirebaseAuthException(
      code: 'wrong-gym',
      message: 'This account does not belong to $normalizedGymId.',
    );
  }

  /// Checks that the signed-in user's gym (if any) is still active.
  /// If [isActive == false], signs the user out and throws a
  /// [FirebaseAuthException] with code [gym-inactive].
  Future<void> _ensureGymIsActive(User? user) async {
    if (user == null) return;
    final userDoc = await _userRepo.getUser(user.uid);
    final gymId = userDoc?.gymId?.trim();
    if (gymId == null || gymId.isEmpty) return; // super admin / no gym → allow
    final active = await _userRepo.isGymActive(gymId);
    if (!active) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'gym-inactive',
        message:
            'Your gym is currently inactive. Please contact your gym to reactivate your subscription.',
      );
    }
  }

  Future<void> _ensureGoogleInitialized() {
    _googleInitFuture ??= GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? _kGoogleWebClientId : null,
      serverClientId: _kGoogleWebClientId,
    );
    return _googleInitFuture!;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
