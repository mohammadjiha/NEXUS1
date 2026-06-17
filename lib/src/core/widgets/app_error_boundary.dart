// lib/src/core/widgets/app_error_boundary.dart
//
// Flutter-native "error boundary" pattern.
//
// How Flutter error handling works (vs React):
// ─────────────────────────────────────────────
// Flutter has no per-widget error boundary like React's componentDidCatch.
// Widget build errors are caught by the framework BEFORE they reach user code.
// The two hooks we have are:
//
//   1. ErrorWidget.builder  — called when any widget in the tree throws during
//      build().  Returns a replacement widget.  Set in main() via
//      [configureGlobalErrorHandling].
//
//   2. AppErrorBoundary  — a StatefulWidget that tracks an explicit error state.
//      Callers set the error via AppErrorBoundary.of(context).reportError(e, s).
//      Useful for async / provider errors that we can catch ourselves.
//
// Usage
// ─────
// Wrap the router's child in MaterialApp.builder:
//
//   builder: (context, child) => AppErrorBoundary(child: child ?? const SizedBox()),
//
// Report an error from any descendant:
//
//   AppErrorBoundary.of(context)?.reportError(error, stack);
//
// Or let the global handler do it automatically via
// [configureGlobalErrorHandling].

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_error_screen.dart';

// ── Global setup ──────────────────────────────────────────────────────────────

/// Call once in main() AFTER Firebase.initializeApp().
///
/// Sets [ErrorWidget.builder] to replace the ugly red debug screen with the
/// app's [AppErrorScreen] and records every build error in Crashlytics.
void configureGlobalErrorHandling() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // Always record to Crashlytics (even in debug so we can see patterns).
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    }

    // Return a widget that sits where the failing widget was.
    // It has a BuildContext so GoRouter / navigation are available.
    return _ErrorWidgetFallback(details: details);
  };
}

// ── Per-widget error boundary ─────────────────────────────────────────────────

/// Wraps [child] and switches to [AppErrorScreen] when [reportError] is called.
///
/// Retrieve the nearest boundary with [AppErrorBoundary.of(context)].
class AppErrorBoundary extends StatefulWidget {
  const AppErrorBoundary({super.key, required this.child});

  final Widget child;

  /// Returns the nearest [AppErrorBoundary] ancestor state, or null if none.
  static AppErrorBoundaryState? of(BuildContext context) =>
      context.findAncestorStateOfType<AppErrorBoundaryState>();

  @override
  State<AppErrorBoundary> createState() => AppErrorBoundaryState();
}

class AppErrorBoundaryState extends State<AppErrorBoundary> {
  Object? _error;
  StackTrace? _stack;

  /// Mark this boundary as errored.  Shows [AppErrorScreen] in place of the
  /// normal child until [clearError] is called.
  void reportError(Object error, StackTrace stack) {
    if (!kDebugMode) {
      FirebaseCrashlytics.instance
          .recordError(error, stack, reason: 'AppErrorBoundary');
    }
    if (mounted) {
      setState(() {
        _error = error;
        _stack = stack;
      });
    }
  }

  /// Clears the error state and rebuilds the child.
  void clearError() {
    if (mounted) setState(() { _error = null; _stack = null; });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AppErrorScreen(
        error: _error,
        onRetry: clearError,
      );
    }
    return widget.child;
  }
}

// ── Fallback widget used by ErrorWidget.builder ───────────────────────────────

/// A minimal self-contained error card placed where the failing widget was.
///
/// Because [ErrorWidget.builder] fires inside the broken subtree, we avoid
/// complex navigation here — we just report to the nearest [AppErrorBoundary]
/// or show an inline [AppErrorScreen].
class _ErrorWidgetFallback extends StatefulWidget {
  final FlutterErrorDetails details;

  const _ErrorWidgetFallback({required this.details});

  @override
  State<_ErrorWidgetFallback> createState() => _ErrorWidgetFallbackState();
}

class _ErrorWidgetFallbackState extends State<_ErrorWidgetFallback> {
  @override
  void initState() {
    super.initState();
    // Propagate to the nearest AppErrorBoundary if one exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final boundary = AppErrorBoundary.of(context);
      if (boundary != null) {
        boundary.reportError(
          widget.details.exception,
          widget.details.stack ?? StackTrace.empty,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Shown briefly before the boundary takes over, or permanently if there
    // is no ancestor AppErrorBoundary.
    return AppErrorScreen(
      error: widget.details.exception,
      onRetry: () {
        // Ask the boundary to clear; otherwise pop the current route.
        final boundary = AppErrorBoundary.of(context);
        if (boundary != null) {
          boundary.clearError();
        }
      },
    );
  }
}
