import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/router/app_router.dart'
    show completeLogin2FA, getAuthRole;
import '../../../../core/utils/role_utils.dart';
import '../../../user/data/user_repository.dart';
import '../../data/auth_repository.dart' show currentUserModelProvider;

class VerifyPhone2FAScreen extends ConsumerStatefulWidget {
  const VerifyPhone2FAScreen({super.key});

  @override
  ConsumerState<VerifyPhone2FAScreen> createState() =>
      _VerifyPhone2FAScreenState();
}

class _VerifyPhone2FAScreenState extends ConsumerState<VerifyPhone2FAScreen> {
  final _otpCtrl = TextEditingController();

  String? _phone;
  String? _verificationId;
  int? _resendToken;
  bool _isLoading = true;
  bool _otpSent = false;
  String? _error;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadPhoneAndSend();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Load phone from Firestore, then send OTP
  // ---------------------------------------------------------------------------
  Future<void> _loadPhoneAndSend() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _abortAndGoLogin();
      return;
    }

    // Try the already-loaded Riverpod stream first (fast path)
    final cachedModel = ref.read(currentUserModelProvider).asData?.value;
    String? phone = cachedModel?.phone?.trim();

    // Fallback: direct Firestore read
    if (phone == null || phone.isEmpty) {
      try {
        final model = await ref.read(userRepositoryProvider).getUser(user.uid);
        phone = model?.phone?.trim();
      } catch (_) {}
    }

    if (phone == null || phone.isEmpty) {
      // No phone on record — skip 2FA
      _finishVerification();
      return;
    }

    _phone = _normalizePhone(phone);
    await _sendOtp();
  }

  String _normalizePhone(String input) {
    var v = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (v.startsWith('00')) v = '+${v.substring(2)}';
    if (v.startsWith('+')) return v;
    if (v.startsWith('962')) return '+$v';
    if (v.startsWith('0')) return '+962${v.substring(1)}';
    return '+962$v';
  }

  void _startCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    final phone = _phone;
    if (phone == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (kDebugMode) {
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
      }

      await FirebaseAuth.instance
          .verifyPhoneNumber(
            phoneNumber: phone,
            forceResendingToken: isResend ? _resendToken : null,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (credential) async {
              await _verifyCredential(credential);
            },
            verificationFailed: (e) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _error = _authError(e);
              });
            },
            codeSent: (verificationId, resendToken) {
              if (!mounted) return;
              setState(() {
                _verificationId = verificationId;
                _resendToken = resendToken;
                _isLoading = false;
                _otpSent = true;
                _error = null;
              });
              _startCountdown();
            },
            codeAutoRetrievalTimeout: (verificationId) {
              _verificationId = verificationId;
              if (!mounted || _otpSent) return;
              setState(() {
                _isLoading = false;
                _error = 'انتهى وقت الإرسال. اضغط إعادة إرسال الرمز.';
              });
            },
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      if (!mounted || _otpSent) return;
      setState(() {
        _isLoading = false;
        _error = 'إرسال رمز OTP استغرق وقتاً طويلاً. حاول مرة أخرى.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _authError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تعذر إرسال رمز OTP: $e';
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    final vid = _verificationId;
    if (vid == null || code.length < 4) {
      setState(() => _error = 'أدخل رمز التحقق.');
      return;
    }
    try {
      await _verifyCredential(
        PhoneAuthProvider.credential(verificationId: vid, smsCode: code),
      ).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تأكيد رمز OTP استغرق وقتاً طويلاً. حاول مرة أخرى.';
      });
    }
  }

  Future<void> _verifyCredential(PhoneAuthCredential credential) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _abortAndGoLogin();
        return;
      }

      await currentUser
          .updatePhoneNumber(credential)
          .timeout(const Duration(seconds: 12));
      _finishVerification();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'تأكيد رقم الهاتف استغرق وقتاً طويلاً. حاول مرة أخرى.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'provider-already-linked' ||
          e.code == 'credential-already-in-use') {
        _finishVerification();
        return;
      }
      setState(() {
        _isLoading = false;
        _error = _authError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'حدث خطأ: $e';
      });
    }
  }

  void _finishVerification() {
    completeLogin2FA();
    if (!mounted) return;
    final role = getAuthRole()?.toLowerCase();

    // للاعبين: تحقق من الحالة قبل التوجيه
    if (!AppRole.isSuperAdmin(role) &&
        role != AppRole.admin &&
        role != AppRole.owner &&
        role != AppRole.gymAdmin &&
        !AppRole.isPrivileged(role)) {
      final userModel = ref.read(currentUserModelProvider).asData?.value;
      if (userModel != null) {
        if (userModel.isFrozen) {
          context.go('/account_frozen');
          return;
        }
        if (userModel.isActive == false) {
          context.go('/account_suspended');
          return;
        }
      }
    }

    if (AppRole.isSuperAdmin(role)) {
      context.go('/super_admin');
    } else if (role == AppRole.admin || role == AppRole.owner || role == AppRole.gymAdmin) {
      context.go('/admin');
    } else if (AppRole.isPrivileged(role)) {
      context.go('/coach_dashboard');
    } else {
      context.go('/dashboard');
    }
  }

  void _abortAndGoLogin() {
    completeLogin2FA();
    FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/login');
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
        return 'رقم الهاتف غير صحيح. تواصل مع الدعم.';
      case 'invalid-app-credential':
      case 'app-not-authorized':
        return 'تعذر التحقق من التطبيق. تأكد من إعدادات Firebase.';
      default:
        return 'حدث خطأ: ${e.code}. حاول مرة أخرى.';
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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Cancel / go back ─────────────────────────────────────────
                      GestureDetector(
                        onTap: _abortAndGoLogin,
                        child: Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 16,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),

                      // ── Shield icon ───────────────────────────────────────────────
                      Container(
                        width: 16.w,
                        height: 16.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5FF),
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.shield_outlined,
                          size: 28.sp,
                          color: const Color(0xFF007AFF),
                        ),
                      ),
                      SizedBox(height: 2.h),

                      // ── Title ─────────────────────────────────────────────────────
                      Text(
                        'التحقق بخطوتين',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        _phone != null
                            ? 'أدخل رمز OTP المرسل إلى $_phone'
                            : 'جاري إرسال رمز التحقق...',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF6E6E73),
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 5.h),

                      // ── Body ─────────────────────────────────────────────────────
                      if (_isLoading && !_otpSent)
                        const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF007AFF),
                          ),
                        )
                      else ...[
                        // OTP input
                        TextField(
                          controller: _otpCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 6,
                          textDirection: TextDirection.ltr,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 10,
                            color: const Color(0xFF1C1C1E),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '- - - - - -',
                            hintStyle: TextStyle(
                              fontSize: 26.sp,
                              color: const Color(0xFFC7C7CC),
                              letterSpacing: 10,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(vertical: 2.h),
                          ),
                        ),
                        SizedBox(height: 1.5.h),

                        if (_error != null)
                          Text(
                            _error!,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: const Color(0xFFE53935),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        SizedBox(height: 1.h),

                        // Resend timer
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _resendSeconds > 0
                              ? Text(
                                  'إعادة الإرسال بعد $_resendSeconds ثانية',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: const Color(0xFF8E8E93),
                                  ),
                                )
                              : TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _sendOtp(isResend: true),
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
                        SizedBox(height: 4.h),

                        // Confirm button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1C1C1E),
                              disabledBackgroundColor: const Color(
                                0xFF1C1C1E,
                              ).withAlpha(100),
                              padding: EdgeInsets.symmetric(vertical: 2.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'تأكيد وتسجيل الدخول',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 1.5.h),

                        // Cancel
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _abortAndGoLogin,
                            child: Text(
                              'إلغاء وتسجيل الخروج',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
