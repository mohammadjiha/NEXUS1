import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../domain/models/food_model.dart';

class FoodDetailScreen extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final FoodModel food;

  const FoodDetailScreen({
    super.key,
    required this.navigatorKey,
    required this.food,
  });

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
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16.sp,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        title: Text(
          'food_details'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 4.w),
            child: Icon(
              Icons.star_border_rounded,
              color: const Color(0xFF1C1C1E),
              size: 18.sp,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 15.h),
          child: Column(
            children: [
              _buildHero(context),
              _buildMacroGrid(context),
              _buildGymPerformance(context),
              _buildGymScoreFull(context),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 4.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFF5F5F7),
              const Color(0xFFF5F5F7).withValues(alpha: 0.0),
            ],
            stops: const [0.68, 1.0],
          ),
        ),
        child: ElevatedButton(
          onPressed: () {
            final displayName = food.localizedName(
              Localizations.localeOf(context).languageCode,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$displayName${'added_to_meal_toast'.tr(context)}',
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C1C1E),
            minimumSize: Size(double.infinity, 6.5.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3.5.w),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 18.sp),
              SizedBox(width: 2.w),
              Text(
                'add_to_meal'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final displayName = food.localizedName(
      Localizations.localeOf(context).languageCode,
    );
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(5.w),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayName,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 0.2.h),
          Text(
            food.servingSize,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroGrid(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildGridItem(
                _fmt(food.calories),
                'calories_upper'.tr(context),
                const Color(0xFF1C1C1E),
                borderRight: true,
                borderBottom: true,
              ),
              _buildGridItem(
                '${_fmt(food.protein)}g',
                'protein_upper'.tr(context),
                const Color(0xFF007AFF),
                borderRight: true,
                borderBottom: true,
              ),
              _buildGridItem(
                '${_fmt(food.carbs)}g',
                'carbs_upper'.tr(context),
                const Color(0xFFFF9500),
                borderRight: true,
                borderBottom: true,
              ),
              _buildGridItem(
                '${_fmt(food.fat)}g',
                'fat_upper'.tr(context),
                const Color(0xFFFF3B30),
                borderBottom: true,
              ),
            ],
          ),
          Row(
            children: [
              _buildGridItem(
                _macroSplit('protein'),
                'protein_pct'.tr(context),
                const Color(0xFF007AFF),
                borderRight: true,
              ),
              _buildGridItem(
                _macroSplit('carbs'),
                'carbs_pct'.tr(context),
                const Color(0xFFFF9500),
                borderRight: true,
              ),
              _buildGridItem(
                _macroSplit('fat'),
                'fat_pct'.tr(context),
                const Color(0xFFFF3B30),
                borderRight: true,
              ),
              _buildGridItem(
                food.tags.isEmpty ? '0' : '${food.tags.length}',
                'tags_upper'.tr(context),
                const Color(0xFF1C1C1E),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
    String val,
    String lbl,
    Color color, {
    bool borderRight = false,
    bool borderBottom = false,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.5.h),
        decoration: BoxDecoration(
          border: Border(
            right: borderRight
                ? const BorderSide(color: Color(0xFFF0F0F5), width: 0.5)
                : BorderSide.none,
            bottom: borderBottom
                ? const BorderSide(color: Color(0xFFF0F0F5), width: 0.5)
                : BorderSide.none,
          ),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: 0.2.h),
            Text(
              lbl,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymPerformance(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'gym_performance_details'.tr(context),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildPerformanceRow(
            'protein_density'.tr(context),
            '${_proteinPer100Kcal()}g/100kcal',
            _proteinNote(context),
          ),
          _buildPerformanceRow(
            'calories_title'.tr(context),
            '${_fmt(food.calories)} kcal',
            food.calories > 300
                ? 'dense_lower'.tr(context)
                : 'manageable_lower'.tr(context),
          ),
          _buildPerformanceRow(
            'carbs_title'.tr(context),
            '${_fmt(food.carbs)}g',
            food.carbs > 25
                ? 'energy_source'.tr(context)
                : 'low_carb_lower'.tr(context),
          ),
          _buildPerformanceRow(
            'fat_title'.tr(context),
            '${_fmt(food.fat)}g',
            food.fat > 15
                ? 'high_fat_lower'.tr(context)
                : 'controlled_lower'.tr(context),
          ),
          _buildPerformanceRow(
            'best_timing'.tr(context),
            _bestTiming(context),
            '',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(
    String name,
    String val,
    String note, {
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF8F8F8), width: 0.5),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3A3A3C),
              ),
            ),
          ),
          Row(
            children: [
              Text(
                val,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              if (note.isNotEmpty) ...[
                SizedBox(width: 1.5.w),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGymScoreFull(BuildContext context) {
    final score = food.gymScore.clamp(0, 10);
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmt(score),
                    style: TextStyle(
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'gym_score_10'.tr(context),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
                decoration: BoxDecoration(
                  color: _scoreBg(score),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Text(
                  _scoreLabel(score, context),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: _scoreColor(score),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildScoreBar(
            'protein_score'.tr(context),
            (food.protein / 35).clamp(0, 1),
            _fmt((food.protein / 3.5).clamp(0, 10)),
            const Color(0xFF007AFF),
          ),
          SizedBox(height: 1.h),
          _buildScoreBar(
            'calorie_control'.tr(context),
            (1 - (food.calories / 700)).clamp(0, 1),
            _fmt((10 - food.calories / 70).clamp(0, 10)),
            const Color(0xFF34C759),
          ),
          SizedBox(height: 1.h),
          _buildScoreBar(
            'energy_score'.tr(context),
            (food.carbs / 60).clamp(0, 1),
            _fmt((food.carbs / 6).clamp(0, 10)),
            const Color(0xFFFF9500),
          ),
          SizedBox(height: 2.5.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: food.tags
                .take(8)
                .map((t) => _buildTimingBadge(t, context))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String lbl, double pct, String val, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 32.w,
          child: Text(
            lbl,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3A3A3C),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(1.h),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFF0F0F5),
              color: color,
              minHeight: 0.8.h,
            ),
          ),
        ),
        SizedBox(width: 3.w),
        SizedBox(
          width: 8.w,
          child: Text(
            val,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimingBadge(String txt, BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FFF0),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1A7A30),
        ),
      ),
    );
  }

  String _fmt(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  String _macroSplit(String macro) {
    final total = food.protein * 4 + food.carbs * 4 + food.fat * 9;
    if (total <= 0) return '0%';
    final value = switch (macro) {
      'protein' => food.protein * 4,
      'carbs' => food.carbs * 4,
      _ => food.fat * 9,
    };
    return '${((value / total) * 100).round()}%';
  }

  String _proteinPer100Kcal() {
    if (food.calories <= 0) return '0';
    return _fmt(food.protein / food.calories * 100);
  }

  String _proteinNote(BuildContext context) {
    if (food.protein >= 20) return 'protein_high'.tr(context);
    if (food.protein >= 10) return 'protein_moderate'.tr(context);
    return 'protein_low'.tr(context);
  }

  String _bestTiming(BuildContext context) {
    if (food.protein >= 20 && food.carbs <= 10) {
      return 'timing_post_workout'.tr(context);
    }
    if (food.carbs >= 25 && food.fat <= 8) {
      return 'timing_pre_workout'.tr(context);
    }
    if (food.fat >= 15) return 'timing_away_workout'.tr(context);
    return 'timing_anytime'.tr(context);
  }

  Color _scoreColor(num score) {
    if (score >= 9) return const Color(0xFF1A7A30);
    if (score >= 7) return const Color(0xFF007AFF);
    return const Color(0xFFC0392B);
  }

  Color _scoreBg(num score) {
    if (score >= 9) return const Color(0xFFE8FFF0);
    if (score >= 7) return const Color(0xFFE8F5FF);
    return const Color(0xFFFFF0F0);
  }

  String _scoreLabel(num score, BuildContext context) {
    if (score >= 9) return 'score_excellent'.tr(context);
    if (score >= 7) return 'score_good'.tr(context);
    return 'score_limit'.tr(context);
  }
}
