import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/localization/app_localizations.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ── المحتوى المركزي ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // لوغو
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.w),
                    child: Image.asset(
                      'assets/images/nexus_logo.png',
                      width: 25.w,
                      height: 25.w,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 0.h),
                   Text('NEXUS',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -1,
                    ),
                  ),
                  SizedBox(height: 1.5.h),
                   Text(
                    'onboarding_subtitle'.tr(context),
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: const Color(0xFF6E6E73),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _pill('onboarding_pill_ai'.tr(context)),
                      SizedBox(width: 2.w),
                      _pill('onboarding_pill_gym'.tr(context)),
                      SizedBox(width: 2.w),
                      _pill('onboarding_pill_analytics'.tr(context)),
                    ],
                  ),
                ],
              ),
            ),

            // ── الأزرار في الأسفل ──
            PositionedDirectional(
              bottom: 5.h,
              start: 4.w,
              end: 4.w,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        padding: EdgeInsets.symmetric(vertical: 2.5.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.w)),
                      ),
                      onPressed: () => context.push('/onboarding_gym'),
                      child:  Text(
                        'onboarding_get_started'.tr(context),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(5.w),
        border: Border.all(color: const Color(0xFFD1D1D6), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF3A3A3C),
        ),
      ),
    );
  }
}
