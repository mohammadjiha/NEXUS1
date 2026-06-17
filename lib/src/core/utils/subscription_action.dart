import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../features/auth/data/auth_repository.dart';

void runIfSubscriptionActive(WidgetRef ref, BuildContext context, VoidCallback action) {
  final user = ref.read(currentUserModelProvider).asData?.value;
  if (user != null && user.isSubscriptionExpired) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('subscription_expired_snack'.tr(context), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE53935),
      ),
    );
    return;
  }
  action();
}
