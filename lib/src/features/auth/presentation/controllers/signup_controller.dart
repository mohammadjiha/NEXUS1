import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/firebase_auth_error_mapper.dart';
import '../../../user/data/user_repository.dart';
import '../../data/auth_repository.dart';

class SignupState {
  final int currentStep;
  final String selectedRole;
  final String? gymId;
  final String? gymCode;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final bool emailVerificationSent;
  final bool emailVerified;
  final DateTime? resendAvailableAt;
  final bool isLoading;
  final String? error;

  const SignupState({
    this.currentStep = 1,
    this.selectedRole = 'player',
    this.gymId,
    this.gymCode,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.emailVerificationSent = false,
    this.emailVerified = false,
    this.resendAvailableAt,
    this.isLoading = false,
    this.error,
  });

  static const _notProvided = Object();

  SignupState copyWith({
    int? currentStep,
    String? selectedRole,
    String? gymId,
    Object? gymCode = _notProvided,
    Object? email = _notProvided,
    Object? firstName = _notProvided,
    Object? lastName = _notProvided,
    Object? phone = _notProvided,
    bool? emailVerificationSent,
    bool? emailVerified,
    Object? resendAvailableAt = _notProvided,
    bool? isLoading,
    Object? error = _notProvided,
  }) {
    return SignupState(
      currentStep: currentStep ?? this.currentStep,
      selectedRole: selectedRole ?? this.selectedRole,
      gymId: gymId ?? this.gymId,
      gymCode: identical(gymCode, _notProvided)
          ? this.gymCode
          : gymCode as String?,
      email: identical(email, _notProvided) ? this.email : email as String?,
      firstName: identical(firstName, _notProvided)
          ? this.firstName
          : firstName as String?,
      lastName: identical(lastName, _notProvided)
          ? this.lastName
          : lastName as String?,
      phone: identical(phone, _notProvided) ? this.phone : phone as String?,
      emailVerificationSent:
          emailVerificationSent ?? this.emailVerificationSent,
      emailVerified: emailVerified ?? this.emailVerified,
      resendAvailableAt: identical(resendAvailableAt, _notProvided)
          ? this.resendAvailableAt
          : resendAvailableAt as DateTime?,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _notProvided) ? this.error : error as String?,
    );
  }

  bool get canResendEmail =>
      resendAvailableAt == null || DateTime.now().isAfter(resendAvailableAt!);
}

class SignupController extends Notifier<SignupState> {
  @override
  SignupState build() {
    final pendingGymId = ref.read(pendingGymIdProvider);
    final pendingGymCode = ref.read(pendingGymCodeProvider);
    return SignupState(gymId: pendingGymId, gymCode: pendingGymCode);
  }

  void setStep(int step) {
    if (step >= 1 && step <= 5) {
      state = state.copyWith(currentStep: step);
    }
  }

  void setRole(String role) {
    state = state.copyWith(selectedRole: role);
  }

  void setGymId(String gymId) {
    state = state.copyWith(gymId: gymId);
  }

  void setGymCode(String gymCode) {
    state = state.copyWith(gymCode: gymCode);
  }

  void nextStep() {
    if (state.currentStep < 5) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void prevStep() {
    if (state.currentStep > 1) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<bool> createAccount({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    final normalizedEmail = email.trim();
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref
          .read(authRepositoryProvider)
          .signUpWithEmail(
            normalizedEmail,
            password,
            profile: AuthProfileInput(
              firstName: firstName?.trim(),
              lastName: lastName?.trim(),
              phone: phone?.trim(),
            ),
          );
      state = state.copyWith(
        isLoading: false,
        email: normalizedEmail,
        firstName: firstName?.trim(),
        lastName: lastName?.trim(),
        phone: phone?.trim(),
        emailVerificationSent: true,
        emailVerified: false,
        resendAvailableAt: DateTime.now().add(AppDurations.emailResendCooldown),
      );
      nextStep();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> resendVerificationEmail() async {
    if (!state.canResendEmail) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendCurrentUserEmailVerification();
      state = state.copyWith(
        isLoading: false,
        emailVerificationSent: true,
        resendAvailableAt: DateTime.now().add(AppDurations.emailResendCooldown),
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> verifyEmail() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final isVerified = await ref
          .read(authRepositoryProvider)
          .syncCurrentUserAfterEmailVerified(
            profile: AuthProfileInput(
              firstName: state.firstName,
              lastName: state.lastName,
              phone: state.phone,
              role: state.selectedRole,
              gymId: state.gymId?.trim(),
            ),
          );
      if (!isVerified) {
        state = state.copyWith(
          isLoading: false,
          emailVerified: false,
          error: 'Please open the verification link sent to your email first.',
        );
        return false;
      }

      state = state.copyWith(isLoading: false, emailVerified: true);
      nextStep();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle() {
    return _signInWithSocial((profile) {
      return ref
          .read(authRepositoryProvider)
          .signInWithGoogle(profile: profile);
    });
  }

  Future<bool> signInWithApple() {
    return _signInWithSocial((profile) {
      return ref.read(authRepositoryProvider).signInWithApple(profile: profile);
    });
  }

  Future<bool> saveRole() async {
    nextStep();
    return true;
  }

  Future<bool> saveGym() async {
    var gymId = state.gymId?.trim() ?? '';
    final gymCode = state.gymCode?.trim() ?? '';
    if (gymId.isEmpty && gymCode.isEmpty) {
      state = state.copyWith(error: 'Please enter a Gym Code');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      if (gymId.isEmpty) {
        final gym = await ref
            .read(userRepositoryProvider)
            .findGymByCode(gymCode);
        gymId = gym?.id ?? '';
      }

      final exists =
          gymId.isNotEmpty &&
          await ref.read(userRepositoryProvider).gymExists(gymId);
      if (!exists) {
        state = state.copyWith(
          isLoading: false,
          error: 'This gym was not found in Firebase',
        );
        return false;
      }

      await ref
          .read(authRepositoryProvider)
          .updateCurrentUserProfile(AuthProfileInput(gymId: gymId));
      state = state.copyWith(isLoading: false, gymId: gymId);
      nextStep();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
      return false;
    }
  }

  Future<bool> _signInWithSocial(
    Future<Object?> Function(AuthProfileInput profile) signIn,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await signIn(
        AuthProfileInput(role: state.selectedRole, gymId: state.gymId),
      );
      state = state.copyWith(isLoading: false);
      nextStep();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
      return false;
    }
  }

  /// Returns a localization **key** (not the translated string).
  /// The widget layer calls `.tr(context)` on it when displaying.
  String _friendlyError(Object error) => FirebaseAuthErrorMapper.toKey(error);
}

final signupControllerProvider =
    NotifierProvider<SignupController, SignupState>(() {
      return SignupController();
    });

class SignupPasswordVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
}

final signupPasswordVisibilityProvider =
    NotifierProvider<SignupPasswordVisibilityNotifier, bool>(
      () => SignupPasswordVisibilityNotifier(),
    );
