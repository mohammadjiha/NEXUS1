import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../../../core/localization/app_localizations.dart';

class SubscriptionExpiredScreen extends ConsumerWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon ──────────────────────────────────────────────────────
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timer_off_rounded,
                  size: 14.w,
                  color: const Color(0xFFFF9500),
                ),
              ),
              SizedBox(height: 4.h),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                'subscription_expired_title'.tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2.h),

              // ── Description ───────────────────────────────────────────────
              Text(
                'subscription_expired_desc'.tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.white54,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 3.h),

              // ── Info box ──────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(3.w),
                  border: Border.all(
                      color: const Color(0xFFFF9500).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: const Color(0xFFFF9500), size: 14.sp),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'renew_contact_gym'.tr(context),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFFFF9500).withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4.h),

              // ── Sign out ──────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).signOut();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                  ),
                  child: Text(
                    'logout'.tr(context),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
