import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../providers/payment_provider.dart';

class SuccessStep extends ConsumerWidget {
  const SuccessStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentProvider);
    bool isYearly = state.billingCycle == BillingCycle.yearly;
    bool isPro = state.planType == PlanType.pro;
    String planName = isPro ? 'NEXUS Pro' : 'NEXUS Elite';

    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(6.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20.w,
            height: 20.w,
            decoration: const BoxDecoration(color: Color(0xFFE8FFF0), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('✅', style: TextStyle(fontSize: 30.sp)),
          ),
          SizedBox(height: 2.h),
          Text('payment_all_set'.tr(context), style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1C1C1E), letterSpacing: -0.5)),
          SizedBox(height: 1.h),
          Text(
            '${'payment_welcome_desc_1'.tr(context)} $planName ${'payment_welcome_desc_2'.tr(context)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF6E6E73), height: 1.5),
          ),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(4.w)),
            child: Column(
              children: [
                _recRow('payment_plan'.tr(context), '$planName · ${isYearly ? 'payment_yearly'.tr(context) : 'payment_monthly'.tr(context)}'),
                _recRow('payment_amount_charged'.tr(context), isYearly ? (isPro ? '47.88 JD' : '83.88 JD') : (isPro ? '8.11 JD' : '13.91 JD')),
                _recRow('payment_pm_label'.tr(context), 'payment_apple_pay'.tr(context)),
                _recRow('payment_receipt'.tr(context), 'ahmad@nexus.app'),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          Align(alignment: AlignmentDirectional.centerStart, child: Text('payment_now_unlocked'.tr(context), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E)))),
          SizedBox(height: 1.h),
          _unlockFeat('🤖', 'payment_feat_ai'.tr(context)),
          _unlockFeat('🍗', 'payment_feat_nutrition'.tr(context)),
          _unlockFeat('📊', 'payment_feat_analytics'.tr(context)),
          _unlockFeat('⌚', 'payment_feat_wearables'.tr(context)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(paymentProvider.notifier).reset();
                context.go('/hub'); // Or go back to profile
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5.w)),
              ),
              child: Text('payment_start_training'.tr(context), style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _recRow(String lbl, String val) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(lbl, style: TextStyle(fontSize: 11.sp, color: const Color(0xFF8E8E93))),
          Text(val, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
        ],
      ),
    );
  }

  Widget _unlockFeat(String emoji, String text) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(3.w)),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 16.sp)),
          SizedBox(width: 3.w),
          Text(text, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E))),
        ],
      ),
    );
  }
}
