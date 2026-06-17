import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/widgets/trophy_animation_dialog.dart';

final trophyServiceProvider = Provider<TrophyService>((ref) => TrophyService());

class TrophyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> awardTrophies({
    required BuildContext context,
    required String uid,
    required int amount,
    required String reason,
  }) async {
    try {
      // 1. Update Firestore
      await _firestore.collection('users').doc(uid).update({
        'trophies': FieldValue.increment(amount),
        'cups': FieldValue.increment(amount),
      });

      // 2. Show Animation Overlay
      if (context.mounted) {
        TrophyAnimationOverlay.show(context, amount, reason);
      }
    } catch (e) {
      debugPrint('Error awarding trophies: $e');
    }
  }

  Future<bool> awardTrophiesOnce({
    required BuildContext context,
    required String uid,
    required String awardId,
    required int amount,
    required String reason,
  }) async {
    try {
      final safeAwardId = awardId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      final userRef = _firestore.collection('users').doc(uid);
      final awardRef = userRef.collection('trophyAwards').doc(safeAwardId);

      final wasAwarded = await _firestore.runTransaction<bool>((
        transaction,
      ) async {
        final awardSnapshot = await transaction.get(awardRef);
        if (awardSnapshot.exists) return false;

        transaction.set(awardRef, {
          'id': safeAwardId,
          'amount': amount,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.update(userRef, {
          'trophies': FieldValue.increment(amount),
          'cups': FieldValue.increment(amount),
        });
        return true;
      });

      if (wasAwarded && context.mounted) {
        TrophyAnimationOverlay.show(context, amount, reason);
      }

      return wasAwarded;
    } catch (e) {
      debugPrint('Error awarding trophies once: $e');
      return false;
    }
  }
}
