import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../domain/models/diet_template_model.dart';
import 'daily_meal_plan_screen.dart';

class TemplateOverviewScreen extends StatelessWidget {
  final DietTemplateModel template;

  const TemplateOverviewScreen({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16.sp,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        title: Text(
          "${_localizeGoal(template.goal, context)} ${'plan'.tr(context)}",
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 22.h),
              child: Column(
                children: [
                  _buildHero(context),
                  _buildMacroBars(context),
                  _buildPlanRules(context),
                ],
              ),
            ),
          ),
          
          // Bottom CTA
          PositionedDirectional(
            bottom: 0,
            start: 0,
            end: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 12.h), // Safe area + padding
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFFF5F5F7),
                    const Color(0xFFF5F5F7).withValues(alpha: 0.0),
                  ],
                  stops: const [0.7, 1.0],
                ),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('nutrition_active_template_json', jsonEncode(template.toJson()));
                  await prefs.setString('nutrition_last_flow_path', '/daily_meal_plan');
                  await prefs.setString('nutrition_plan_start_date', DateTime.now().toIso8601String());
                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DailyMealPlanScreen(template: template),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  minimumSize: Size(double.infinity, 7.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20.sp),
                    SizedBox(width: 3.w),
                    Text(
                      'see_my_meal_plan'.tr(context),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${'template_applied'.tr(context)}${_localizeGoal(template.goal, context).toUpperCase()}",
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 0.7,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            '${template.title} 🔥',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            "${_localizeBodyType(template.bodyType, context)} · ${template.numberOfMeals}${'meals_per_day'.tr(context)}",
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroMacro(template.totalCalories.toString(), 'kcal_per_day'.tr(context)),
              _buildHeroMacro('${template.macros.protein}g', 'protein_upper'.tr(context)),
              _buildHeroMacro('${template.macros.carbs}g', 'carbs_upper'.tr(context)),
              _buildHeroMacro('${template.macros.fat}g', 'fat_upper'.tr(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMacro(String val, String lbl) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 0.3.h),
        Text(
          lbl,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroBars(BuildContext context) {
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
          Text(
            'new_daily_targets'.tr(context),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 2.h),
          _buildBarRow('protein_title'.tr(context), '${template.macros.protein}g', const Color(0xFF007AFF)),
          SizedBox(height: 1.5.h),
          _buildBarRow('carbs_title'.tr(context), '${template.macros.carbs}g', const Color(0xFFFF9500)),
          SizedBox(height: 1.5.h),
          _buildBarRow('fat_title'.tr(context), '${template.macros.fat}g', const Color(0xFFFF3B30)),
        ],
      ),
    );
  }

  Widget _buildBarRow(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A3A3C),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 0.8.h),
        Container(
          height: 1.0.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(1.w),
          ),
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            height: 1.0.h,
            width: 70.w, // Simulated full target bar
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1.w),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanRules(BuildContext context) {
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
          Text(
            'plan_rules'.tr(context),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 2.h),
          _buildRuleItem(
            '🔥',
            const Color(0xFFFFF0F0),
            'stick_to_calories'.tr(context),
            'stick_to_calories_desc'.tr(context),
          ),
          _buildRuleItem(
            '💪',
            const Color(0xFFE8F5FF),
            'hit_protein'.tr(context),
            'hit_protein_desc'.tr(context),
          ),
          _buildRuleItem(
            '💧',
            const Color(0xFFF0EEFF),
            'water_minimum'.tr(context),
            'water_minimum_desc'.tr(context),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String emoji, Color bg, String title, String sub, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 11.w,
            height: 11.w,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2.w),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: TextStyle(fontSize: 18.sp)),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF6E6E73),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  String _localizeBodyType(String type, BuildContext context) {
    switch (type) {
      case 'All': return 'tab_all'.tr(context);
      case 'Ectomorph': return 'ectomorph'.tr(context);
      case 'Mesomorph': return 'mesomorph'.tr(context);
      case 'Endomorph': return 'endomorph'.tr(context);
      default: return type;
    }
  }

  String _localizeGoal(String goal, BuildContext context) {
    switch (goal) {
      case 'All': return 'tab_all'.tr(context);
      case 'Cutting': return 'cutting'.tr(context);
      case 'Bulking': return 'bulking'.tr(context);
      case 'Maintenance': return 'maintenance_goal'.tr(context);
      case 'Fat Loss': return 'fat_loss'.tr(context);
      default: return goal;
    }
  }
}
