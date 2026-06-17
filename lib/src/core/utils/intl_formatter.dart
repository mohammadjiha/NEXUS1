// lib/src/core/utils/intl_formatter.dart
//
// Locale-aware date, time, and number formatting for Nexus.
//
// Usage
// ─────
//   AppIntl.date(context, someDateTime)        // "Jun 13, 2026"  |  "١٣ يونيو ٢٠٢٦"
//   AppIntl.shortDate(context, someDateTime)   // "Jun 13"        |  "١٣ يون"
//   AppIntl.time(context, someDateTime)        // "4:30 PM"       |  "٤:٣٠ م"
//   AppIntl.dateTime(context, someDateTime)    // "Jun 13 · 4:30 PM"
//   AppIntl.number(context, 1234.5)            // "1,234.5"       |  "١٬٢٣٤٫٥"
//
// All methods read the current app locale from context so you never have to
// pass locale strings manually.

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

abstract final class AppIntl {
  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns the BCP-47 locale string for the current context.
  /// Falls back to 'en' when [Localizations.localeOf] is unavailable.
  static String _locale(BuildContext context) {
    try {
      return Localizations.localeOf(context).toLanguageTag();
    } catch (_) {
      return 'en';
    }
  }

  static bool _isArabic(BuildContext context) =>
      _locale(context).startsWith('ar');

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Long date: "June 13, 2026" | "١٣ يونيو ٢٠٢٦"
  static String date(BuildContext context, DateTime dt) {
    final loc = _locale(context);
    return DateFormat.yMMMMd(loc).format(dt);
  }

  /// Short date: "Jun 13" | "١٣ يون"
  static String shortDate(BuildContext context, DateTime dt) {
    final loc = _locale(context);
    return DateFormat.MMMd(loc).format(dt);
  }

  /// Short date with year: "Jun 13, 2026" | "١٣ يون ٢٠٢٦"
  static String shortDateYear(BuildContext context, DateTime dt) {
    final loc = _locale(context);
    return DateFormat.yMMMd(loc).format(dt);
  }

  /// Numeric date: "13/06/2026" | "١٣/٠٦/٢٠٢٦"
  static String numericDate(BuildContext context, DateTime dt) {
    final loc = _locale(context);
    return DateFormat.yMd(loc).format(dt);
  }

  /// Day-of-week abbreviated: "Mon" | "الإثنين"
  static String weekday(BuildContext context, DateTime dt) {
    final loc = _locale(context);
    return DateFormat.E(loc).format(dt);
  }

  /// Full day-of-week: "Monday" | "الإثنين"
  static String weekdayFull(BuildContext context, DateTime dt) {
    final loc = _locale(context);
    return DateFormat.EEEE(loc).format(dt);
  }

  /// Time only: "4:30 PM" | "٤:٣٠ م"
  static String time(BuildContext context, DateTime dt) {
    final loc = _locale(context);
    return DateFormat.jm(loc).format(dt);
  }

  /// Date + time: "Jun 13 · 4:30 PM" | "١٣ يون · ٤:٣٠ م"
  static String dateTime(BuildContext context, DateTime dt) {
    return '${shortDate(context, dt)} · ${time(context, dt)}';
  }

  /// Full date + time: "June 13, 2026 · 4:30 PM"
  static String fullDateTime(BuildContext context, DateTime dt) {
    return '${date(context, dt)} · ${time(context, dt)}';
  }

  /// Integer: "1,234" | "١٬٢٣٤"
  static String integer(BuildContext context, int n) {
    final loc = _locale(context);
    return NumberFormat.decimalPattern(loc).format(n);
  }

  /// Decimal: "1,234.5" | "١٬٢٣٤٫٥"
  static String decimal(BuildContext context, num n, {int fractionDigits = 1}) {
    final loc = _locale(context);
    return NumberFormat.decimalPatternDigits(
      locale: loc,
      decimalDigits: fractionDigits,
    ).format(n);
  }

  /// Percentage: "85%" | "٨٥٪"
  static String percent(BuildContext context, num fraction) {
    final loc = _locale(context);
    return NumberFormat.percentPattern(loc).format(fraction);
  }

  /// Compact integer: "1.2K" | "١٫٢ ألف"
  static String compact(BuildContext context, num n) {
    final loc = _locale(context);
    return NumberFormat.compact(locale: loc).format(n);
  }

  /// Converts Western Arabic digits to Eastern Arabic when locale is AR.
  /// Use this for any number that is already a formatted string
  /// (e.g. a countdown timer "0:45").
  static String digits(BuildContext context, String western) {
    if (!_isArabic(context)) return western;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = western;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(en[i], ar[i]);
    }
    return result;
  }
}
