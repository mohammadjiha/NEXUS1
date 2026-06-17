// test/unit/repositories/food_repository_test.dart
//
// Unit tests for FoodRepository — focuses on the pure static helper
// isArabicQuery() which has no Firebase dependency.

import 'package:flutter_test/flutter_test.dart';

import 'package:nexus/src/features/nutrition/data/food_repository.dart';

void main() {
  group('FoodRepository.isArabicQuery', () {
    // ── Arabic detection ───────────────────────────────────────────────────

    test('returns true for a pure Arabic word', () {
      expect(FoodRepository.isArabicQuery('تفاحة'), isTrue);
    });

    test('returns true for Arabic sentence with spaces', () {
      expect(FoodRepository.isArabicQuery('صدر دجاج مشوي'), isTrue);
    });

    test('returns true for Arabic mixed with numbers', () {
      expect(FoodRepository.isArabicQuery('بروتين 100'), isTrue);
    });

    test('returns true for Arabic with diacritics (tashkeel)', () {
      expect(FoodRepository.isArabicQuery('لَحْمٌ'), isTrue);
    });

    test('returns true for Extended Arabic block (U+0750–U+077F)', () {
      // U+0750 is in the extended Arabic block
      expect(FoodRepository.isArabicQuery('ݐ'), isTrue);
    });

    // ── Non-Arabic ─────────────────────────────────────────────────────────

    test('returns false for English word', () {
      expect(FoodRepository.isArabicQuery('chicken'), isFalse);
    });

    test('returns false for numeric string', () {
      expect(FoodRepository.isArabicQuery('12345'), isFalse);
    });

    test('returns false for empty string', () {
      expect(FoodRepository.isArabicQuery(''), isFalse);
    });

    test('returns false for Latin with accents', () {
      expect(FoodRepository.isArabicQuery('café'), isFalse);
    });

    test('returns false for whitespace only', () {
      expect(FoodRepository.isArabicQuery('   '), isFalse);
    });

    test('returns false for emoji', () {
      expect(FoodRepository.isArabicQuery('🍗'), isFalse);
    });
  });
}
