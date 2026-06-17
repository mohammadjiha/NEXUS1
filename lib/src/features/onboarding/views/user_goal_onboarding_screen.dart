import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/localization/app_localizations.dart';
import '../controllers/goal_selection_provider.dart';

class UserGoalOnboardingScreen extends ConsumerWidget {
  const UserGoalOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalSelectionProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 2.h),
              _buildTopNav(context),
              SizedBox(height: 2.h),
              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 0.5.h,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(1.w),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Container(
                    width: 10.w,
                    height: 0.5.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F5),
                      borderRadius: BorderRadius.circular(1.w),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                'onboarding_what_is_goal'.tr(context),
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'onboarding_goal_desc'.tr(context),
                style: TextStyle(
                  fontSize: 16.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'onboarding_primary_goal'.tr(context),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3A3C),
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 2.h),
              _buildGoalsGrid(ref, state, context),
              SizedBox(height: 4.h),
              Text(
                'onboarding_fitness_level'.tr(context),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3A3C),
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(height: 2.h),
              _buildFitnessLevelRow(ref, state, context),
              const Spacer(),
              _buildBottomButton(context),
              SizedBox(height: 2.h),
              Center(
                child: Text(
                  'onboarding_personalized_msg'.tr(context),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF8E8E93),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNav(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            if (context.canPop()) context.pop();
          },
          child: Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1C1C1E)),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5FF),
            borderRadius: BorderRadius.circular(4.w),
          ),
          child: Text(
            'auth_step_3'.tr(context),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF007AFF),
            ),
          ),
        ),
        Text(
          'auth_skip'.tr(context),
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsGrid(WidgetRef ref, GoalSelectionState state, BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 3.w,
      mainAxisSpacing: 3.w,
      childAspectRatio: 1.4,
      children: [
        _buildGoalCard(
          ref: ref,
          goal: PrimaryGoal.loseFat,
          isSelected: state.primaryGoal == PrimaryGoal.loseFat,
          emoji: '🔥',
          title: 'onboarding_lose_fat'.tr(context),
          subtitle: 'onboarding_lose_fat_desc'.tr(context),
        ),
        _buildGoalCard(
          ref: ref,
          goal: PrimaryGoal.buildMuscle,
          isSelected: state.primaryGoal == PrimaryGoal.buildMuscle,
          emoji: '💪',
          title: 'onboarding_build_muscle'.tr(context),
          subtitle: 'onboarding_build_muscle_desc'.tr(context),
        ),
        _buildGoalCard(
          ref: ref,
          goal: PrimaryGoal.getFit,
          isSelected: state.primaryGoal == PrimaryGoal.getFit,
          emoji: '⚡',
          title: 'onboarding_get_fit'.tr(context),
          subtitle: 'onboarding_get_fit_desc'.tr(context),
        ),
        _buildGoalCard(
          ref: ref,
          goal: PrimaryGoal.maintain,
          isSelected: state.primaryGoal == PrimaryGoal.maintain,
          emoji: '⚖️',
          title: 'onboarding_maintain'.tr(context),
          subtitle: 'onboarding_maintain_desc'.tr(context),
        ),
      ],
    );
  }

  Widget _buildGoalCard({
    required WidgetRef ref,
    required PrimaryGoal goal,
    required bool isSelected,
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () => ref.read(goalSelectionProvider.notifier).selectGoal(goal),
      child: Container(
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(
            color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 22.sp)),
            SizedBox(height: 1.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessLevelRow(WidgetRef ref, GoalSelectionState state, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildLevelChip(
          ref: ref,
          level: FitnessLevel.beginner,
          isSelected: state.fitnessLevel == FitnessLevel.beginner,
          label: 'onboarding_beginner'.tr(context),
        ),
        _buildLevelChip(
          ref: ref,
          level: FitnessLevel.intermediate,
          isSelected: state.fitnessLevel == FitnessLevel.intermediate,
          label: 'onboarding_intermediate'.tr(context),
        ),
        _buildLevelChip(
          ref: ref,
          level: FitnessLevel.advanced,
          isSelected: state.fitnessLevel == FitnessLevel.advanced,
          label: 'onboarding_advanced'.tr(context),
        ),
      ],
    );
  }

  Widget _buildLevelChip({
    required WidgetRef ref,
    required FitnessLevel level,
    required bool isSelected,
    required String label,
  }) {
    return GestureDetector(
      onTap: () => ref.read(goalSelectionProvider.notifier).selectLevel(level),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8FFF0) : const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(3.w),
          border: Border.all(
            color: isSelected ? const Color(0xFF34C759) : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF1A7A30) : const Color(0xFF3A3A3C),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.go('/dashboard');
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 2.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3.w),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🚀', style: TextStyle(fontSize: 18)),
            SizedBox(width: 2.w),
            Text(
              'onboarding_complete_setup'.tr(context),
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
