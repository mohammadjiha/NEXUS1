import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentRecord {
  final String id;
  final String planName;
  final double amount;
  final double totalAmount;
  final double discountAmount;
  final double amountRemaining;
  final String paymentMethod;
  final DateTime paymentDate;
  final int durationDays;
  final String type;

  PaymentRecord({
    required this.id,
    required this.planName,
    required this.amount,
    this.totalAmount = 0.0,
    this.discountAmount = 0.0,
    this.amountRemaining = 0.0,
    required this.paymentMethod,
    required this.paymentDate,
    required this.durationDays,
    this.type = 'payment',
  });

  Map<String, dynamic> toMap() {
    return {
      'planName': planName,
      'amount': amount,
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'amountRemaining': amountRemaining,
      'paymentMethod': paymentMethod,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'durationDays': durationDays,
      'type': type,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map, String docId) {
    return PaymentRecord(
      id: docId,
      planName: map['planName'] as String? ?? 'Monthly Plan',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,
      amountRemaining: (map['amountRemaining'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash',
      paymentDate: map['paymentDate'] is Timestamp
          ? (map['paymentDate'] as Timestamp).toDate()
          : DateTime.now(),
      durationDays: (map['durationDays'] as num?)?.toInt() ?? 30,
      type: map['type'] as String? ?? 'payment',
    );
  }
}
