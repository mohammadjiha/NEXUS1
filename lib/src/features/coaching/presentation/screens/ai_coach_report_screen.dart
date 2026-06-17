import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../smart_workout/presentation/widgets/exercise_feedback_sheet.dart';
import '../../domain/models/ai_coach_report.dart';

class AICoachReportScreen extends StatelessWidget {
  final AICoachReport report;

  const AICoachReportScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    int criticalCount = report.issues
        .where((i) => i.severity == 'Critical')
        .length;
    int warningCount = report.issues
        .where((i) => i.severity == 'Warning')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // Match phone-w bg
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 2.h),
                color: const Color(0xFF1C1C1E),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 14.sp,
                            ),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ai_coach_report'.tr(context).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13.sp,
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                "${report.exerciseName} · ${'set'.tr(context)} 1",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.ios_share,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 16.sp,
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'form_score'.tr(context).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${report.formScore}',
                                    style: TextStyle(
                                      color: const Color(0xFFFF9500),
                                      fontSize: 30.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  Text(
                                    '/100',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'reps'.tr(context).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${report.correctReps}',
                                    style: TextStyle(
                                      color: const Color(0xFF34C759),
                                      fontSize: 30.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  Text(
                                    "/${report.totalReps} ${'correct'.tr(context)}",
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (criticalCount > 0)
                              _buildBadge(
                                "$criticalCount ${'errors'.tr(context)}",
                                const Color(0xFFFF3B30),
                                const Color(0xFFFF3B30).withValues(alpha: 0.15),
                              ),
                            if (warningCount > 0) ...[
                              SizedBox(height: 0.5.h),
                              _buildBadge(
                                "$warningCount ${'warning'.tr(context)}",
                                const Color(0xFFFF9500),
                                const Color(0xFFFF9500).withValues(alpha: 0.15),
                              ),
                            ],
                            SizedBox(height: 0.5.h),
                            _buildBadge(
                              "${report.goodPoints.length} ${'good'.tr(context)}",
                              const Color(0xFF34C759),
                              const Color(0xFF34C759).withValues(alpha: 0.15),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gemini AI Coach says
                    Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5FF),
                        border: Border.all(color: const Color(0xFF85B7EB)),
                        borderRadius: BorderRadius.circular(3.w),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.smart_toy_rounded,
                              color: Colors.white,
                              size: 14.sp,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'gemini_ai_coach_says'.tr(context),
                                  style: TextStyle(
                                    color: const Color(0xFF0A64B0),
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  report.coachFeedback,
                                  style: TextStyle(
                                    color: const Color(0xFF185FA5),
                                    fontSize: 15.sp,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Recommended Alternative (if form is poor)
                    if (report.recommendedAlternative != null &&
                        report.recommendedAlternative!.isNotEmpty) ...[
                      Text(
                        'suggested_alternative'.tr(context).toUpperCase(),
                        style: TextStyle(
                          color: const Color(0xFF8E8E93),
                          fontSize: 12.sp,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF5E5CE6), Color(0xFF3B39C6)],
                          ),
                          borderRadius: BorderRadius.circular(3.w),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF5E5CE6,
                              ).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(2.w),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.autorenew_rounded,
                                color: Colors.white,
                                size: 16.sp,
                              ),
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${'try_exercise'.tr(context)} ${report.recommendedAlternative}",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 0.5.h),
                                  Text(
                                    'better_suited_mobility_form'.tr(context),
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white.withValues(alpha: 0.5),
                              size: 12.sp,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => ExerciseFeedbackSheet(
                                originalExercise: report.exerciseName,
                                alternativeExercise:
                                    report.recommendedAlternative!,
                              ),
                            );
                            if (result == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'feedback_saved_exercise_updated'.tr(
                                      context,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            Icons.swap_horiz,
                            color: const Color(0xFF5E5CE6),
                            size: 14.sp,
                          ),
                          label: Text(
                            'swap_leave_feedback'.tr(context),
                            style: TextStyle(
                              color: const Color(0xFF5E5CE6),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF5E5CE6)),
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3.w),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 3.h),
                    ],

                    // Issues Found
                    if (report.issues.isNotEmpty) ...[
                      Text(
                        'issues_found'.tr(context).toUpperCase(),
                        style: TextStyle(
                          color: const Color(0xFF8E8E93),
                          fontSize: 14.sp,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      ...report.issues.map((issue) => _buildIssueCard(issue)),
                      SizedBox(height: 2.h),
                    ],

                    // What You Did Well
                    if (report.goodPoints.isNotEmpty) ...[
                      Text(
                        'what_you_did_well'.tr(context).toUpperCase(),
                        style: TextStyle(
                          color: const Color(0xFF8E8E93),
                          fontSize: 14.sp,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                        child: Column(
                          children: report.goodPoints.map((point) {
                            int index = report.goodPoints.indexOf(point);
                            return Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(3.w),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8.w,
                                        height: 8.w,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8FFF0),
                                          borderRadius: BorderRadius.circular(
                                            2.w,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.check,
                                          color: const Color(0xFF34C759),
                                          size: 16.sp,
                                        ),
                                      ),
                                      SizedBox(width: 3.w),
                                      Expanded(
                                        child: Text(
                                          point,
                                          style: TextStyle(
                                            color: const Color(0xFF1C1C1E),
                                            fontSize: 15.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (index < report.goodPoints.length - 1)
                                  Container(
                                    height: 0.5,
                                    color: const Color(0xFFF0F0F5),
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 4.w,
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2.w),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildIssueCard(CoachIssue issue) {
    bool isCritical = issue.severity.toLowerCase() == 'critical';
    Color iconColor = isCritical
        ? const Color(0xFFFF3B30)
        : const Color(0xFFFF9500);
    Color iconBg = isCritical
        ? const Color(0xFFFFEBEE)
        : const Color(0xFFFFF8E8);

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E5EA)),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(3.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isCritical
                        ? Icons.warning_rounded
                        : Icons.info_outline_rounded,
                    color: iconColor,
                    size: 14.sp,
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              issue.title,
                              style: TextStyle(
                                color: const Color(0xFF1C1C1E),
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.5.w,
                              vertical: 0.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(3.w),
                            ),
                            child: Text(
                              issue.severity,
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        issue.description,
                        style: TextStyle(
                          color: const Color(0xFF8E8E93),
                          fontSize: 14.sp,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (issue.fix.isNotEmpty) ...[
                        SizedBox(height: 1.5.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 3.w,
                            vertical: 1.2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8FFF0),
                            borderRadius: BorderRadius.circular(2.w),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: const Color(0xFF1A7A30),
                                size: 16.sp,
                              ),
                              SizedBox(width: 2.w),
                              Expanded(
                                child: Text(
                                  'Fix: ${issue.fix}',
                                  style: TextStyle(
                                    color: const Color(0xFF1A7A30),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (issue.reps.isNotEmpty) ...[
            Container(height: 0.5, color: const Color(0xFFF0F0F5)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Detected at reps ${issue.reps.join(', ')}",
                    style: TextStyle(
                      color: const Color(0xFF8E8E93),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Watch clip ↗',
                    style: TextStyle(
                      color: const Color(0xFF007AFF),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
