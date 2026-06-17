import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';

class HeartRateDetailScreen extends StatefulWidget {
  const HeartRateDetailScreen({super.key});

  @override
  State<HeartRateDetailScreen> createState() => _HeartRateDetailScreenState();
}

class _HeartRateDetailScreenState extends State<HeartRateDetailScreen>
    with SingleTickerProviderStateMixin {
  int _liveHr = 72;
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _simulateLiveHr();
  }

  void _simulateLiveHr() async {
    final rand = Random();
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _liveHr = 70 + rand.nextInt(6);
        });
      }
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

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
          'heart_rate'.tr(context),
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
            _buildHRChart(context),
            SizedBox(height: 1.5.h),
            _buildNormalRanges(context),
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
          colors: [Color(0xFFFF3B30), Color(0xFFC0392B)],
        ),
        borderRadius: BorderRadius.circular(5.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FadeTransition(
                opacity: _blinkController,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 1.5.w),
              Text(
                'live_heart_rate'.tr(context),
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          SizedBox(height: 0.5.h),
          Text(
            '$_liveHr',
            style: TextStyle(
              fontSize: 48.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -2,
              height: 1,
            ),
          ),
          SizedBox(height: 0.3.h),
          Text(
            'bpm_resting'.tr(context),
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroStat('54', 'resting'.tr(context)),
              _buildHeroStat('178', 'max_today'.tr(context)),
              _buildHeroStat('142', 'avg_workout'.tr(context)),
              _buildHeroStat('85', 'avg_day'.tr(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String val, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
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

  Widget _buildHRChart(BuildContext context) {
    final hrs = ['12a', '3a', '6a', '9a', '12p', '3p', '6p', '9p'];
    final vals = [54, 52, 51, 58, 72, 85, 142, 88];
    const maxVal = 150;

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
            'todays_heart_rate'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            'twenty_four_hours_apple_watch'.tr(context),
            style: TextStyle(fontSize: 11.sp, color: const Color(0xFF8E8E93)),
          ),
          SizedBox(height: 2.h),
          SizedBox(
            height: 10.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(8, (index) {
                final v = vals[index];
                final color = v > 141
                    ? const Color(0xFFFF3B30)
                    : v > 100
                    ? const Color(0xFFFF9500)
                    : v > 70
                    ? const Color(0xFF007AFF)
                    : const Color(0xFF34C759);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 0.5.w),
                    child: Container(
                      height: (v / maxVal) * 10.h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(1.w),
                        ),
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
            children: List.generate(8, (index) {
              return Expanded(
                child: Text(
                  hrs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC7C7CC),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalRanges(BuildContext context) {
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
            'your_normal_ranges'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 1.5.h),
          _buildRangeRow(
            'resting_hr'.tr(context),
            '54 bpm ✓ ${'athlete'.tr(context)}',
            const Color(0xFF34C759),
          ),
          _buildRangeRow(
            'max_hr_est'.tr(context),
            '202 bpm (18yr)',
            const Color(0xFF1C1C1E),
          ),
          _buildRangeRow(
            'fat_burn_zone'.tr(context),
            '101–141 bpm',
            const Color(0xFFFF9500),
          ),
          _buildRangeRow('Peak Zone', '162–202 bpm', const Color(0xFFFF3B30)),
        ],
      ),
    );
  }

  Widget _buildRangeRow(String label, String val, Color valColor) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(2.5.w),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: valColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
