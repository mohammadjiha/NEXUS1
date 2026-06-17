import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/models/supplement_model.dart';
import 'package:uuid/uuid.dart';

final supplementsRepositoryProvider = Provider<SupplementsRepository>((ref) {
  final user = ref.watch(currentUserModelProvider).asData?.value;
  return SupplementsRepository(FirebaseFirestore.instance, user?.uid);
});

class SupplementsRepository {
  final FirebaseFirestore _firestore;
  final String? _uid;

  SupplementsRepository(this._firestore, this._uid);

  CollectionReference<Map<String, dynamic>>? get _routineRef {
    if (_uid == null) return null;
    return _firestore.collection('users').doc(_uid).collection('supplements_routine');
  }

  CollectionReference<Map<String, dynamic>>? get _historyRef {
    if (_uid == null) return null;
    return _firestore.collection('users').doc(_uid).collection('supplements_history');
  }

  Stream<List<SupplementItem>> watchRoutine() {
    if (_routineRef == null) return Stream.value([]);
    return _routineRef!.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SupplementItem.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> saveSupplement(SupplementItem item) async {
    if (_routineRef == null) return;
    await _routineRef!.doc(item.id).set(item.toMap());
  }

  Future<void> deleteSupplement(String id) async {
    if (_routineRef == null) return;
    await _routineRef!.doc(id).delete();
  }

  Stream<SupplementDailyLog> watchDailyLog(String date) {
    if (_historyRef == null) return Stream.value(SupplementDailyLog(date: date, takenIds: []));
    return _historyRef!.doc(date).snapshots().map((doc) {
      if (!doc.exists) return SupplementDailyLog(date: date, takenIds: []);
      return SupplementDailyLog.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> toggleSupplement(String date, String supplementId, bool isTaken) async {
    if (_historyRef == null) return;
    final docRef = _historyRef!.doc(date);
    if (isTaken) {
      await docRef.set({
        'takenIds': FieldValue.arrayUnion([supplementId])
      }, SetOptions(merge: true));
    } else {
      await docRef.set({
        'takenIds': FieldValue.arrayRemove([supplementId])
      }, SetOptions(merge: true));
    }
  }

  Future<void> setupDefaultSupplementsIfNeeded() async {
    if (_routineRef == null) return;
    final snapshot = await _routineRef!.limit(1).get();
    if (snapshot.docs.isEmpty) {
      final batch = _firestore.batch();
      
      final defaults = [
        SupplementItem(id: const Uuid().v4(), name: 'Creatine Monohydrate', details: '5g - With breakfast', timing: SupplementTiming.morning, emoji: '💊', iconBgColor: 0xFFE8F5FF),
        SupplementItem(id: const Uuid().v4(), name: 'Vitamin D3 + K2', details: '2000 IU - With meal', timing: SupplementTiming.morning, emoji: '🌅', iconBgColor: 0xFFFFF8E8),
        SupplementItem(id: const Uuid().v4(), name: 'Omega-3', details: '2 caps - With breakfast', timing: SupplementTiming.morning, emoji: '🐟', iconBgColor: 0xFFE8FFF0),
        SupplementItem(id: const Uuid().v4(), name: 'Pre-Workout', details: '1 scoop - 30 min before', timing: SupplementTiming.preWorkout, emoji: '⚡', iconBgColor: 0xFFFFF0E8),
        SupplementItem(id: const Uuid().v4(), name: 'Whey Protein', details: '30g - Post-workout', timing: SupplementTiming.postWorkout, emoji: '🥛', iconBgColor: 0xFFE8FFF0),
      ];

      for (var item in defaults) {
        batch.set(_routineRef!.doc(item.id), item.toMap());
      }
      
      await batch.commit();
    }
  }
}

