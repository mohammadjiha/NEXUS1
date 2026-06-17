import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/spinning_dumbbell.dart';
import '../../../user/data/user_repository.dart';
import '../controllers/signup_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final PageController _pageController = PageController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final TextEditingController _gymIdController;
  final _formKey1 = GlobalKey<FormState>();
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  bool _termsAccepted = false;
  bool _isEmailOk = false;
  bool _isPasswordOk = false;
  bool _isFirstNameOk = false;
  bool _isLastNameOk = false;
  bool _isPhoneOk = false;
  bool _isConfirmPasswordOk = false;
  String _countrySuffix = 'JO';

  static const Map<String, String> _countryCodes = {
    '962': 'JO',
    '1': 'US',
    '44': 'UK',
    '971': 'AE',
    '966': 'SA',
    '20': 'EG',
    '964': 'IQ',
    '965': 'KW',
    '974': 'QA',
    '973': 'BH',
    '968': 'OM',
    '963': 'SY',
    '961': 'LB',
    '970': 'PS',
    '972': 'PS',
    '212': 'MA',
    '213': 'DZ',
    '216': 'TN',
    '218': 'LY',
    '249': 'SD',
  };

  @override
  void initState() {
    super.initState();
    final pendingGymId = ref.read(pendingGymIdProvider);
    final pendingGymCode = ref.read(pendingGymCodeProvider);
    _gymIdController = TextEditingController(text: pendingGymCode ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(signupControllerProvider.notifier);
      if (pendingGymId != null && pendingGymId.trim().isNotEmpty) {
        notifier.setGymId(pendingGymId);
      }
      notifier.setGymCode(_gymIdController.text);
    });
    _emailController.addListener(() {
      final isOk =
          _emailController.text.contains('@') &&
          _emailController.text.contains('.');
      if (_isEmailOk != isOk) setState(() => _isEmailOk = isOk);
    });
    _passwordController.addListener(() {
      final isOk = _passwordController.text.length >= 8;
      if (_isPasswordOk != isOk) setState(() => _isPasswordOk = isOk);

      final confirmOk =
          _confirmPasswordController.text == _passwordController.text &&
          _passwordController.text.isNotEmpty;
      if (_isConfirmPasswordOk != confirmOk) {
        setState(() => _isConfirmPasswordOk = confirmOk);
      }
    });
    _firstNameController.addListener(() {
      final isOk = _firstNameController.text.isNotEmpty;
      if (_isFirstNameOk != isOk) setState(() => _isFirstNameOk = isOk);
    });
    _lastNameController.addListener(() {
      final isOk = _lastNameController.text.isNotEmpty;
      if (_isLastNameOk != isOk) setState(() => _isLastNameOk = isOk);
    });
    _phoneController.addListener(() {
      final text = _phoneController.text.replaceAll(' ', '');
      final isOk = text.length >= 8;
      if (_isPhoneOk != isOk) setState(() => _isPhoneOk = isOk);

      String newSuffix = '';
      for (int i = 3; i >= 1; i--) {
        if (text.length >= i) {
          String code = text.substring(0, i);
          if (_countryCodes.containsKey(code)) {
            newSuffix = _countryCodes[code]!;
            break;
          }
        }
      }
      if (_countrySuffix != newSuffix) {
        setState(() => _countrySuffix = newSuffix);
      }
    });
    _confirmPasswordController.addListener(() {
      final isOk =
          _confirmPasswordController.text == _passwordController.text &&
          _passwordController.text.isNotEmpty;
      if (_isConfirmPasswordOk != isOk) {
        setState(() => _isConfirmPasswordOk = isOk);
      }
    });
    _gymIdController.addListener(() {
      ref
          .read(signupControllerProvider.notifier)
          .setGymCode(_gymIdController.text);
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _confirmPasswordController.dispose();
    _gymIdController.dispose();
    _pageController.dispose();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _handleNext(SignupState state, BuildContext context) {
    if (state.currentStep == 1) {
      if (!_formKey1.currentState!.validate() || !_termsAccepted) {
        if (!_termsAccepted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('auth_accept_terms'.tr(context))),
          );
        }
        return;
      }
      ref
          .read(signupControllerProvider.notifier)
          .createAccount(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: '+${_phoneController.text.trim()}',
          );
    } else if (state.currentStep == 2) {
      ref.read(signupControllerProvider.notifier).saveRole();
    } else if (state.currentStep == 3) {
      ref.read(signupControllerProvider.notifier).verifyEmail();
    } else if (state.currentStep == 4) {
      ref.read(signupControllerProvider.notifier).saveGym();
    } else if (state.currentStep < 5) {
      ref.read(signupControllerProvider.notifier).nextStep();
    }
  }

  void _handlePrev(SignupState state) {
    if (state.currentStep > 1) {
      ref.read(signupControllerProvider.notifier).prevStep();
    } else {
      context.pop();
    }
  }

  Widget _buildStepIndicator(int currentStep) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isActive = index == (currentStep - 1);
        final isDone = index < (currentStep - 1);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 1.w),
          height: 0.8.h,
          width: isActive ? 6.w : 2.w,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF1C1C1E)
                : (isDone ? const Color(0xFF34C759) : const Color(0xFFE5E5EA)),
            borderRadius: BorderRadius.circular(1.w),
          ),
        );
      }),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    bool isFocusedBlue = false,
    bool isOk = false,
    bool showBlueDot = true,
    IconData? prefixIcon,
    Color? prefixIconColor,
    String? prefixText,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    Widget? suffixWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBlueDot) ...[
              Container(
                width: 2.5.w,
                height: 2.5.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF007AFF),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 1.5.w),
            ] else ...[
              SizedBox(width: 1.5.w),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A3A3C),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4.w),
            border: Border.all(
              color: isOk
                  ? const Color(0xFF34C759)
                  : (isFocusedBlue
                        ? const Color(0xFF007AFF)
                        : const Color(0xFFE5E5EA)),
              width: isOk || isFocusedBlue ? 1.5 : 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.2.h),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(
                  prefixIcon,
                  color: prefixIconColor ?? const Color(0xFF8E8E93),
                  size: 18.sp,
                ),
                SizedBox(width: 3.w),
              ],
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1C1C1E),
                  ),
                  cursorColor: const Color(0xFF1C1C1E),
                  keyboardType: prefixText == '+' ? TextInputType.phone : null,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: const Color(0xFFC7C7CC),
                      fontSize: 17.sp,
                    ),
                    prefixText: prefixText,
                    prefixStyle: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1C1C1E),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    errorStyle: const TextStyle(
                      height: 0,
                      color: Colors.transparent,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.symmetric(vertical: 1.5.h),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'auth_required'.tr(context);
                    if (label.toLowerCase().contains('email') &&
                        !val.contains('@')) {
                      return 'auth_required'.tr(context);
                    }
                    if (isPassword && val.length < 8) return 'auth_required'.tr(context);
                    return null;
                  },
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?suffixWidget,
                  if (suffixWidget == null && isOk && !isPassword)
                    Icon(Icons.check, color: const Color(0xFF34C759), size: 18.sp),
                  if (isPassword && onToggleVisibility != null) ...[
                    if (suffixWidget != null) SizedBox(width: 3.w),
                    GestureDetector(
                      onTap: onToggleVisibility,
                      child: Icon(
                        obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFC7C7CC),
                        size: 20.sp,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
            fontSize: 26.sp,
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

  int _resendSecondsLeft(SignupState state) {
    final availableAt = state.resendAvailableAt;
    if (availableAt == null || !_now.isBefore(availableAt)) return 0;
    return availableAt.difference(_now).inSeconds + 1;
  }

  Future<void> _openEmailInbox(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final inboxUrl = normalizedEmail.endsWith('@gmail.com')
        ? Uri.parse('https://mail.google.com/mail/u/0/#inbox')
        : Uri(scheme: 'mailto', path: normalizedEmail);

    final opened = await launchUrl(
      inboxUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth_no_email_app'.tr(context))),
      );
    }
  }

  Widget _buildLoadingDumbbell() {
    return SpinningDumbbell(size: 18.sp, boxSize: 6.w);
  }

  Widget _buildRoleCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String selectedRole,
  }) {
    final isSelected = selectedRole == id;
    return GestureDetector(
      onTap: () => ref.read(signupControllerProvider.notifier).setRole(id),
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.5.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF007AFF)
                : const Color(0xFFE5E5EA),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 14.w,
              height: 14.w,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Icon(icon, color: iconColor, size: 24.sp),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13.sp, color: const Color(0xFF6E6E73)),
                  ),
                ],
              ),
            ),
            Container(
              width: 7.w,
              height: 7.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFD1D1D6),
                  width: 1.5,
                ),
                color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 2.5.w,
                        height: 2.5.w,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String text,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            SizedBox(width: 3.w),
            Text(
              text,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(bool isObscured, BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.only(start: 6.w, end: 6.w, bottom: 15.h),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(
              step: 'auth_step_1'.tr(context),
              title: 'auth_create_account'.tr(context),
              subtitle: 'auth_create_account_desc'.tr(context),
            ),

            Row(
              children: [
                Expanded(
                  child: _buildSocialButton(
                    text: 'auth_google'.tr(context),
                    onTap: () => ref
                        .read(signupControllerProvider.notifier)
                        .signInWithGoogle(),
                    icon: Image.network(
                      'https://img.icons8.com/color/48/000000/google-logo.png',
                      width: 5.w,
                      height: 5.w,
                      errorBuilder: (c, e, s) => Icon(
                        Icons.g_mobiledata,
                        color: Colors.red,
                        size: 16.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _buildSocialButton(
                    text: 'auth_apple'.tr(context),
                    onTap: () => ref
                        .read(signupControllerProvider.notifier)
                        .signInWithApple(),
                    icon: Icon(Icons.apple, color: Colors.black, size: 16.sp),
                  ),
                ),
              ],
            ),

            SizedBox(height: 4.h),
            Row(
              children: [
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFF2F2F7)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: Text(
                    'auth_or_with_email'.tr(context),
                    style: TextStyle(fontSize: 15.sp, color: const Color(0xFFC7C7CC)),
                  ),
                ),
                Expanded(
                  child: Container(height: 1, color: const Color(0xFFF2F2F7)),
                ),
              ],
            ),
            SizedBox(height: 3.h),

            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    label: 'auth_first_name'.tr(context),
                    hint: 'auth_first_name_hint'.tr(context),
                    controller: _firstNameController,
                    isOk: _isFirstNameOk,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: _buildInputField(
                    label: 'auth_last_name'.tr(context),
                    hint: 'auth_last_name_hint'.tr(context),
                    controller: _lastNameController,
                    isOk: _isLastNameOk,
                  ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            _buildInputField(
              label: 'auth_email'.tr(context),
              hint: 'auth_email_hint'.tr(context),
              controller: _emailController,
              isFocusedBlue: _isEmailOk,
              prefixIcon: Icons.email_outlined,
              prefixIconColor: _isEmailOk
                  ? const Color(0xFF007AFF)
                  : const Color(0xFF8E8E93),
            ),
            SizedBox(height: 2.h),
            _buildInputField(
              label: 'auth_phone'.tr(context),
              hint: '962 79 123 4567',
              controller: _phoneController,
              isFocusedBlue: _isPhoneOk,
              prefixIcon: Icons.phone_iphone_outlined,
              prefixIconColor: _isPhoneOk
                  ? const Color(0xFF007AFF)
                  : const Color(0xFF8E8E93),
              prefixText: '+',
              suffixWidget: Text(
                _countrySuffix,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ),
            SizedBox(height: 2.h),
            _buildInputField(
              label: 'auth_password'.tr(context),
              hint: '••••••••••',
              controller: _passwordController,
              isPassword: true,
              isOk: _isPasswordOk,
              obscureText: isObscured,
              onToggleVisibility: () =>
                  ref.read(signupPasswordVisibilityProvider.notifier).toggle(),
              prefixIcon: Icons.lock_outline,
              prefixIconColor: _isPasswordOk
                  ? const Color(0xFF34C759)
                  : const Color(0xFF8E8E93),
            ),

            // Password Strength Indicator
            if (_passwordController.text.isNotEmpty) ...[
              SizedBox(height: 1.h),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 0.5.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(width: 1.w),
                  Expanded(
                    child: Container(
                      height: 0.5.h,
                      decoration: BoxDecoration(
                        color: _passwordController.text.length >= 4
                            ? const Color(0xFF34C759)
                            : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(width: 1.w),
                  Expanded(
                    child: Container(
                      height: 0.5.h,
                      decoration: BoxDecoration(
                        color: _passwordController.text.length >= 6
                            ? const Color(0xFF34C759)
                            : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(width: 1.w),
                  Expanded(
                    child: Container(
                      height: 0.5.h,
                      decoration: BoxDecoration(
                        color: _passwordController.text.length >= 8
                            ? const Color(0xFF34C759)
                            : const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 0.8.h),
              Text(
                _passwordController.text.length >= 8
                    ? 'auth_strong_password'.tr(context)
                    : 'auth_weak_password'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: _passwordController.text.length >= 8
                      ? const Color(0xFF34C759)
                      : const Color(0xFFE53935),
                ),
              ),
            ],

            SizedBox(height: 2.h),
            _buildInputField(
              label: 'auth_confirm_password'.tr(context),
              hint: '••••••••••',
              controller: _confirmPasswordController,
              isPassword: true,
              isOk: _isConfirmPasswordOk,
              obscureText: isObscured,
              onToggleVisibility: () =>
                  ref.read(signupPasswordVisibilityProvider.notifier).toggle(),
              prefixIcon: Icons.lock_outline,
              prefixIconColor: _isConfirmPasswordOk
                  ? const Color(0xFF34C759)
                  : const Color(0xFF8E8E93),
              suffixWidget: _isConfirmPasswordOk
                  ? Text(
                      'auth_match'.tr(context),
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF34C759),
                      ),
                    )
                  : null,
            ),
            SizedBox(height: 3.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _termsAccepted = !_termsAccepted),
                  child: Container(
                    width: 6.w,
                    height: 6.w,
                    margin: EdgeInsetsDirectional.only(top: 0.5.h, end: 3.w),
                    decoration: BoxDecoration(
                      color: _termsAccepted ? const Color(0xFF1C1C1E) : Colors.white,
                      border: Border.all(
                        color: _termsAccepted
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFD1D1D6),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(1.5.w),
                    ),
                    child: _termsAccepted
                        ? Icon(Icons.check, color: Colors.white, size: 12.sp)
                        : null,
                  ),
                ),
                Expanded(
                  child: Text(
                    'auth_agree_terms'.tr(context),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF6E6E73),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2(String selectedRole, BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.only(start: 6.w, end: 6.w, bottom: 15.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            step: 'auth_step_2'.tr(context),
            title: 'auth_choose_role'.tr(context),
            subtitle: 'auth_choose_role_desc'.tr(context),
          ),
          _buildRoleCard(
            id: 'player',
            title: 'auth_role_player'.tr(context),
            subtitle: 'auth_role_player_desc'.tr(context),
            icon: Icons.person_outline,
            iconColor: const Color(0xFF007AFF),
            iconBg: const Color(0xFFE8F5FF),
            selectedRole: selectedRole,
          ),
          _buildRoleCard(
            id: 'coach',
            title: 'auth_role_coach'.tr(context),
            subtitle: 'auth_role_coach_desc'.tr(context),
            icon: Icons.sports,
            iconColor: const Color(0xFFFF3B30),
            iconBg: const Color(0xFFFFF0F0),
            selectedRole: selectedRole,
          ),
          _buildRoleCard(
            id: 'owner',
            title: 'auth_role_owner'.tr(context),
            subtitle: 'auth_role_owner_desc'.tr(context),
            icon: Icons.business,
            iconColor: const Color(0xFF34C759),
            iconBg: const Color(0xFFF0FFF4),
            selectedRole: selectedRole,
          ),
          _buildRoleCard(
            id: 'independent',
            title: 'auth_role_independent'.tr(context),
            subtitle: 'auth_role_independent_desc'.tr(context),
            icon: Icons.auto_awesome,
            iconColor: const Color(0xFF7B5CF0),
            iconBg: const Color(0xFFF0EEFF),
            selectedRole: selectedRole,
          ),
        ],
      ),
    );
  }

  Widget _buildStep3(SignupState state, BuildContext context) {
    final email = state.email ?? _emailController.text.trim();
    final resendSecondsLeft = _resendSecondsLeft(state);
    final canResend = resendSecondsLeft == 0 && !state.isLoading;
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.only(start: 6.w, end: 6.w, bottom: 15.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            step: 'auth_step_3'.tr(context),
            title: 'auth_verify_email'.tr(context),
            subtitle:
                '${'auth_verify_email_desc'.tr(context)} ${email.isEmpty ? "" : email}',
          ),
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 1.h, bottom: 3.h),
              padding: EdgeInsets.all(5.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(5.w),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Icon(
                Icons.mark_email_read_outlined,
                size: 36.sp,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: state.emailVerified
                    ? null
                    : () => _openEmailInbox(email),
                borderRadius: BorderRadius.circular(4.w),
                child: Ink(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5.w,
                    vertical: 1.8.h,
                  ),
                  decoration: BoxDecoration(
                    color: state.emailVerified
                        ? const Color(0xFFE8FFF0)
                        : const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(4.w),
                    border: Border.all(
                      color: state.emailVerified
                          ? const Color(0xFF34C759)
                          : const Color(0xFF007AFF),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.emailVerified
                            ? Icons.check_circle_outline
                            : Icons.link,
                        color: state.emailVerified
                            ? const Color(0xFF34C759)
                            : const Color(0xFF007AFF),
                        size: 20.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        state.emailVerified
                            ? 'auth_email_verified'.tr(context)
                            : 'auth_open_email_continue'.tr(context),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: state.emailVerified
                              ? const Color(0xFF1A7A30)
                              : const Color(0xFF007AFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Center(
            child: RichText(
              text: TextSpan(
                text: 'auth_didnt_receive_email'.tr(context),
                style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: canResend
                          ? () => ref
                                .read(signupControllerProvider.notifier)
                                .resendVerificationEmail()
                          : null,
                      child: Text(
                        'auth_resend_email'.tr(context),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: canResend
                              ? const Color(0xFF007AFF)
                              : const Color(0xFF1C1C1E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  TextSpan(
                    text: resendSecondsLeft > 0
                        ? ' · 0:${resendSecondsLeft.toString().padLeft(2, '0')}'
                        : '',
                  ),
                ],
              ),
            ),
          ),
          if (state.emailVerificationSent)
            Center(
              child: Text(
                'auth_verification_link_sent'.tr(context),
                style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
              ),
            ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(4.w),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: const Color(0xFF007AFF), size: 20.sp),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    'auth_firebase_secure_link'.tr(context),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF6E6E73),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.only(start: 6.w, end: 6.w, bottom: 15.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            step: 'auth_step_4'.tr(context),
            title: 'auth_join_gym'.tr(context),
            subtitle: 'auth_join_gym_desc'.tr(context),
          ),
          Text(
            'auth_gym_code_label'.tr(context),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3A3A3C),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 1.h),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4.w),
              border: Border.all(color: const Color(0xFF34C759), width: 1.5),
            ),
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.8.h),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gymIdController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(border: InputBorder.none),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Text(
                  'auth_found'.tr(context),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF34C759),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'auth_iron_peak'.tr(context),
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF34C759)),
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: const Color(0xFFE8FFF0),
              borderRadius: BorderRadius.circular(4.w),
              border: Border.all(color: const Color(0xFFA8E6BE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 14.w,
                  height: 14.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'auth_iron_peak_title'.tr(context),
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A7A30),
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        'auth_verified_gym'.tr(context),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF34A853),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: Container(height: 1, color: const Color(0xFFF2F2F7)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                child: Text(
                  'auth_or_scan_qr'.tr(context),
                  style: TextStyle(fontSize: 13.sp, color: const Color(0xFFC7C7CC)),
                ),
              ),
              Expanded(
                child: Container(height: 1, color: const Color(0xFFF2F2F7)),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(4.w),
              border: Border.all(color: const Color(0xFFD1D1D6)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 36.sp,
                  color: const Color(0xFF8E8E93),
                ),
                SizedBox(height: 1.5.h),
                Text(
                  'auth_scan_gym_qr'.tr(context),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF3A3A3C),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'auth_point_camera_gym'.tr(context),
                  style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.only(start: 6.w, end: 6.w, bottom: 15.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 7.h),
          Text('🎉', style: TextStyle(fontSize: 36.sp)),
          SizedBox(height: 2.h),
          Container(
            width: 26.w,
            height: 26.w,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(8.w),
            ),
            child: Icon(Icons.check, color: Colors.white, size: 40.sp),
          ),
          SizedBox(height: 3.h),
          Text(
            'auth_welcome_nexus'.tr(context),
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              'auth_account_ready'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF6E6E73),
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 5.h),
          Wrap(
            spacing: 3.w,
            runSpacing: 2.h,
            alignment: WrapAlignment.center,
            children: [
              _buildBadge('auth_account_created'.tr(context)),
              _buildBadge('auth_role_set'.tr(context)),
              _buildBadge('auth_email_verified_badge'.tr(context)),
              _buildBadge('auth_gym_connected'.tr(context), isGreen: true),
            ],
          ),
          SizedBox(height: 8.h),
          ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1E),
              minimumSize: Size(double.infinity, 7.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.w),
              ),
            ),
            child: Text(
              'auth_go_dashboard'.tr(context),
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, {bool isGreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: isGreen ? const Color(0xFFE8FFF0) : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: isGreen ? const Color(0xFF1A7A30) : const Color(0xFF1C1C1E),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupControllerProvider);
    final isObscured = ref.watch(signupPasswordVisibilityProvider);

    ref.listen<SignupState>(signupControllerProvider, (prev, next) {
      if (prev?.currentStep != next.currentStep &&
          next.currentStep > 0 &&
          next.currentStep <= 5) {
        _pageController.animateToPage(
          next.currentStep - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!.tr(context)), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(top: 2.h, start: 4.w, end: 4.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _handlePrev(state),
                    child: Container(
                      width: 9.w,
                      height: 9.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 14.sp,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  if (state.currentStep < 5)
                    _buildStepIndicator(state.currentStep),
                  if (state.currentStep >= 5) SizedBox(width: 20.w),
                  if (state.currentStep == 4)
                    GestureDetector(
                      onTap: () => ref
                          .read(signupControllerProvider.notifier)
                          .nextStep(),
                      child: Text(
                        'auth_skip'.tr(context),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    )
                  else
                    SizedBox(width: 12.w),
                ],
              ),
            ),
            SizedBox(height: 1.h),
            Expanded(
              child: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1(isObscured, context),
                      _buildStep2(state.selectedRole, context),
                      _buildStep3(state, context),
                      _buildStep4(context),
                      _buildStep5(context),
                    ],
                  ),
                  if (state.currentStep < 5)
                    PositionedDirectional(
                      bottom: -1.h,
                      start: 0,
                      end: 0,
                      child: Container(
                        padding: EdgeInsetsDirectional.only(
                          start: 4.w,
                          end: 4.w,
                          bottom: 4.h,
                          top: 3.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.white,
                              Colors.white.withValues(alpha: 0.9),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: state.isLoading
                                    ? null
                                    : () => _handleNext(state, context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1C1C1E),
                                  padding: EdgeInsets.symmetric(
                                    vertical: 2.5.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4.w),
                                  ),
                                ),
                                child: state.isLoading
                                    ? _buildLoadingDumbbell()
                                    : Text(
                                        state.currentStep == 3
                                            ? 'auth_i_verified'.tr(context)
                                            : (state.currentStep == 4
                                                  ? 'auth_join_finish'.tr(context)
                                                  : 'auth_continue'.tr(context)),
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            if (state.currentStep == 4)
                              GestureDetector(
                                onTap: () => ref
                                    .read(signupControllerProvider.notifier)
                                    .nextStep(),
                                child: Text(
                                  'auth_skip_add_gym'.tr(context),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: const Color(0xFF8E8E93),
                                  ),
                                ),
                              ),
                            // if (state.currentStep == 1) Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Have an account? ", style: TextStyle(fontSize: 14.sp, color: Color(0xFF8E8E93))), GestureDetector(onTap: () => context.pop(), child: Text('Sign In', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: Color(0xFF007AFF))))]),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
