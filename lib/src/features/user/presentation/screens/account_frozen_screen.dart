import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class AccountFrozenScreen extends ConsumerWidget {
  const AccountFrozenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final freezeDays   = user?.freezeDays ?? 0;
    final freezeReason = user?.freezeReason ?? '';
    final frozenAt     = user?.frozenAt;

    // تاريخ انتهاء التجميد = frozenAt + freezeDays
    DateTime? freezeUntil;
    if (frozenAt != null && freezeDays > 0) {
      freezeUntil = frozenAt.add(Duration(days: freezeDays));
    }

    final untilStr = freezeUntil != null
        ? DateFormat('MMMM d, yyyy').format(freezeUntil)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon ─────────────────────────────────────────────────────
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF5BA8FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.ac_unit_rounded,
                  size: 14.w,
                  color: const Color(0xFF5BA8FF),
                ),
              ),
              SizedBox(height: 4.h),

              // ── Title ─────────────────────────────────────────────────────
              Text(
                'Subscription Frozen ❄️',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 1.5.h),

              // ── Until date ────────────────────────────────────────────────
              if (untilStr != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5BA8FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3.w),
                    border: Border.all(
                      color: const Color(0xFF5BA8FF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          color: const Color(0xFF5BA8FF), size: 13.sp),
                      SizedBox(width: 2.w),
                      Text(
                        'Frozen until $untilStr',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5BA8FF),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 2.5.h),

              // ── Description ───────────────────────────────────────────────
              Text(
                'Your gym subscription is temporarily frozen'
                '${freezeReason.isNotEmpty ? ' due to: $freezeReason' : ''}.'
                '\n\nYour subscription end date will be automatically extended once the freeze is lifted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.white54,
                  height: 1.6,
                ),
              ),

              SizedBox(height: 4.h),

              // ── Info box ──────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(3.w),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.white38, size: 14.sp),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'To unfreeze your account early, contact your gym admin.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white38,
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
                    'Sign Out',
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
