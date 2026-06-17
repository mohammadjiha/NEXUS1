import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/food_model.dart';

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(FirebaseFirestore.instance);
});

class FoodRepository {
  final FirebaseFirestore _firestore;

  FoodRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _foods =>
      _firestore.collection('foods');

  Future<FoodPage> topPicks({
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _foods
        .orderBy('gymScore', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);

    final snapshot = await query.get();
    return FoodPage.fromSnapshot(snapshot, limit: limit);
  }

  /// Returns true if [text] contains Arabic characters.
  static bool isArabicQuery(String text) =>
      RegExp(r'[\u0600-\u06FF\u0750-\u077F]').hasMatch(text);

  Future<FoodPage> search(
    String query, {
    int limit = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return topPicks(limit: limit, startAfter: startAfter);
    }

    final useArabic = isArabicQuery(query);
    final token = normalized.split(RegExp(r'\s+')).first;
    final indexField = useArabic ? 'namePrefixesAr' : 'namePrefixes';

    Query<Map<String, dynamic>> queryRef = _foods
        .where(indexField, arrayContains: token)
        .limit(limit);
    if (startAfter != null) queryRef = queryRef.startAfterDocument(startAfter);

    final snapshot = await queryRef.get();
    final foods = snapshot.docs
        .map((doc) => FoodModel.fromMap(doc.id, doc.data()))
        .where((food) {
          if (useArabic) {
            final ar = (food.nameAr ?? '').toLowerCase();
            return ar.contains(normalized) || ar.startsWith(token);
          }
          final haystack = '${food.name} ${food.tags.join(' ')}'.toLowerCase();
          return haystack.contains(normalized) ||
              food.name.toLowerCase().startsWith(token);
        })
        .toList();

    return FoodPage(
      foods: foods,
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }
}

class FoodPage {
  final List<FoodModel> foods;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const FoodPage({
    required this.foods,
    required this.lastDocument,
    required this.hasMore,
  });

  factory FoodPage.fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    required int limit,
  }) {
    return FoodPage(
      foods: snapshot.docs
          .map((doc) => FoodModel.fromMap(doc.id, doc.data()))
          .toList(),
      lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }
}
