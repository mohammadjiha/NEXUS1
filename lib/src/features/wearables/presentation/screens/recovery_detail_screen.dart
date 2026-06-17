import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';

class RecoveryDetailScreen extends StatelessWidget {
  const RecoveryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: const Color(0xFF1C1C1E),
            size: 16.sp,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'recovery_detail'.tr(context),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 5.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 1.h),
            _buildHero(context),
            SizedBox(height: 1.5.h),
            _build7DayChart(context),
            SizedBox(height: 1.5.h),
            _buildHowCalculated(context),
            SizedBox(height: 1.5.h),
            _buildAIInsight(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      padding: EdgeInsets.all(4.4.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [Color(0xFF1C1C1E), Color(0xFF2C3E50)],
        ),
        borderRadius: BorderRadius.circular(5.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recovery_score_last_7_days'.tr(context),
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            '84%',
            style: TextStyle(
              fontSize: 45.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF34C759),
              letterSpacing: -1,
              height: 1,
            ),
          ),
          SizedBox(height: 0.3.h),
          Text(
            'recovery_based_on_factors'.tr(context),
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroStat('68ms', 'hrv_rmssd'.tr(context)),
              _buildHeroStat('54bpm', 'resting_hr'.tr(context)),
              _buildHeroStat('98%', 'SpO2'),
              _buildHeroStat('7.2h', 'sleep_upper'.tr(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 0.2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            color: Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _build7DayChart(BuildContext context) {
    final scores = [72, 45, 88, 65, 91, 78, 84];
    final days = ['SAT', 'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI'];
    const maxScore = 100;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'seven_day_recovery_trend'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 2.h),
          SizedBox(
            height: 10.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final score = scores[index];
                final color = score >= 70
                    ? const Color(0xFF34C759)
                    : score >= 50
                    ? const Color(0xFFFF9500)
                    : const Color(0xFFFF3B30);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0.5.w),
                    child: Container(
                      height: (score / maxScore) * 10.h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(1.w),
                        ),
                        border: index == 6
                            ? Border.all(
                                color: const Color(0xFF1C1C1E),
                                width: 2,
                              )
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(height: 0.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              return Expanded(
                child: Text(
                  days[index].substring(0, 1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: index == 6 ? FontWeight.w700 : FontWeight.w600,
                    color: index == 6
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFC7C7CC),
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 2.h),
          Row(
            children: [
              _buildLegend(
                const Color(0xFF34C759),
                'recovery_good_range'.tr(context),
              ),
              SizedBox(width: 3.w),
              _buildLegend(
                const Color(0xFFFF9500),
                'recovery_ok_range'.tr(context),
              ),
              SizedBox(width: 3.w),
              _buildLegend(
                const Color(0xFFFF3B30),
                'recovery_low_range'.tr(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 1.w),
        Text(
          text,
          style: TextStyle(fontSize: 10.sp, color: const Color(0xFF8E8E93)),
        ),
      ],
    );
  }

  Widget _buildHowCalculated(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'how_recovery_is_calculated'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 1.5.h),
          _buildCalcRow(
            '🫀',
            'hrv_weight'.tr(context),
            '68ms',
            0.85,
            const Color(0xFF34C759),
          ),
          _buildCalcRow(
            '😴',
            'sleep_weight'.tr(context),
            '7.2h',
            0.80,
            const Color(0xFF5B3FBF),
          ),
          _buildCalcRow(
            '❤️',
            'resting_hr_weight'.tr(context),
            '54bpm',
            0.88,
            const Color(0xFFFF3B30),
          ),
          _buildCalcRow(
            '🩸',
            'spo2_weight'.tr(context),
            '98%',
            0.98,
            const Color(0xFF007AFF),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcRow(
    String emoji,
    String title,
    String value,
    double percent,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 16.sp)),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$value ✓',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF34C759),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 0.5.h),
                Container(
                  height: 0.6.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(1.w),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: percent,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(1.w),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsight(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(3.5.w),
        border: Border.all(color: const Color(0xFFB5D4F4), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(2.w),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 14.sp),
          ),
          SizedBox(width: 2.5.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF0C447C),
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: 'ai_prefix'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'recovery_ai_insight_body'.tr(context)),
                  TextSpan(
                    text: 'recovery_ai_intensity_high'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'recovery_ai_go_for_it'.tr(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
