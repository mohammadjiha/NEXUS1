import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../providers/ai_coach_provider.dart';
import 'ai_coach_report_screen.dart';

class AICoachAnalyzingScreen extends ConsumerStatefulWidget {
  final String videoPath;
  final String exerciseName;

  const AICoachAnalyzingScreen({
    super.key,
    required this.videoPath,
    required this.exerciseName,
  });

  @override
  ConsumerState<AICoachAnalyzingScreen> createState() =>
      _AICoachAnalyzingScreenState();
}

class _AICoachAnalyzingScreenState
    extends ConsumerState<AICoachAnalyzingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(aiCoachProvider.notifier)
          .analyzeVideo(widget.videoPath, widget.exerciseName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiCoachProvider);

    ref.listen<AICoachState>(aiCoachProvider, (previous, next) {
      if (next.status == AICoachStateStatus.success && next.report != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AICoachReportScreen(report: next.report!),
          ),
        );
      }
      // Error is shown inline — no pop so the user can retry without losing context.
    });

    // ── Error state — show retry UI ───────────────────────────────────────────
    if (state.status == AICoachStateStatus.error) {
      return _buildErrorView(context, state.errorMessage);
    }

    // ── Analyzing state ───────────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: const Color(0xFF007AFF),
                  size: 10.sp * 2.5,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'ai_coach_analyzing'.tr(context),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                "${'processing_video_prefix'.tr(context)} ${widget.exerciseName.toLowerCase()} ${'processing_video_suffix'.tr(context)}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16.sp,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 4.h),

              // Progress Bar
              Container(
                width: 50.w,
                height: 1.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(1.w),
                ),
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: state.progress.clamp(0.1, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(1.w),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                "${'detecting_joint_angles'.tr(context)} ${(state.progress * 100).toInt()}%",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14.sp,
                ),
              ),

              SizedBox(height: 5.h),
              _buildStepRow(
                Icons.check,
                'video_uploaded_successfully'.tr(context),
                const Color(0xFF34C759),
                state.progress > 0.1,
              ),
              SizedBox(height: 1.h),
              _buildStepRow(
                Icons.check,
                'pose_landmarks_extracted'.tr(context),
                const Color(0xFF34C759),
                state.progress >= 0.3,
              ),
              SizedBox(height: 1.h),
              _buildStepRow(
                Icons.hourglass_empty,
                'gemini_vision_analyzing_form'.tr(context),
                const Color(0xFF007AFF),
                state.progress >= 0.6,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error view ──────────────────────────────────────────────────────────────

  Widget _buildErrorView(BuildContext context, String? errorMessage) {
    String msg = errorMessage ?? 'unknown_error'.tr(context);
    if (msg.contains('Exception: ')) msg = msg.replaceAll('Exception: ', '');

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Error icon ──────────────────────────────────────────────────
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.error_outline_rounded,
                  color: const Color(0xFFFF3B30),
                  size: 10.sp * 2.5,
                ),
              ),
              SizedBox(height: 3.h),

              // ── Title ───────────────────────────────────────────────────────
              Text(
                'analysis_failed'.tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 1.5.h),

              // ── Error detail ────────────────────────────────────────────────
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(3.w),
                  border: Border.all(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13.sp,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: 5.h),

              // ── Retry button ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref
                        .read(aiCoachProvider.notifier)
                        .analyzeVideo(widget.videoPath, widget.exerciseName);
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label: Text(
                    'retry'.tr(context),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              SizedBox(height: 1.5.h),

              // ── Go back button ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                  ),
                  child: Text(
                    'go_back'.tr(context),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(IconData icon, String text, Color color, bool isActive) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActive ? 0.05 : 0.02),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? color : Colors.white.withValues(alpha: 0.2),
            size: 18.sp,
          ),
          SizedBox(width: 3.w),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isActive ? 0.9 : 0.5),
              fontSize: 15.sp,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
