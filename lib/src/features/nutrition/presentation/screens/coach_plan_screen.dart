import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../widgets/nutrition_settings_sheet.dart';

class CoachPlanScreen extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const CoachPlanScreen({super.key, required this.navigatorKey});

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
          'coach_plan_title'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () {
              NutritionSettingsSheet.show(context, navigatorKey.currentState!);
            },
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 3.w),
              child: Icon(Icons.settings_rounded, color: const Color(0xFF1C1C1E), size: 20.sp),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(end: 4.w),
            child: Icon(Icons.message_rounded, color: const Color(0xFF1C1C1E), size: 20.sp),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Column(
            children: [
              _buildCoachCard(context),
              _buildCoachNote(context),
              _buildMealsSection(context),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 8.h),
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
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A7A30),
            minimumSize: Size(double.infinity, 6.5.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5.w)),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, color: Colors.white, size: 16.sp),
              SizedBox(width: 2.w),
              Text(
                'follow_coach_plan'.tr(context),
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

  Widget _buildCoachCard(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('assigned_by'.tr(context), style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.4), letterSpacing: 0.7)),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Container(
                width: 14.w, height: 14.w,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('👨‍💼', style: TextStyle(fontSize: 22.sp)),
              ),
              SizedBox(width: 3.5.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('coach_khalid'.tr(context), style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    SizedBox(height: 0.2.h),
                    Text('coach_khalid_desc'.tr(context), style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroStat('2,800', 'kcal_upper'.tr(context), Colors.white),
              _buildMacroStat('160g', 'protein_upper'.tr(context), const Color(0xFF007AFF)),
              _buildMacroStat('330g', 'carbs_upper'.tr(context), const Color(0xFFFF9500)),
              _buildMacroStat('75g', 'fat_upper'.tr(context), const Color(0xFFFF3B30)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(String val, String lbl, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: color)),
        SizedBox(height: 0.2.h),
        Text(lbl, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.4))),
      ],
    );
  }

  Widget _buildCoachNote(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(3.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('coach_note_updated'.tr(context), style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: const Color(0xFF8E8E93), letterSpacing: 0.5)),
          SizedBox(height: 1.h),
          Text(
            'coach_note_msg'.tr(context),
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF3A3A3C), height: 1.5, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildMealsSection(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 2.5.h, 4.w, 1.5.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'coachs_meal_plan'.tr(context),
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E)),
                ),
              ],
            ),
          ),
          _buildMealRow(
            icon: '🌅', iconBg: const Color(0xFFFFF8E8),
            name: 'breakfast_7am'.tr(context), macros: '480 kcal · P:42g · C:55g · F:12g',
            foods: [
              _buildFoodItem('🥣', 'oats_protein_powder'.tr(context), 'oats_whey_desc'.tr(context), '390'),
              _buildFoodItem('🍳', 'egg_whites_5'.tr(context), '150g · P:18g · C:0g · F:0g', '83'),
            ],
          ),
          _buildMealRow(
            icon: '☀️', iconBg: const Color(0xFFE8F5FF),
            name: 'lunch_1230pm'.tr(context), macros: '720 kcal · P:58g · C:88g · F:14g',
            foods: [
              _buildFoodItem('🍗', 'chicken_breast'.tr(context), 'chicken_breast_desc'.tr(context), '310'),
              _buildFoodItem('🍠', 'sweet_potato'.tr(context), 'sweet_potato_desc'.tr(context), '172'),
              _buildFoodItem('🥗', 'green_salad_olive_oil'.tr(context), 'green_salad_desc'.tr(context), '80'),
            ],
          ),
          _buildMealRow(
            icon: '🏆', iconBg: const Color(0xFFE8FFF0),
            name: 'post_workout'.tr(context), macros: 'coach_within_20min'.tr(context),
            foods: [
              _buildFoodItem('🥛', 'whey_isolate'.tr(context), 'whey_isolate_desc'.tr(context), '154'),
              _buildFoodItem('🍌', 'banana'.tr(context), 'banana_desc'.tr(context), '105'),
            ],
          ),
          _buildMealRow(
            icon: '🌙', iconBg: const Color(0xFFEBF5FF),
            name: 'dinner_9pm'.tr(context), macros: '560 kcal · P:48g · C:40g · F:18g',
            borderBottom: false,
            foods: [
              _buildFoodItem('🥩', 'lean_beef_150g'.tr(context), 'lean_beef_desc'.tr(context), '280'),
              _buildFoodItem('🥦', 'steamed_vegetables'.tr(context), 'steamed_vegetables_desc'.tr(context), '60'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealRow({
    required String icon, required Color iconBg,
    required String name, required String macros,
    required List<Widget> foods,
    bool borderBottom = true,
  }) {
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF5F5F7), width: 0.5))),
      padding: EdgeInsets.only(bottom: borderBottom ? 0 : 2.h),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Container(
                  width: 10.w, height: 10.w,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(2.5.w)),
                  alignment: Alignment.center,
                  child: Text(icon, style: TextStyle(fontSize: 20.sp)),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
                      SizedBox(height: 0.2.h),
                      Text(macros, style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...foods,
        ],
      ),
    );
  }

  Widget _buildFoodItem(String emoji, String name, String macros, String cal) {
    return Container(
      padding: EdgeInsets.fromLTRB(5.w, 1.5.h, 4.w, 1.5.h),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF8F8F8), width: 0.5))),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 22.sp)),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
                SizedBox(height: 0.2.h),
                Text(macros, style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93))),
              ],
            ),
          ),
          Text('$cal kcal', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
        ],
      ),
    );
  }
}
