// lib/src/core/widgets/app_error_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/localization/app_localizations.dart';

class AppErrorScreen extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  final bool compact;

  const AppErrorScreen({
    super.key,
    this.error,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) return _CompactError(onRetry: onRetry);
    return _FullScreenError(error: error, onRetry: onRetry);
  }
}

// ── Full-screen layout ────────────────────────────────────────────────────────

class _FullScreenError extends StatefulWidget {
  final Object? error;
  final VoidCallback? onRetry;

  const _FullScreenError({this.error, this.onRetry});

  @override
  State<_FullScreenError> createState() => _FullScreenErrorState();
}

class _FullScreenErrorState extends State<_FullScreenError> {
  bool _retrying = false;

  /// Determine the correct home route from the current GoRouter location.
  /// This avoids depending on Riverpod/Firebase when the widget tree is broken.
  String _homeRoute(BuildContext context) {
    try {
      final router = GoRouter.maybeOf(context);
      final location = router?.routerDelegate.currentConfiguration.uri.path ?? '';
      if (location.startsWith('/super_admin')) return '/super_admin';
      if (location.startsWith('/admin'))       return '/admin';
      if (location.startsWith('/coach'))       return '/coach_dashboard';
    } catch (_) {}
    return '/dashboard'; // player / fallback
  }

  void _goHome(BuildContext context) {
    final route = _homeRoute(context);
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(route);
    } else {
      Navigator.of(context, rootNavigator: true)
          .popUntil((r) => r.isFirst);
    }
  }

  Future<void> _onRetry(BuildContext context) async {
    if (_retrying) return;
    setState(() => _retrying = true);

    // Try calling onRetry; give it 3 seconds to recover
    bool recovered = false;
    try {
      widget.onRetry?.call();
      await Future.delayed(const Duration(seconds: 3));
      recovered = true;
    } catch (_) {
      recovered = false;
    }

    if (!mounted) return;

    if (!recovered) {
      // Failed → go home
      _goHome(context);
    } else {
      setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icon ──────────────────────────────────────────────────────
              Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 11.w,
                  color: const Color(0xFFFF3B30),
                ),
              ),
              SizedBox(height: 3.h),

              // ── Heading ───────────────────────────────────────────────────
              Text(
                'something_went_wrong'.tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: 1.5.h),

              // ── Subtitle ──────────────────────────────────────────────────
              Text(
                'error_boundary_desc'.tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8E8E93),
                  height: 1.6,
                ),
              ),
              SizedBox(height: 5.h),

              // ── Go Home ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _retrying ? null : () => _goHome(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    disabledBackgroundColor: const Color(0xFF1C1C1E).withOpacity(0.4),
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'go_home'.tr(context),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // ── Retry ─────────────────────────────────────────────────────
              if (widget.onRetry != null) ...[
                SizedBox(height: 1.2.h),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _retrying ? null : () => _onRetry(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 1.8.h),
                      side: const BorderSide(color: Color(0xFFE0E0E5), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3.w),
                      ),
                    ),
                    child: _retrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1C1C1E),
                            ),
                          )
                        : Text(
                            'retry'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compact inline error card ─────────────────────────────────────────────────

class _CompactError extends StatelessWidget {
  final VoidCallback? onRetry;

  const _CompactError({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(
          color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFF3B30),
            size: 22,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'something_went_wrong'.tr(context),
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF1C1C1E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(width: 3.w),
            GestureDetector(
              onTap: onRetry,
              child: Text(
                'retry'.tr(context),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF3B30),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
