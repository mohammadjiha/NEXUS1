import 'package:flutter/material.dart';

extension AppColorsExt on BuildContext {
  Color get bg => Theme.of(this).scaffoldBackgroundColor;
  Color get surface => Theme.of(this).colorScheme.surface;
  Color get primaryText => Theme.of(this).textTheme.bodyLarge?.color ?? const Color(0xFF1C1C1E);
  Color get secondaryText => Theme.of(this).textTheme.bodySmall?.color ?? const Color(0xFF8E8E93);
  Color get border => Theme.of(this).inputDecorationTheme.border?.borderSide.color ?? const Color(0xFFE5E5EA);
  Color get primary => Theme.of(this).colorScheme.primary;
  Color get secondary => Theme.of(this).colorScheme.secondary;
}
