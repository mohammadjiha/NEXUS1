import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

enum _Step { phone, otp, newPassword }

class ForgotPhoneScreen extends StatefulWidget {
  const ForgotPhoneScreen({super.key});

  @override
  State<ForgotPhoneScreen> createState() => _ForgotPhoneScreenState();
}

class _ForgotPhoneScreenState extends State<ForgotPhoneScreen> {
  final _phoneController    = TextEditingController();
  final _otpController      = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  _Step   _step          = _Step.phone;
  bool    _isLoading     = false;
  String? _error;

  String? _verificationId;
  int?    _resendToken;

  Timer? _resendTimer;
  int    _resendSeconds = 0;

  bool _showPassword = false;
  bool _showConfirm  = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _normalizePhone(String input) {
    var v = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (v.startsWith('00')) v = '+${v.substring(2)}';
    if (v.startsWith('+')) return v;
    if (v.startsWith('962')) return '+$v';
    if (v.startsWith('0')) return '+962${v.substring(1)}';
    return '+962$v';
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  String _functionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'not-found':
        return 'لا يوجد حساب مرتبط بهذا الرقم.';
      case 'unauthenticated':
      case 'failed-precondition':
        return 'انتهت جلسة التحقق. ارجع وابدأ من جديد.';
      case 'invalid-argument':
        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.';
      case 'internal':
        return 'خطأ داخلي. تواصل مع المدرب.';
      default:
        return 'حدث خطأ. حاول مرة أخرى.';
    }
  }

  String _authError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'رمز OTP غير صحيح.';
      case 'session-expired':
        return 'انتهت صلاحية الرمز. اضغط "إعادة إرسال".';
      case 'too-many-requests':
        return 'تم إيقاف الطلبات مؤقتاً. انتظر قليلاً.';
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صحيح.';
      case 'invalid-app-credential':
      case 'app-not-authorized':
        return 'تعذر التحقق من التطبيق. تأكد من إعدادات Firebase.';
      default:
        return 'حدث خطأ. حاول مرة أخرى.';
    }
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Send OTP
  // ---------------------------------------------------------------------------

  Future<void> _sendOtp({bool isResend = false}) async {
    final phone = _normalizePhone(_phoneController.text);
    if (phone.length < 10) {
      setState(() => _error = 'أدخل رقم هاتف صحيح.');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: isResend ? _resendToken : null,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _signInWithCredential(credential);
      },
      verificationFailed: (e) {
        debugPrint('[ForgotPhone] verificationFailed: code=${e.code} msg=${e.message}');
        if (!mounted) return;
        setState(() { _isLoading = false; _error = _authError(e); });
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken    = resendToken;
          _isLoading      = false;
          if (!isResend) _step = _Step.otp;
          _error = null;
        });
        _startResendCountdown();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Verify OTP
  // ---------------------------------------------------------------------------

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    final vid  = _verificationId;
    if (vid == null || code.length < 4) {
      setState(() => _error = 'أدخل رمز التحقق.');
      return;
    }
    await _signInWithCredential(
      PhoneAuthProvider.credential(verificationId: vid, smsCode: code),
    );
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      setState(() { _isLoading = false; _step = _Step.newPassword; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = _authError(e); });
    } catch (_) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'حدث خطأ. حاول مرة أخرى.'; });
    }
  }

  // ---------------------------------------------------------------------------
  // Step 3 — Reset Password via Cloud Function
  // ---------------------------------------------------------------------------

  Future<void> _resetPassword() async {
    final pass    = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('resetPasswordViaPhone');
      final result = await callable.call({'newPassword': pass});
      final email  = (result.data as Map<String, dynamic>?)?['email'] as String?;

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور بنجاح. يمكنك الدخول الآن.'),
          backgroundColor: Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Redirect to login with email pre-filled — user only needs to type new password
      final emailParam = (email != null && email.isNotEmpty)
          ? '?email=${Uri.encodeComponent(email)}'
          : '';
      context.go('/login$emailParam');
    } on FirebaseFunctionsException catch (e) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() { _isLoading = false; _error = _functionError(e); });
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'حدث خطأ. حاول مرة أخرى.'; });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () {
              if (_step == _Step.otp) {
                setState(() { _step = _Step.phone; _error = null; });
              } else if (_step == _Step.newPassword) {
                setState(() { _step = _Step.otp; _error = null; });
              } else {
                context.pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  _Step.phone       => _buildPhoneStep(),
                  _Step.otp         => _buildOtpStep(),
                  _Step.newPassword => _buildPasswordStep(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step widgets
  // ---------------------------------------------------------------------------

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'استرجاع الحساب',
          subtitle: 'أدخل رقم الهاتف المرتبط بحسابك وسنرسل لك رمز OTP للتحقق.',
        ),
        SizedBox(height: 4.h),
        _inputField(
          controller: _phoneController,
          label: 'رقم الهاتف',
          hint: '+9627xxxxxxxx',
          icon: Icons.phone_iphone_rounded,
          keyboard: TextInputType.phone,
        ),
        _errorWidget(),
        SizedBox(height: 4.h),
        _primaryButton(
          label: 'إرسال رمز OTP',
          onPressed: _sendOtp,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    final displayPhone = _normalizePhone(_phoneController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'رمز التحقق',
          subtitle: 'أدخل الرمز المرسل إلى $displayPhone',
        ),
        SizedBox(height: 4.h),
        _inputField(
          controller: _otpController,
          label: 'رمز OTP',
          hint: '123456',
          icon: Icons.password_rounded,
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        _errorWidget(),
        SizedBox(height: 2.h),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _resendSeconds > 0
              ? Text(
                  'إعادة الإرسال بعد $_resendSeconds ثانية',
                  style: TextStyle(fontSize: 13.sp, color: const Color(0xFF6E6E73)),
                )
              : TextButton(
                  onPressed: _isLoading ? null : () => _sendOtp(isResend: true),
                  child: Text(
                    'إعادة إرسال الرمز',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
        ),
        SizedBox(height: 3.h),
        _primaryButton(
          label: 'تأكيد الرمز',
          onPressed: _verifyOtp,
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          title: 'كلمة المرور الجديدة',
          subtitle: 'أدخل كلمة مرور جديدة لحسابك. يجب أن تكون 6 أحرف على الأقل.',
        ),
        SizedBox(height: 4.h),
        _passwordField(
          controller: _passwordController,
          label: 'كلمة المرور الجديدة',
          show: _showPassword,
          onToggle: () => setState(() => _showPassword = !_showPassword),
        ),
        SizedBox(height: 2.h),
        _passwordField(
          controller: _confirmController,
          label: 'تأكيد كلمة المرور',
          show: _showConfirm,
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
        ),
        _errorWidget(),
        SizedBox(height: 4.h),
        _primaryButton(
          label: 'تغيير كلمة المرور',
          onPressed: _resetPassword,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable sub-widgets
  // ---------------------------------------------------------------------------

  Widget _stepHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13.sp, height: 1.6, color: const Color(0xFF6E6E73)),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      textDirection: TextDirection.ltr,
      decoration: _decoration(label: label, hint: hint, prefix: Icon(icon)),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !show,
      textDirection: TextDirection.ltr,
      decoration: _decoration(
        label: label,
        hint: '••••••',
        prefix: const Icon(Icons.lock_outline_rounded),
        suffix: IconButton(
          icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: onToggle,
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required Widget prefix,
    Widget? suffix,
  }) {
    const radius = BorderRadius.all(Radius.circular(14));
    const side   = BorderSide(color: Color(0xFFE5E5EA));
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      border:        const OutlineInputBorder(borderRadius: radius, borderSide: side),
      enabledBorder: const OutlineInputBorder(borderRadius: radius, borderSide: side),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Color(0xFF1C1C1E), width: 1.5),
      ),
    );
  }

  Widget _errorWidget() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 1.5.h),
      child: Text(
        _error!,
        style: TextStyle(
          color: const Color(0xFFE53935),
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1C1C1E),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF1C1C1E).withAlpha(100),
          padding: EdgeInsets.symmetric(vertical: 2.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(label, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
