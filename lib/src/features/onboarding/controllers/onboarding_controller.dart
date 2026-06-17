import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/data/user_repository.dart';
import '../models/onboarding_model.dart';

class OnboardingController extends Notifier<OnboardingModel> {
  @override
  OnboardingModel build() {
    return OnboardingModel();
  }

  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void setGymId(String gymId) {
    state = state.copyWith(gymId: gymId);
  }

  void setRole(String role) {
    state = state.copyWith(selectedRole: role);
  }

  /// يحفظ gymId و role في Firestore إذا كان المستخدم مسجّل دخول
  Future<void> saveToFirestore() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('Onboarding: user not logged in — data will be saved after login');
        return;
      }

      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updateOnboardingData(
        uid: currentUser.uid,
        gymId: state.gymId,
        role: state.selectedRole,
      );

      debugPrint('Onboarding data saved to Firestore ✅');
    } catch (e) {
      debugPrint('Failed to save onboarding data: $e');
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingController, OnboardingModel>(() {
  return OnboardingController();
});
