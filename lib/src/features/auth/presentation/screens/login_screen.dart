import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/shared_preferences_provider.dart';
import '../../../../core/router/app_router.dart'
    show prepareLogin2FA, isLogin2FAPending;
import '../../../../core/utils/firebase_auth_error_mapper.dart';
import '../../../../core/utils/role_utils.dart';
import '../../../user/data/user_repository.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialEmail;

  const LoginScreen({super.key, this.initialEmail});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isEmailOk = false;
  bool _isPasswordOk = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      final isOk =
          _emailController.text.contains('@') &&
          _emailController.text.contains('.');
      if (_isEmailOk != isOk) setState(() => _isEmailOk = isOk);
    });
    _passwordController.addListener(() {
      final isOk = _passwordController.text.length >= 8;
      if (_isPasswordOk != isOk) setState(() => _isPasswordOk = isOk);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = ref.read(sharedPreferencesProvider);
      final rememberMe = prefs.getBool('remember_me') ?? false;
      if (widget.initialEmail != null &&
          widget.initialEmail!.trim().isNotEmpty) {
        _emailController.text = widget.initialEmail!.trim();
        return;
      }
      if (rememberMe) {
        final savedEmail = prefs.getString('saved_email');
        // Passwords are never persisted — only the email is restored
        setState(() {
          _rememberMe = true;
          if (savedEmail != null) _emailController.text = savedEmail;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    context.push('/forgot_phone');
  }

  void _submit(BuildContext context) {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth_fill_fields'.tr(context)),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    if (_rememberMe) {
      prefs.setBool('remember_me', true);
      prefs.setString('saved_email', _emailController.text.trim());
      // Never store the password — Firebase handles session persistence automatically
    } else {
      prefs.setBool('remember_me', false);
      prefs.remove('saved_email');
      prefs.remove('saved_password'); // Remove any previously stored password
    }

    final pendingGymId = ref.read(pendingGymIdProvider);
    // Arm the 2FA trigger — if the user has a phone in Firestore, the router
    // will redirect to /phone_2fa immediately after auth state changes.
    prepareLogin2FA();
    ref
        .read(authControllerProvider.notifier)
        .signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          requiredGymId: pendingGymId,
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
        padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            SizedBox(width: 2.w),
            Text(
              text,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isPassword = false,
    bool isFocusedBlue = false,
    bool isOk = false,
    IconData? prefixIcon,
    Color? prefixIconColor,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: 1.w),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3A3A3C),
              letterSpacing: 0.5,
            ),
          ),
        ),
        SizedBox(height: 0.7.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOk
                  ? const Color(0xFF34C759)
                  : (isFocusedBlue
                        ? const Color(0xFF007AFF)
                        : const Color(0xFFE5E5EA)),
              width: isOk || isFocusedBlue ? 1.5 : 1,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.3.h),
          child: Row(
            children: [
              if (prefixIcon != null) ...[
                Icon(
                  prefixIcon,
                  color: prefixIconColor ?? const Color(0xFF8E8E93),
                  size: 18,
                ),
                SizedBox(width: 2.5.w),
              ],
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1C1C1E),
                  ),
                  cursorColor: const Color(0xFF1C1C1E),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: const Color(0xFFC7C7CC),
                      fontSize: 16.sp,
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
                    contentPadding: EdgeInsets.symmetric(vertical: 1.3.h),
                  ),
                ),
              ),
              if (isOk && !isPassword)
                const Icon(Icons.check, color: Color(0xFF34C759), size: 18),
              if (isPassword)
                GestureDetector(
                  onTap: onToggleVisibility,
                  child: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFFC7C7CC),
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final isObscured = ref.watch(loginPasswordVisibilityProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (prev, state) async {
      if (!state.isLoading &&
          !state.hasError &&
          state.hasValue &&
          prev != null &&
          prev.isLoading) {
        ref.read(pendingGymIdProvider.notifier).set(null);
        ref.read(pendingGymCodeProvider.notifier).set(null);

        // If 2FA is pending the router already redirected to /phone_2fa.
        // Skip manual navigation here — let VerifyPhone2FAScreen handle it.
        if (isLogin2FAPending) return;

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userRepo = ref.read(userRepositoryProvider);
          final userModel = await userRepo.getUser(user.uid);
          final role = userModel?.role?.toLowerCase() ?? 'player';

          if (!context.mounted) return;
          if (AppRole.isSuperAdmin(role)) {
            context.go('/super_admin');
          } else if (role == AppRole.admin || role == AppRole.owner || role == AppRole.gymAdmin) {
            context.go('/admin');
          } else if (AppRole.isPrivileged(role)) {
            context.go('/coach_dashboard');
          } else {
            context.go('/dashboard');
          }
        } else {
          if (!context.mounted) return;
          context.go('/dashboard');
        }
      }
      if (state.hasError && !state.isLoading) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              FirebaseAuthErrorMapper.toMessage(context, state.error!),
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.5.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── زر الرجوع ──
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: GestureDetector(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/onboarding');
                      }
                    },
                    child: Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE5E5EA),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 3.h),

                // ── لوغو ──
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: SizedBox(
                    width: 14.w,
                    height: 7.h,

                    child: Image.asset(
                      'assets/images/nexus_logo.png',
                      width: 9.w,
                      height: 4.5.h,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.change_history,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 2.5.h),

                // ── العنوان ──
                Text(
                  'auth_welcome_back'.tr(context),
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 0.7.h),
                Text(
                  'auth_sign_in_desc'.tr(context),
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: const Color(0xFF6E6E73),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 3.h),
                // ── حقل البريد الإلكتروني ──
                _buildInputField(
                  label: 'auth_email'.tr(context),
                  hint: 'auth_email_hint'.tr(context),
                  controller: _emailController,
                  isFocusedBlue: _isEmailOk,
                  isOk: _isEmailOk,
                  prefixIcon: Icons.email_outlined,
                  prefixIconColor: _isEmailOk
                      ? const Color(0xFF007AFF)
                      : const Color(0xFF8E8E93),
                ),

                SizedBox(height: 2.h),

                // ── حقل كلمة المرور ──
                _buildInputField(
                  label: 'auth_password'.tr(context),
                  hint: 'auth_password_hint'.tr(context),
                  controller: _passwordController,
                  isPassword: true,
                  isOk: _isPasswordOk,
                  obscureText: isObscured,
                  onToggleVisibility: () => ref
                      .read(loginPasswordVisibilityProvider.notifier)
                      .toggle(),
                  prefixIcon: Icons.lock_outline,
                  prefixIconColor: _isPasswordOk
                      ? const Color(0xFF34C759)
                      : const Color(0xFF8E8E93),
                ),

                SizedBox(height: 1.h),

                // ── تذكرني & نسيت كلمة المرور ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _rememberMe = val);
                              }
                            },
                            activeColor: const Color(0xFF1C1C1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: const BorderSide(
                              color: Color(0xFFC7C7CC),
                              width: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'auth_remember_me'.tr(context),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _showForgotPasswordDialog(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'auth_forgot_password'.tr(context),
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF007AFF),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 3.h),

                // ── زر تسجيل الدخول ──
                GestureDetector(
                  onTap: isLoading ? null : () => _submit(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'auth_sign_in'.tr(context),
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
