// lib/src/features/auth/presentation/screens/change_password_screen.dart
//
// Shown automatically when a player logs in with a coach-assigned temporary
// password (UserModel.temporaryPasswordSet == true).
//
// The GoRouter redirect in app_router.dart blocks all other routes until the
// player completes this screen.
//
// Flow
// ────
// 1. Player signs in with the temporary password the coach shared.
// 2. GoRouter redirect detects temporaryPasswordSet == true and sends them here.
// 3. Player sets a new password (min 8 chars).
// 4. On success:
//      a. FirebaseAuth.updatePassword() updates the credential.
//      b. Firestore users/{uid}.temporaryPasswordSet = false is cleared.
//      c. GoRouter refreshes and sends the player to /dashboard.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/router/app_router.dart'
    show completeRequiredPasswordChange, isLogin2FAPending;

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'session_expired'.tr(context));
        return;
      }

      // 1. Update Firebase Auth password
      await user.updatePassword(_newPassCtrl.text.trim());

      // 2. Clear the temporary-password flag in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'temporaryPasswordSet': false},
      );

      completeRequiredPasswordChange();

      if (!mounted) return;
      if (isLogin2FAPending) {
        context.go('/phone_2fa');
      } else {
        context.go('/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.code == 'requires-recent-login'
            ? 'auth_relogin_required'.tr(context)
            : e.message ?? 'auth_unknown_error'.tr(context);
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false, // no back — this screen is mandatory
        title: Text(
          'change_password'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF1C1C1E)),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Explanation banner ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A64B0).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF0A64B0).withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: const Color(0xFF0A64B0),
                        size: 18.sp,
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Text(
                          'temp_password_notice'.tr(context),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF0A64B0),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 4.h),

                // ── New password ────────────────────────────────────────────
                Text(
                  'new_password'.tr(context),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 1.h),
                TextFormField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNew,
                  style: TextStyle(color: Colors.black, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: 'password_min_8'.tr(context),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF8E8E93),
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'field_required'.tr(context);
                    }
                    if (v.trim().length < 8) {
                      return 'password_min_8'.tr(context);
                    }
                    return null;
                  },
                ),

                SizedBox(height: 2.5.h),

                // ── Confirm password ────────────────────────────────────────
                Text(
                  'confirm_password'.tr(context),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 1.h),
                TextFormField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirm,
                  style: TextStyle(color: Colors.black, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: 'confirm_password'.tr(context),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF8E8E93),
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'field_required'.tr(context);
                    }
                    if (v.trim() != _newPassCtrl.text.trim()) {
                      return 'passwords_do_not_match'.tr(context);
                    }
                    return null;
                  },
                ),

                // ── Error message ───────────────────────────────────────────
                if (_errorMessage != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 11.sp),
                  ),
                ],

                SizedBox(height: 4.h),

                // ── Submit button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A64B0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'save_password'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
