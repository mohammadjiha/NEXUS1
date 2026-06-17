import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../providers/wearables_provider.dart';
import 'heart_rate_detail_screen.dart';
import 'recovery_detail_screen.dart';

class WearablesDashboardScreen extends ConsumerWidget {
  const WearablesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedWatch =
        ref.watch(connectedWearableProvider) ?? 'Apple Watch';
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
          'health_dashboard'.tr(context),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.sync_rounded,
              color: const Color(0xFF1C1C1E),
              size: 18.sp,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('sync_now_last_synced_2_min'.tr(context)),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 5.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 1.h),
            _buildRecoveryHero(context, connectedWatch),
            SizedBox(height: 1.5.h),
            _buildAIInsight(context),
            SizedBox(height: 2.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.4.w),
              child: Text(
                'live_vitals'.tr(context),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF8E8E93),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(height: 1.h),
            _buildLiveVitals(context, ref),
            SizedBox(height: 1.5.h),
            _buildAutoDetectedWorkout(context, connectedWatch),
            SizedBox(height: 1.5.h),
            _buildSleepCard(context),
            SizedBox(height: 1.5.h),
            _buildHRZonesCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryHero(BuildContext context, String connectedWatch) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecoveryDetailScreen()),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.4.w),
        padding: EdgeInsets.all(4.4.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(5.5.w),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF34C759),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 1.5.w),
                        SizedBox(
                          width: 55.w,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '${'live'.tr(context)} ? ${connectedWatch.toUpperCase()} ? ${'updated_2_min_ago'.tr(context)}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.5),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      '84%',
                      style: TextStyle(
                        fontSize: 45.sp,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF34C759),
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'recovery_score_great'.tr(context),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        value: 0.84,
                        strokeWidth: 2.w,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF34C759),
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text('💚', style: TextStyle(fontSize: 16.sp)),
                  ],
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            SizedBox(height: 1.5.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHeroStat('7.2h', 'SLEEP', const Color(0xFF5B3FBF)),
                _buildHeroStat('68ms', 'HRV', const Color(0xFF34C759)),
                _buildHeroStat('54', 'RHR', const Color(0xFFFF3B30)),
                _buildHeroStat('98%', 'SpO2', const Color(0xFF007AFF)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStat(String val, String label, Color valColor) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: valColor,
            height: 1,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: Colors.white.withValues(alpha: 0.35),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
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
                    text: '${'ai_coach'.tr(context)}: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'wearable_ai_recovery_insight'.tr(context)),
                  TextSpan(
                    text: 'push_day_ready'.tr(context),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: 'wearable_ai_added_bench'.tr(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveVitals(BuildContext context, WidgetRef ref) {
    final hrAsync = ref.watch(heartRateProvider);
    final stepsAsync = ref.watch(stepsProvider);

    final hrValue = hrAsync.when(
      data: (val) => val?.toString() ?? '--',
      loading: () => '...',
      error: (_, __) => '--',
    );

    final stepsValue = stepsAsync.when(
      data: (val) => val.toString(),
      loading: () => '...',
      error: (_, __) => '--',
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.4.w),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 2.w,
        mainAxisSpacing: 2.w,
        childAspectRatio: 1.15,
        children: [
          _buildVitalCard(
            context,
            '❤️',
            hrValue,
            'bpm',
            'heart_rate'.tr(context),
            'trend_resting'.tr(context),
            const Color(0xFF34C759),
            true,
            isHR: true,
          ),
          _buildVitalCard(
            context,
            '🫀',
            '68',
            'ms',
            'HRV',
            'trend_above_avg'.tr(context),
            const Color(0xFF34C759),
            false,
            isHRV: true,
          ),
          _buildVitalCard(
            context,
            '🩸',
            '98',
            '%',
            'blood_oxygen'.tr(context),
            'trend_normal'.tr(context),
            const Color(0xFF34C759),
            false,
          ),
          _buildVitalCard(
            context,
            '🚶',
            stepsValue,
            '',
            'steps_today'.tr(context),
            '${'goal'.tr(context)}: 7,500',
            const Color(0xFFFF9500),
            true,
          ),
          _buildVitalCard(
            context,
            '🧠',
            '24',
            '/100',
            'stress_level'.tr(context),
            'trend_low'.tr(context),
            const Color(0xFF34C759),
            false,
          ),
          _buildVitalCard(
            context,
            '🔥',
            '480',
            '',
            'cal_burned'.tr(context),
            'active_cals'.tr(context),
            const Color(0xFF1C1C1E),
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(
    BuildContext context,
    String icon,
    String val,
    String unit,
    String label,
    String trend,
    Color trendColor,
    bool isLive, {
    bool isHR = false,
    bool isHRV = false,
  }) {
    return GestureDetector(
      onTap: () {
        if (isHR) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HeartRateDetailScreen()),
          );
        }
        if (isHRV) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RecoveryDetailScreen()),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icon, style: TextStyle(fontSize: 24.sp)),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        val,
                        style: TextStyle(
                          fontSize: 26.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1C1C1E),
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                      if (unit.isNotEmpty)
                        Text(
                          ' $unit',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 0.5.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF8E8E93),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 0.2.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: trendColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (isLive)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34C759),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoDetectedWorkout(
    BuildContext context,
    String connectedWatch,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4.w),
                topRight: Radius.circular(4.w),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  alignment: Alignment.center,
                  child: Text('🏋️', style: TextStyle(fontSize: 16.sp)),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'workout_detected'.tr(context),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 0.2.h),
                      Text(
                        '${'wearable_detected_session_prefix'.tr(context)} $connectedWatch ${'wearable_detected_session_suffix'.tr(context)}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '58 min',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF34C759),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(3.5.w),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFF0F0F5),
                      width: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Row(
                    children: [
                      _buildAutoStat('142', 'avg_hr'.tr(context)),
                      Container(
                        width: 0.5,
                        height: 4.h,
                        color: const Color(0xFFF0F0F5),
                      ),
                      _buildAutoStat('178', 'max_hr'.tr(context)),
                      Container(
                        width: 0.5,
                        height: 4.h,
                        color: const Color(0xFFF0F0F5),
                      ),
                      _buildAutoStat('480', 'calories'.tr(context)),
                      Container(
                        width: 0.5,
                        height: 4.h,
                        color: const Color(0xFFF0F0F5),
                      ),
                      _buildAutoStat('58m', 'duration'.tr(context)),
                    ],
                  ),
                ),
                SizedBox(height: 1.5.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1C1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3.w),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                        ),
                        child: Text(
                          'log_this_session'.tr(context),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w),
                          side: const BorderSide(
                            color: Color(0xFFE5E5EA),
                            width: 0.5,
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 2.h,
                          horizontal: 6.w,
                        ),
                      ),
                      child: Text(
                        'dismiss'.tr(context),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3A3A3C),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoStat(String val, String label) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 1.h),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                val,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                  height: 1,
                ),
              ),
            ),
            SizedBox(height: 0.3.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'last_nights_sleep'.tr(context),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                Text(
                  '${'score'.tr(context)}: 82/100',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF5B3FBF),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Container(
              height: 2.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2.w),
              ),
              clipBehavior: Clip.hardEdge,
              child: Row(
                children: [
                  Expanded(
                    flex: 8,
                    child: Container(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                    ),
                  ),
                  Expanded(
                    flex: 20,
                    child: Container(color: const Color(0xFF5B3FBF)),
                  ),
                  Expanded(
                    flex: 35,
                    child: Container(color: const Color(0xFF1C1C1E)),
                  ),
                  Expanded(
                    flex: 25,
                    child: Container(
                      color: const Color(0xFF5B3FBF).withValues(alpha: 0.7),
                    ),
                  ),
                  Expanded(
                    flex: 12,
                    child: Container(
                      color: const Color(0xFF34C759).withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 1.5.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Column(
              children: [
                _buildSleepStageRow(
                  'deep_sleep'.tr(context),
                  '1h 45m',
                  const Color(0xFF1C1C1E),
                  0.8,
                ),
                _buildSleepStageRow(
                  'rem_sleep'.tr(context),
                  '1h 25m',
                  const Color(0xFF5B3FBF),
                  0.65,
                ),
                _buildSleepStageRow(
                  'light_sleep'.tr(context),
                  '3h 40m',
                  const Color(0xFF8E8E93).withValues(alpha: 0.4),
                  1.0,
                  isLight: true,
                ),
                _buildSleepStageRow(
                  'awake'.tr(context),
                  '0h 22m',
                  const Color(0xFFFF3B30).withValues(alpha: 0.5),
                  0.15,
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${'bedtime'.tr(context)}: 11:48 PM',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${'total'.tr(context)}: 7h 12m',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      '${'wake'.tr(context)}: 7:00 AM',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF8E8E93),
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

  Widget _buildSleepStageRow(
    String name,
    String time,
    Color color,
    double pct, {
    bool isLight = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 2.w),
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3A3A3C),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              height: 0.8.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(1.w),
              ),
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.w),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                time,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3A3C),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHRZonesCard(BuildContext context) {
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
            'heart_rate_zones'.tr(context),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            'last_workout_push_day_58_min'.tr(context),
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
          ),
          SizedBox(height: 1.5.h),
          _buildHRZoneRow(
            'zone_1_rest'.tr(context),
            '6m',
            '10%',
            const Color(0xFF8E8E93).withValues(alpha: 0.5),
            0.1,
          ),
          _buildHRZoneRow(
            'zone_2_fat_burn'.tr(context),
            '17m',
            '30%',
            const Color(0xFF34C759),
            0.3,
          ),
          _buildHRZoneRow(
            'zone_3_cardio'.tr(context),
            '23m',
            '40%',
            const Color(0xFFFF9500),
            0.4,
          ),
          _buildHRZoneRow(
            'zone_4_peak'.tr(context),
            '9m',
            '15%',
            const Color(0xFFFF3B30),
            0.15,
          ),
          _buildHRZoneRow(
            'zone_5_max'.tr(context),
            '3m',
            '5%',
            const Color(0xFF8B0000),
            0.05,
          ),
        ],
      ),
    );
  }

  Widget _buildHRZoneRow(
    String name,
    String time,
    String pct,
    Color color,
    double widthPct,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.7.h),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 1),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            flex: 7,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF3A3A3C),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              height: 0.8.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(1.w),
              ),
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: widthPct,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1.w),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            flex: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                time,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF3A3A3C),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                pct,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
