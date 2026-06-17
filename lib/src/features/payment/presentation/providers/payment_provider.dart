import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../user/models/user_model.dart';

enum BillingCycle { monthly, yearly }
enum PlanType { basic, pro, elite }
enum PaymentMethod { apple, card, cliq, zain, cash, transfer }

// ─── Pricing table ───────────────────────────────────────────────────────────

const _monthlyPrices = {
  PlanType.basic: 29.0,
  PlanType.pro: 49.0,
  PlanType.elite: 79.0,
};

double getPlanPrice(PlanType plan, BillingCycle cycle) {
  final monthly = _monthlyPrices[plan] ?? 49.0;
  return cycle == BillingCycle.yearly ? monthly * 12 * 0.8 : monthly; // 20% yearly discount
}

String planTypeName(PlanType p) =>
    p.name[0].toUpperCase() + p.name.substring(1);

// ─── State ───────────────────────────────────────────────────────────────────

class PaymentState {
  final int currentStep;
  final BillingCycle billingCycle;
  final PlanType planType;
  final PaymentMethod paymentMethod;
  final bool isConfirming;
  final String? errorMessage;
  final bool confirmed;

  const PaymentState({
    this.currentStep = 0,
    this.billingCycle = BillingCycle.yearly,
    this.planType = PlanType.pro,
    this.paymentMethod = PaymentMethod.cash,
    this.isConfirming = false,
    this.errorMessage,
    this.confirmed = false,
  });

  PaymentState copyWith({
    int? currentStep,
    BillingCycle? billingCycle,
    PlanType? planType,
    PaymentMethod? paymentMethod,
    bool? isConfirming,
    String? errorMessage,
    bool? confirmed,
  }) {
    return PaymentState(
      currentStep: currentStep ?? this.currentStep,
      billingCycle: billingCycle ?? this.billingCycle,
      planType: planType ?? this.planType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isConfirming: isConfirming ?? this.isConfirming,
      errorMessage: errorMessage,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  double get totalPrice => getPlanPrice(planType, billingCycle);
  String get planName => planTypeName(planType);
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class PaymentNotifier extends Notifier<PaymentState> {
  @override
  PaymentState build() => const PaymentState();

  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void setBillingCycle(BillingCycle cycle) =>
      state = state.copyWith(billingCycle: cycle);

  void setPlan(PlanType plan) => state = state.copyWith(planType: plan);

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method);

  void reset() => state = const PaymentState();

  /// Writes the subscription + payment record to Firestore.
  /// Called when the user taps "Confirm" on the final step.
  Future<bool> confirmPayment(String playerUid) async {
    state = state.copyWith(isConfirming: true, errorMessage: null);

    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();

      final durationMonths = state.billingCycle == BillingCycle.yearly ? 12 : 1;
      final endDate = DateTime(now.year, now.month + durationMonths, now.day);
      final totalAmount = state.totalPrice;
      final planName = state.planName;
      final methodName = state.paymentMethod.name;

      final batch = db.batch();

      // 1. Payment record in subcollection
      final payRef = db
          .collection('users')
          .doc(playerUid)
          .collection('payments')
          .doc();
      batch.set(payRef, {
        'type': 'subscription',
        'planName': planName,
        'amount': totalAmount,
        'paymentMethod': methodName,
        'billingCycle': state.billingCycle.name,
        'paymentDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update user document: subscription + amounts
      batch.update(db.collection('users').doc(playerUid), {
        'subscriptionPlan': planName,
        'subscriptionStart': Timestamp.fromDate(now),
        'subscriptionEnd': Timestamp.fromDate(endDate),
        'totalAmount': totalAmount,
        'amountPaid': totalAmount,
        'amountRemaining': 0.0,
        'paymentMethod': methodName,
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      state = state.copyWith(
          isConfirming: false, confirmed: true, currentStep: 2);
      return true;
    } catch (e) {
      state = state.copyWith(
          isConfirming: false, errorMessage: e.toString());
      return false;
    }
  }
}

final paymentProvider =
    NotifierProvider<PaymentNotifier, PaymentState>(PaymentNotifier.new);

// ─── Provider: current player's payment history ───────────────────────────────

final playerPaymentsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, uid) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('payments')
      .orderBy('paymentDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

// ─── Provider: current signed-in user's payment history ──────────────────────

final myPaymentsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('payments')
      .orderBy('paymentDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});
