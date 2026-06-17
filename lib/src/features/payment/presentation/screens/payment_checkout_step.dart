import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../providers/payment_provider.dart';

class CheckoutStep extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const CheckoutStep({super.key, required this.onBack, required this.onNext});

  @override
  ConsumerState<CheckoutStep> createState() => _CheckoutStepState();
}

class _CheckoutStepState extends ConsumerState<CheckoutStep> {
  bool _isProcessing = false;
  bool _promoApplied = false;

  void _processPayment() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isProcessing = false);
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentProvider);
    final notifier = ref.read(paymentProvider.notifier);

    bool isYearly = state.billingCycle == BillingCycle.yearly;
    bool isPro = state.planType == PlanType.pro;

    String planName = isPro ? 'NEXUS Pro' : 'NEXUS Elite';
    String billing = isYearly ? 'payment_billed_annually'.tr(context) : 'payment_billed_monthly'.tr(context);
    String total = isYearly ? (isPro ? '47.88 JD' : '83.88 JD') : (isPro ? '8.11 JD' : '13.91 JD');
    String period = isYearly ? (isPro ? 'then 47.88 JD/year' : 'then 83.88 JD/year') : (isPro ? 'then 8.11 JD/month' : 'then 13.91 JD/month');
    String savings = isYearly ? (isPro ? 'payment_you_save_pro'.tr(context) : 'payment_you_save_elite'.tr(context)) : '';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary
              Container(
                margin: EdgeInsets.all(4.w),
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(5.w)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('payment_order_summary'.tr(context), style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.7)),
                    SizedBox(height: 0.5.h),
                    Text('$planName — ${isYearly ? 'payment_yearly'.tr(context) : 'payment_monthly'.tr(context)}', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4)),
                    SizedBox(height: 0.2.h),
                    Text(billing, style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.45))),
                    SizedBox(height: 1.5.h),
                    Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                    SizedBox(height: 1.5.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('payment_total_today'.tr(context), style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.4))),
                            Text(total, style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5, height: 1)),
                            Text(period, style: TextStyle(fontSize: 12.sp, color: Colors.white.withValues(alpha: 0.4))),
                          ],
                        ),
                        if (isYearly)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
                            decoration: BoxDecoration(color: const Color(0xFF34C759).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2.5.w)),
                            child: Text(savings, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF34C759))),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Payment Methods
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                child: Text('payment_method'.tr(context), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93), letterSpacing: 0.5)),
              ),
              _buildPMCard(PaymentMethod.apple, 'payment_apple_pay'.tr(context), 'payment_touch_id'.tr(context), state, notifier),
              _buildPMCard(PaymentMethod.card, 'payment_credit_card'.tr(context), 'payment_card_brands'.tr(context), state, notifier),
              if (state.paymentMethod == PaymentMethod.card) _buildCardForm(context),
              _buildPMCard(PaymentMethod.cliq, 'payment_cliq'.tr(context), 'payment_jordan_instant'.tr(context), state, notifier),
              _buildPMCard(PaymentMethod.zain, 'payment_zain_cash'.tr(context), 'payment_zain_jordan'.tr(context), state, notifier),

              // Promo
              Container(
                margin: EdgeInsets.all(4.w),
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3.5.w), border: Border.all(color: const Color(0xFFE5E5EA))),
                child: Row(
                  children: [
                    Icon(Icons.local_offer_outlined, color: const Color(0xFF8E8E93), size: 14.sp),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(hintText: 'payment_promo_hint'.tr(context), border: InputBorder.none, hintStyle: TextStyle(color: const Color(0xFFC7C7CC), fontSize: 13.sp), isDense: true, contentPadding: EdgeInsets.zero),
                        style: TextStyle(fontSize: 13.sp, color: const Color(0xFF1C1C1E)),
                      ),
                    ),
                    if (!_promoApplied)
                      GestureDetector(onTap: () => setState(() => _promoApplied = true), child: Text('payment_apply'.tr(context), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF007AFF))))
                    else
                      Text('✓ −10%', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: const Color(0xFF34C759))),
                  ],
                ),
              ),

              // Order Lines
              Container(
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3.5.w)),
                child: Column(
                  children: [
                    _olRow(planName, isYearly ? (isPro ? '83.88 JD' : '143.88 JD') : (isPro ? '6.99 JD' : '11.99 JD')),
                    if (isYearly) _olRow('payment_yearly_discount'.tr(context), isPro ? '−36.00 JD' : '−60.00 JD', isDiscount: true),
                    if (_promoApplied) _olRow('payment_promo_code'.tr(context), '−4.79 JD', isDiscount: true),
                    _olRow('payment_sales_tax'.tr(context), isYearly ? (isPro ? '7.66 JD' : '13.42 JD') : (isPro ? '1.12 JD' : '1.92 JD')),
                    Container(height: 1, color: const Color(0xFFF8F8F8), margin: EdgeInsets.symmetric(vertical: 1.h)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('payment_total'.tr(context), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
                        Text(total, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: const Color(0xFF1C1C1E))),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _secBadge(Icons.lock_outline, 'payment_ssl'.tr(context)),
                  SizedBox(width: 2.w),
                  _secBadge(Icons.verified_user_outlined, 'payment_pci'.tr(context)),
                  SizedBox(width: 2.w),
                  _secBadge(Icons.restore, 'payment_cancel_anytime'.tr(context)),
                ],
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
                child: Text(
                  'payment_terms'.tr(context),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.sp, color: const Color(0xFFC7C7CC), height: 1.5),
                ),
              ),
            ],
          ),
        ),
        _buildPayCTA(total, context),
      ],
    );
  }

  Widget _buildPMCard(PaymentMethod pm, String title, String sub, PaymentState state, PaymentNotifier notifier) {
    bool isSel = state.paymentMethod == pm;
    return GestureDetector(
      onTap: () => notifier.setPaymentMethod(pm),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: isSel ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 12.w,
              height: 8.w,
              decoration: BoxDecoration(color: _pmColor(pm), borderRadius: BorderRadius.circular(2.w)),
              alignment: Alignment.center,
              child: Text(_pmIcon(pm), style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
                  Text(sub, style: TextStyle(fontSize: 11.sp, color: const Color(0xFF8E8E93))),
                ],
              ),
            ),
            Container(
              width: 5.w,
              height: 5.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? const Color(0xFF1C1C1E) : Colors.transparent,
                border: Border.all(color: isSel ? const Color(0xFF1C1C1E) : const Color(0xFFD1D1D6), width: 2),
              ),
              child: isSel ? Icon(Icons.circle, color: Colors.white, size: 8.sp) : null,
            ),
          ],
        ),
      ),
    );
  }

  Color _pmColor(PaymentMethod pm) {
    switch (pm) {
      case PaymentMethod.apple: return Colors.black;
      case PaymentMethod.card: return const Color(0xFFE5E5EA);
      case PaymentMethod.cliq: return const Color(0xFF00A86B);
      case PaymentMethod.zain: return const Color(0xFFE60028);
      case PaymentMethod.cash: return const Color(0xFF34C759);
      case PaymentMethod.transfer: return const Color(0xFF007AFF);
    }
  }

  String _pmIcon(PaymentMethod pm) {
    switch (pm) {
      case PaymentMethod.apple: return 'Pay';
      case PaymentMethod.card: return '💳';
      case PaymentMethod.cliq: return 'CliQ';
      case PaymentMethod.zain: return 'Zain';
      case PaymentMethod.cash: return '💵';
      case PaymentMethod.transfer: return '🏦';
    }
  }

  Widget _buildCardForm(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4.w)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('payment_card_details'.tr(context), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
          SizedBox(height: 2.h),
          _cfInput('payment_card_number'.tr(context), '1234 5678 9012 3456'),
          _cfInput('payment_card_name'.tr(context), 'Full name on card'),
          Row(
            children: [
              Expanded(child: _cfInput('payment_expiry_date'.tr(context), 'MM/YY')),
              SizedBox(width: 2.w),
              Expanded(child: _cfInput('payment_cvv'.tr(context), '•••')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cfInput(String label, String hint) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: const Color(0xFF8E8E93), letterSpacing: 0.4)),
          SizedBox(height: 0.5.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
            decoration: BoxDecoration(color: const Color(0xFFF9F9FB), borderRadius: BorderRadius.circular(3.w), border: Border.all(color: const Color(0xFFE5E5EA))),
            child: Text(hint, style: TextStyle(fontSize: 14.sp, color: const Color(0xFFC7C7CC))),
          ),
        ],
      ),
    );
  }

  Widget _olRow(String lbl, String val, {bool isDiscount = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(lbl, style: TextStyle(fontSize: 12.sp, color: isDiscount ? const Color(0xFF34C759) : const Color(0xFF6E6E73))),
          Text(val, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: isDiscount ? const Color(0xFF34C759) : const Color(0xFF1C1C1E))),
        ],
      ),
    );
  }

  Widget _secBadge(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2.5.w), border: Border.all(color: const Color(0xFFE5E5EA))),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF34C759), size: 12.sp),
          SizedBox(width: 1.w),
          Text(text, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: const Color(0xFF6E6E73))),
        ],
      ),
    );
  }

  Widget _buildPayCTA(String total, BuildContext context) {
    String pmName = 'Apple Pay';
    if (ref.watch(paymentProvider).paymentMethod == PaymentMethod.card) pmName = 'Card';
    if (ref.watch(paymentProvider).paymentMethod == PaymentMethod.cliq) pmName = 'CliQ';
    if (ref.watch(paymentProvider).paymentMethod == PaymentMethod.zain) pmName = 'Zain Cash';

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
          onPressed: _isProcessing ? null : _processPayment,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1C1E),
            padding: EdgeInsets.symmetric(vertical: 2.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5.w)),
          ),
          child: _isProcessing
              ? SizedBox(width: 16.sp, height: 16.sp, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: Colors.white, size: 14.sp),
                    SizedBox(width: 2.w),
                    Text('${'payment_pay_btn'.tr(context)} $total ${'payment_with'.tr(context)} $pmName', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}
