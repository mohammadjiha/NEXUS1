import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../user/data/user_repository.dart';

class OnboardingGymScreen extends ConsumerStatefulWidget {
  const OnboardingGymScreen({super.key});

  @override
  ConsumerState<OnboardingGymScreen> createState() =>
      _OnboardingGymScreenState();
}

class _OnboardingGymScreenState extends ConsumerState<OnboardingGymScreen> {
  final _gymIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _gymIdController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final gymCode = _gymIdController.text.trim();
    if (gymCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('auth_enter_gym_code'.tr(context))));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final gym = await ref.read(userRepositoryProvider).findGymByCode(gymCode);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (gym != null) {
        ref.read(pendingGymIdProvider.notifier).set(gym.id);
        ref.read(pendingGymCodeProvider.notifier).set(gym.code);
        context.push('/login');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'auth_gym_code_not_found'.tr(context)}: $gymCode')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth_network_error'.tr(context))),
      );
    }
  }

  Future<void> _handleSignUp() async {
    final gymCode = _gymIdController.text.trim();
    if (gymCode.isEmpty) {
      ref.read(pendingGymIdProvider.notifier).set(null);
      ref.read(pendingGymCodeProvider.notifier).set(null);
      context.push('/signup');
      return;
    }

    setState(() => _isLoading = true);
    final gym = await ref.read(userRepositoryProvider).findGymByCode(gymCode);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (gym == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'auth_gym_code_not_found'.tr(context)}: $gymCode')),
      );
      return;
    }

    ref.read(pendingGymIdProvider.notifier).set(gym.id);
    ref.read(pendingGymCodeProvider.notifier).set(gym.code);
    context.push('/signup');
  }

  Widget _buildStepHeader({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 2.h),
        Text(
          step,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF007AFF),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15.sp,
            color: const Color(0xFF6E6E73),
            height: 1.5,
          ),
        ),
        SizedBox(height: 4.h),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == 0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 1.w),
          height: 0.8.h,
          width: isActive ? 6.w : 2.w,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            borderRadius: BorderRadius.circular(1.w),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(top: 2.h, start: 4.w, end: 4.w),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/onboarding');
                      }
                    },
                    child: Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 18.sp,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 1.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepHeader(
                      step: 'auth_onboarding_step_1'.tr(context),
                      title: 'auth_enter_gym_code_title'.tr(context),
                      subtitle: 'auth_enter_gym_code_desc'.tr(context),
                    ),
                    Text(
                      'auth_gym_code_label'.tr(context),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3A3A3C),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(4.w),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 5.w),
                      child: TextFormField(
                        controller: _gymIdController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: '1001',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: true,
                          fillColor: const Color(0xFF1C1C1E),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 2.h),
                        ),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFF2F2F7),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 3.w),
                          child: Text(
                            'auth_or'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFF2F2F7),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 2.2.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4.w),
                        border: Border.all(color: const Color(0xFFD1D1D6)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            color: const Color(0xFF1C1C1E),
                            size: 20.sp,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'auth_scan_qr'.tr(context),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                        ],
                      ),
                    ),


                    const Spacer(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 3.h),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: EdgeInsets.symmetric(vertical: 2.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 5.w,
                          height: 5.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'auth_continue'.tr(context),
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
