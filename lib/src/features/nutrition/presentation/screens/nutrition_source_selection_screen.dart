import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/shared_preferences_provider.dart';

class NutritionSourceSelectionScreen extends ConsumerWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const NutritionSourceSelectionScreen({super.key, required this.navigatorKey});

  void _selectAndNavigate(WidgetRef ref, String path) {
    ref.read(sharedPreferencesProvider).setString('nutrition_last_flow_path', path);
    navigatorKey.currentState!.pushNamed(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'nav_nutrition'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 4.w),
            child: Icon(Icons.more_horiz, color: const Color(0xFF1C1C1E), size: 18.sp),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.only(start: 1.w, bottom: 2.h),
                child: Text(
                  'how_plan_meals'.tr(context),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8E8E93),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _buildSourceCard(
                icon: '🤖',
                iconBg: const Color(0xFFE8F5FF),
                title: 'ai_coach_plan'.tr(context),
                subtitle: 'ai_coach_plan_desc'.tr(context),
                badgeText: 'auto'.tr(context),
                badgeColor: const Color(0xFF007AFF),
                badgeBg: const Color(0xFFE8F5FF),
                onTap: () => _selectAndNavigate(ref, '/ai_coach'),
              ),
              SizedBox(height: 1.5.h),
              _buildSourceCard(
                icon: '👨‍💼',
                iconBg: const Color(0xFFE8FFF0),
                title: 'coach_plan'.tr(context),
                subtitle: 'coach_plan_desc'.tr(context),
                badgeText: 'coach'.tr(context),
                badgeColor: const Color(0xFF1A7A30),
                badgeBg: const Color(0xFFE8FFF0),
                onTap: () => _selectAndNavigate(ref, '/coach_plan'),
              ),
              SizedBox(height: 1.5.h),
              _buildSourceCard(
                icon: '📋',
                iconBg: const Color(0xFFF0EEFF),
                title: 'ready_templates'.tr(context),
                subtitle: 'ready_templates_desc'.tr(context),
                badgeText: 'templates'.tr(context),
                badgeColor: const Color(0xFF5B3FBF),
                badgeBg: const Color(0xFFF0EEFF),
                onTap: () => _selectAndNavigate(ref, '/templates'),
              ),
              SizedBox(height: 1.5.h),
              _buildSourceCard(
                icon: '✏️',
                iconBg: const Color(0xFFFFF8E8),
                title: 'build_my_own'.tr(context),
                subtitle: 'build_my_own_desc'.tr(context),
                badgeText: 'custom'.tr(context),
                badgeColor: const Color(0xFF7A4D0A),
                badgeBg: const Color(0xFFFFF8E8),
                onTap: () => _selectAndNavigate(ref, '/build_own'),
              ),
              SizedBox(height: 2.h),
              _buildQuickActions(ref, context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(WidgetRef ref, BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _buildActionBox('food_search'.tr(context), 'gym_score'.tr(context), const Color(0xFF1C1C1E), Icons.search_rounded, () => _selectAndNavigate(ref, '/food_search')),
          SizedBox(width: 3.w),
          _buildActionBox('supplements'.tr(context), 'creatine_whey'.tr(context), const Color(0xFF5B3FBF), Icons.medication_liquid_rounded, () => _selectAndNavigate(ref, '/supplements')),
        ],
      ),
    );
  }

  Widget _buildActionBox(String title, String subtitle, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42.w,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3.5.w),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        child: Column(
            children: [
              Container(
                width: 11.w,
                height: 11.w,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2.5.w),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: 18.sp),
              ),
              SizedBox(height: 1.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E)),
              ),
              SizedBox(height: 0.2.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildSourceCard({
    required String icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 14.w,
              height: 14.w,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(3.w),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: TextStyle(fontSize: 24.sp)),
            ),
            SizedBox(width: 3.5.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 3.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ),
            SizedBox(width: 2.5.w),
            Container(
              width: 5.w,
              height: 5.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD1D1D6), width: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
