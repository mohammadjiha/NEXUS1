import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      read: map['read'] as bool? ?? false,
      createdAt: _parseSafeDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseSafeDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is double) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }
}

// authStateProvider is declared canonically in auth_repository.dart — use that import.

final notificationsProvider = StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50) // cap at 50 — prevents unbounded reads as history grows
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.id, doc.data()))
          .toList());
});

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider).asData?.value ?? [];
  return notifications.where((n) => !n.read).length;
});

final markNotificationReadProvider = Provider.autoDispose((ref) => (String notificationId) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .doc(notificationId)
      .update({'read': true});
});
