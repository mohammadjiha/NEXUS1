import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';

class MealTimingScreen extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const MealTimingScreen({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => navigatorKey.currentState!.pop(),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16.sp, color: const Color(0xFF1C1C1E)),
        ),
        title: Text(
          'meal_timing'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Column(
            children: [
              _buildHeaderBox(context),
              _buildTimingStrip(context),
              _buildHydrationBox(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBox(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(4.w),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('today_push_day'.tr(context), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.5)),
          SizedBox(height: 1.h),
          Text('workout_at_6pm'.tr(context), style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: Colors.white)),
          SizedBox(height: 0.5.h),
          Text('meals_timed_around_session'.tr(context), style: TextStyle(fontSize: 15.sp, color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildTimingStrip(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          _buildTimingRow(
            time: 'time_7am'.tr(context), icon: '🌅', iconBg: const Color(0xFFFFF8E8),
            name: 'breakfast_meal'.tr(context), foods: 'breakfast_foods'.tr(context),
            macros: 'breakfast_macros'.tr(context), macroColor: const Color(0xFF007AFF),
            tag: 'anytime'.tr(context), tagColor: const Color(0xFF3A3A3C), tagBg: const Color(0xFFF5F5F7),
          ),
          _buildTimingRow(
            time: 'time_12pm'.tr(context), icon: '☀️', iconBg: const Color(0xFFE8F5FF),
            name: 'lunch_meal'.tr(context), foods: 'lunch_foods'.tr(context),
            macros: 'lunch_macros'.tr(context), macroColor: const Color(0xFF007AFF),
            tag: 'anytime'.tr(context), tagColor: const Color(0xFF3A3A3C), tagBg: const Color(0xFFF5F5F7),
          ),
          _buildTimingRow(
            time: 'time_430pm'.tr(context), icon: '⚡', iconBg: const Color(0xFFFFF8E8),
            name: 'pre_workout_meal'.tr(context), foods: 'pre_workout_foods'.tr(context),
            macros: 'pre_workout_macros'.tr(context), macroColor: const Color(0xFFFF9500),
            tag: 'pre_workout_tag'.tr(context), tagColor: const Color(0xFF7A4D0A), tagBg: const Color(0xFFFFF8E8),
          ),
          _buildTimingRow(
            time: 'time_7pm'.tr(context), icon: '🏆', iconBg: const Color(0xFFE8FFF0),
            name: 'post_workout_meal'.tr(context), foods: 'post_workout_foods'.tr(context),
            macros: 'post_workout_macros'.tr(context), macroColor: const Color(0xFF34C759),
            tag: 'post_workout_tag'.tr(context), tagColor: const Color(0xFF1A7A30), tagBg: const Color(0xFFE8FFF0),
            borderColor: const Color(0xFF34C759),
            subLabel: 'within_30_min'.tr(context),
          ),
          _buildTimingRow(
            time: 'time_9pm'.tr(context), icon: '🌙', iconBg: const Color(0xFFEBF5FF),
            name: 'dinner_meal'.tr(context), foods: 'dinner_foods'.tr(context),
            macros: 'dinner_macros'.tr(context), macroColor: const Color(0xFF007AFF),
            tag: 'anytime'.tr(context), tagColor: const Color(0xFF3A3A3C), tagBg: const Color(0xFFF5F5F7),
          ),
          _buildTimingRow(
            time: 'time_11pm'.tr(context), icon: '😴', iconBg: const Color(0xFFF0EEFF),
            name: 'before_sleep'.tr(context), foods: 'before_sleep_foods'.tr(context),
            macros: 'before_sleep_macros'.tr(context), macroColor: const Color(0xFF5B3FBF),
            tag: 'sleep_tag'.tr(context), tagColor: const Color(0xFF5B3FBF), tagBg: const Color(0xFFF0EEFF),
            subLabel: 'slow_protein_desc'.tr(context),
            subLabelColor: const Color(0xFF5B3FBF),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingRow({
    required String time, required String icon, required Color iconBg,
    required String name, required String foods, required String macros, required Color macroColor,
    required String tag, required Color tagColor, required Color tagBg,
    Color? borderColor, String? subLabel, Color? subLabelColor,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.5.w),
        border: Border.all(color: borderColor ?? const Color(0xFFE5E5EA), width: borderColor != null ? 1.5 : 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 10.w,
            child: Text(
              time,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), height: 1.2),
            ),
          ),
          Container(
            width: 1.w,
            margin: EdgeInsets.symmetric(horizontal: 2.w),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFE5E5EA), width: 1.5)),
            ),
          ),
          Container(
            width: 11.w, height: 11.w,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(2.w)),
            alignment: Alignment.center,
            child: Text(icon, style: TextStyle(fontSize: 22.sp)),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
                SizedBox(height: 0.2.h),
                Text(foods, style: TextStyle(fontSize: 15.sp, color: const Color(0xFF6E6E73))),
                SizedBox(height: 0.5.h),
                Text(macros, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: macroColor)),
                if (subLabel != null) ...[
                  SizedBox(height: 0.5.h),
                  Text(subLabel, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: subLabelColor ?? const Color(0xFF34C759))),
                ]
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
            decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(2.w)),
            child: Text(tag, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: tagColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationBox(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 1.5.h),
            child: Text('gym_hydration'.tr(context), style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
            child: Column(
              children: [
                _buildHydrationRow('⏰', 'before_workout'.tr(context), 'before_workout_desc'.tr(context)),
                SizedBox(height: 1.h),
                _buildHydrationRow('🏋️', 'during_workout'.tr(context), 'during_workout_desc'.tr(context)),
                SizedBox(height: 1.h),
                _buildHydrationRow('✅', 'after_workout'.tr(context), 'after_workout_desc'.tr(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationRow(String emoji, String title, String sub) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5FF),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: const Color(0xFF0C447C))),
                SizedBox(height: 0.2.h),
                Text(sub, style: TextStyle(fontSize: 14.sp, color: const Color(0xFF007AFF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
