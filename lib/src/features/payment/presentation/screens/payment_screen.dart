import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../providers/payment_provider.dart';
import 'payment_checkout_step.dart';
import 'payment_success_step.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    ref.read(paymentProvider.notifier).nextStep();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _prevStep() {
    ref.read(paymentProvider.notifier).previousStep();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (state.currentStep < 2) _buildTopBar(context, state.currentStep),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _PlanPickerStep(onNext: _nextStep),
                  CheckoutStep(onBack: _prevStep, onNext: _nextStep),
                  const SuccessStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, int step) {
    String title = step == 0 ? 'payment_choose_plan'.tr(context) : 'payment_checkout'.tr(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.5.h),
      color: const Color(0xFFF5F5F7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (step == 0) {
                Navigator.pop(context);
              } else {
                _prevStep();
              }
            },
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14.sp,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(width: 8.w), // To balance the back button
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// STEP 1: PLAN PICKER
// ---------------------------------------------------------
class _PlanPickerStep extends ConsumerWidget {
  final VoidCallback onNext;

  const _PlanPickerStep({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentProvider);
    final notifier = ref.read(paymentProvider.notifier);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(context),
              _buildBillingToggle(state.billingCycle, notifier, context),
              _buildPlanCards(state, notifier, context),
              _buildCompareTable(context),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
                child: Center(
                  child: Text(
                    'payment_cancel_no_fees'.tr(context),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFFC7C7CC),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildCTA(state, context),
      ],
    );
  }

  Widget _buildHero(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: const Color(0xFF007AFF), size: 14.sp),
              SizedBox(width: 1.w),
              Text(
                'payment_nexus_premium'.tr(context),
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'payment_unlock_potential'.tr(context),
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.2,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            'payment_hero_desc'.tr(context),
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.5,
              color: const Color(0xFF6E6E73),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle(BillingCycle cycle, PaymentNotifier notifier, BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(0.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        children: [
          _buildToggleBtn('payment_monthly'.tr(context), cycle == BillingCycle.monthly, () => notifier.setBillingCycle(BillingCycle.monthly), context),
          _buildToggleBtn('payment_yearly'.tr(context), cycle == BillingCycle.yearly, () => notifier.setBillingCycle(BillingCycle.yearly), context, showSave: true),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool isSelected, VoidCallback onTap, BuildContext context, {bool showSave = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 1.2.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(2.5.w),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
                ),
              ),
              if (showSave)
                PositionedDirectional(
                  top: -1.5.h,
                  end: -5.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Text(
                      'payment_save_40'.tr(context),
                      style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCards(PaymentState state, PaymentNotifier notifier, BuildContext context) {
    bool isYearly = state.billingCycle == BillingCycle.yearly;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          // BASIC
          _buildCard(
            planType: PlanType.basic,
            state: state,
            notifier: notifier,
            title: 'payment_basic'.tr(context),
            price: 'payment_free'.tr(context),
            period: 'payment_forever'.tr(context),
            bgColor: const Color(0xFFF9F9FB),
            borderColor: const Color(0xFFE5E5EA),
            titleColor: const Color(0xFF8E8E93),
            priceColor: const Color(0xFF1C1C1E),
            periodColor: const Color(0xFF8E8E93),
            featBg: Colors.white,
            featBorder: const Color(0xFFE5E5EA),
            features: [
              _feat('payment_workout_tracking'.tr(context), true, false),
              _feat('payment_3_workouts'.tr(context), true, false),
              _feat('payment_ai_coach'.tr(context), false, false),
              _feat('payment_form_analysis'.tr(context), false, false),
            ],
          ),
          SizedBox(height: 1.5.h),
          // PRO
          _buildCard(
            planType: PlanType.pro,
            state: state,
            notifier: notifier,
            title: 'payment_pro'.tr(context),
            price: isYearly ? '3.99 JD' : '6.99 JD',
            period: 'payment_per_month'.tr(context),
            was: isYearly ? 'payment_was_699'.tr(context) : null,
            badge: 'payment_most_popular'.tr(context),
            bgColor: const Color(0xFF1C1C1E),
            borderColor: const Color(0xFF007AFF),
            titleColor: Colors.white.withValues(alpha: 0.45),
            priceColor: Colors.white,
            periodColor: Colors.white.withValues(alpha: 0.5),
            wasColor: Colors.white.withValues(alpha: 0.3),
            featBg: Colors.white.withValues(alpha: 0.06),
            featBorder: Colors.white.withValues(alpha: 0.08),
            features: [
              _feat('payment_unlimited_workouts'.tr(context), true, true),
              _feat('payment_ai_coach_247'.tr(context), true, true),
              _feat('payment_nutrition_tracking'.tr(context), true, true),
              _feat('payment_progress_tracking'.tr(context), true, true),
              _feat('payment_video_form'.tr(context), false, true),
            ],
          ),
          SizedBox(height: 1.5.h),
          // ELITE
          _buildCard(
            planType: PlanType.elite,
            state: state,
            notifier: notifier,
            title: 'payment_elite'.tr(context),
            price: isYearly ? '6.99 JD' : '11.99 JD',
            period: 'payment_per_month'.tr(context),
            was: isYearly ? 'payment_was_1199'.tr(context) : null,
            gradient: const LinearGradient(colors: [Color(0xFF1a0a2e), Color(0xFF2d1b4e)]),
            borderColor: Colors.transparent,
            titleColor: const Color(0xFFFFD700).withValues(alpha: 0.6),
            priceColor: Colors.white,
            periodColor: Colors.white.withValues(alpha: 0.4),
            wasColor: Colors.white.withValues(alpha: 0.3),
            featBg: Colors.white.withValues(alpha: 0.06),
            featBorder: Colors.white.withValues(alpha: 0.1),
            features: [
              _feat('payment_everything_pro'.tr(context), true, true, isGold: true),
              _feat('payment_video_form_emoji'.tr(context), true, true, isGold: true),
              _feat('payment_human_coach'.tr(context), true, true, isGold: true),
              _feat('payment_pose_detection'.tr(context), true, true, isGold: true),
              _feat('payment_priority_support'.tr(context), true, true, isGold: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _feat(String label, bool active, bool isDark, {bool isGold = false}) {
    Color activeColor = isGold ? const Color(0xFFFFD700) : const Color(0xFF34C759);
    Color activeBg = activeColor.withValues(alpha: 0.2);
    Color inactiveColor = isDark ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFC7C7CC);
    Color inactiveBg = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF5F5F7);
    return Padding(
      padding: EdgeInsets.only(bottom: 0.8.h),
      child: Row(
        children: [
          Container(
            width: 4.5.w,
            height: 4.5.w,
            decoration: BoxDecoration(
              color: active ? activeBg : inactiveBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: active
                ? Icon(Icons.check, color: activeColor, size: 10.sp)
                : Icon(Icons.close, color: inactiveColor, size: 10.sp),
          ),
          SizedBox(width: 2.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: active ? (isDark ? Colors.white : const Color(0xFF3A3A3C)) : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required PlanType planType,
    required PaymentState state,
    required PaymentNotifier notifier,
    required String title,
    required String price,
    required String period,
    String? was,
    String? badge,
    Color? bgColor,
    LinearGradient? gradient,
    required Color borderColor,
    required Color titleColor,
    required Color priceColor,
    required Color periodColor,
    Color? wasColor,
    required Color featBg,
    required Color featBorder,
    required List<Widget> features,
  }) {
    bool isSel = state.planType == planType;
    return GestureDetector(
      onTap: () => notifier.setPlan(planType),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: bgColor,
          gradient: gradient,
          borderRadius: BorderRadius.circular(5.w),
          border: Border.all(color: isSel ? (planType == PlanType.pro ? borderColor : Colors.white) : (gradient == null ? borderColor : Colors.transparent), width: 2),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, badge != null ? 3.h : 2.h, 4.w, 1.5.h),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (badge != null)
                    PositionedDirectional(
                      top: -4.h,
                      start: 0,
                      end: 0,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF007AFF),
                            borderRadius: BorderRadius.circular(2.w),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: titleColor),
                          ),
                          SizedBox(height: 0.5.h),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(price, style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w900, letterSpacing: -1, color: priceColor)),
                              SizedBox(width: 1.w),
                              Text(period, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: periodColor)),
                            ],
                          ),
                          if (was != null)
                            Padding(
                              padding: EdgeInsets.only(top: 0.2.h),
                              child: Text(was, style: TextStyle(fontSize: 12.sp, decoration: TextDecoration.lineThrough, color: wasColor)),
                            ),
                        ],
                      ),
                      Container(
                        width: 6.w,
                        height: 6.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? (planType == PlanType.basic ? const Color(0xFF1C1C1E) : Colors.white) : Colors.transparent,
                          border: Border.all(color: isSel ? Colors.transparent : titleColor.withValues(alpha: 0.3), width: 2),
                        ),
                        child: isSel
                            ? Icon(Icons.circle, color: planType == PlanType.pro || planType == PlanType.elite ? const Color(0xFF1C1C1E) : Colors.white, size: 8.sp)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: featBg,
                border: Border(top: BorderSide(color: featBorder)),
              ),
              child: Column(children: features),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareTable(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
            child: Row(
              children: [
                Expanded(child: Text('payment_feature'.tr(context), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93)))),
                SizedBox(width: 14.w, child: Text('payment_basic_table'.tr(context), textAlign: TextAlign.center, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93)))),
                SizedBox(width: 14.w, child: Text('payment_pro_table'.tr(context), textAlign: TextAlign.center, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E)))),
                SizedBox(width: 14.w, child: Text('payment_elite_table'.tr(context), textAlign: TextAlign.center, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF7B2FBE)))),
              ],
            ),
          ),
          _cmpRow('payment_workout_tracking'.tr(context), true, true, true),
          _cmpRow('payment_ai_coach'.tr(context), false, true, true),
          _cmpRow('payment_nutrition_macros'.tr(context), false, true, true),
          _cmpRow('payment_wearables_sync'.tr(context), false, true, true),
          _cmpRow('payment_form_analysis_ai'.tr(context), false, false, true),
          _cmpRow('payment_human_coach'.tr(context), false, false, true, last: true),
        ],
      ),
    );
  }

  Widget _cmpRow(String feat, bool b, bool p, bool e, {bool last = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF8F8F8)))),
      child: Row(
        children: [
          Expanded(child: Text(feat, style: TextStyle(fontSize: 12.sp, color: const Color(0xFF3A3A3C)))),
          SizedBox(width: 14.w, child: Text(b ? '✓' : '✕', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: b ? const Color(0xFF1C1C1E) : const Color(0xFFC7C7CC)))),
          SizedBox(width: 14.w, child: Text(p ? '✓' : '✕', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: p ? const Color(0xFF1C1C1E) : const Color(0xFFC7C7CC)))),
          SizedBox(width: 14.w, child: Text(e ? '✓' : '✕', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: e ? const Color(0xFF7B2FBE) : const Color(0xFFC7C7CC)))),
        ],
      ),
    );
  }

  Widget _buildCTA(PaymentState state, BuildContext context) {
    if (state.planType == PlanType.basic) return const SizedBox.shrink();
    String btnText = state.planType == PlanType.pro ? 'payment_continue_pro'.tr(context) : 'payment_continue_elite'.tr(context);
    return PositionedDirectional(
      bottom: 0,
      start: 0,
      end: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFF5F5F7), const Color(0xFFF5F5F7).withValues(alpha: 0)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: ElevatedButton(
          onPressed: onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1C1E),
            padding: EdgeInsets.symmetric(vertical: 2.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5.w)),
          ),
          child: Text(btnText, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ),
    );
  }
}
