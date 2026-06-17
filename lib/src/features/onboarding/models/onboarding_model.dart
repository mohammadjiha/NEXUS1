class OnboardingModel {
  final int currentStep;
  final String? gymId;
  final String? selectedRole;

  OnboardingModel({
    this.currentStep = 0,
    this.gymId,
    this.selectedRole,
  });

  OnboardingModel copyWith({
    int? currentStep,
    String? gymId,
    String? selectedRole,
  }) {
    return OnboardingModel(
      currentStep: currentStep ?? this.currentStep,
      gymId: gymId ?? this.gymId,
      selectedRole: selectedRole ?? this.selectedRole,
    );
  }
}
