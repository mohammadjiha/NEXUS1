import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';

class NutritionSettingsSheet {
  static void show(BuildContext context, NavigatorState navigator) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPath = prefs.getString('nutrition_last_flow_path');

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildSheet(ctx, currentPath, navigator),
    );
  }

  static Widget _buildSheet(BuildContext context, String? currentPath, NavigatorState navigator) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
        ),
        padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 2.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          // Drag handle
          Center(
            child: Container(
              width: 12.w,
              height: 1.w,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(1.w),
              ),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            'plan_settings'.tr(context),
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
          Text(
            'what_would_you_like_to_change'.tr(context),
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF6E6E73)),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),

          if (currentPath == '/build_own') ...[
            _buildOption(
              context,
              icon: Icons.edit_note_rounded,
              title: 'edit_goal_macros'.tr(context),
              subtitle: 'edit_goal_macros_desc'.tr(context),
              color: const Color(0xFF007AFF),
              onTap: () {
                Navigator.pop(context);
                navigator.pushNamedAndRemoveUntil('/build_own', (route) => route.settings.name == '/', arguments: true);
              },
            ),
          ] else if (currentPath == '/templates') ...[
            _buildOption(
              context,
              icon: Icons.list_alt_rounded,
              title: 'change_template'.tr(context),
              subtitle: 'change_template_desc'.tr(context),
              color: const Color(0xFF007AFF),
              onTap: () {
                Navigator.pop(context);
                navigator.popUntil((route) => route.settings.name == '/templates');
              },
            ),
          ] else if (currentPath == '/ai_coach' || currentPath == '/coach_plan') ...[
             _buildOption(
              context,
              icon: Icons.refresh_rounded,
              title: 'request_new_plan'.tr(context),
              subtitle: 'request_new_plan_desc'.tr(context),
              color: const Color(0xFF007AFF),
              onTap: () {
                Navigator.pop(context);
                navigator.popUntil((route) => route.settings.name == currentPath);
              },
            ),
          ],
          
          SizedBox(height: 2.h),
          const Divider(height: 1, color: Color(0xFFF2F2F7)),
          SizedBox(height: 2.h),

          _buildOption(
            context,
            icon: Icons.sync_problem_rounded,
            title: 'change_entire_strategy'.tr(context),
            subtitle: 'change_entire_strategy_desc'.tr(context),
            color: const Color(0xFFFF3B30),
            isDestructive: true,
            onTap: () async {
              // Show confirmation dialog before deleting
              _showConfirmDelete(context, navigator);
            },
          ),
          SizedBox(height: 2.h),
        ],
          ),
        ),
      ),
    );
  }

  static Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3.w),
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFFFFF0F0) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(3.w),
          border: isDestructive ? Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.3)) : null,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: isDestructive ? const Color(0xFFFF3B30).withValues(alpha: 0.1) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1C1C1E))),
                  SizedBox(height: 0.5.h),
                  Text(subtitle, style: TextStyle(fontSize: 12.sp, color: isDestructive ? const Color(0xFFFF3B30).withValues(alpha: 0.8) : const Color(0xFF8E8E93))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDestructive ? const Color(0xFFFF3B30) : const Color(0xFFC7C7CC), size: 20.sp),
          ],
        ),
      ),
    );
  }

  static void _showConfirmDelete(BuildContext context, NavigatorState navigator) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: const Color(0xFFFF3B30), size: 20.sp),
            SizedBox(width: 2.w),
            Text('warning'.tr(context), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFFFF3B30))),
          ],
        ),
        content: Text(
          'changing_strategy_warning'.tr(context),
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF6E6E73), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr(context), style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('nutrition_last_flow_path');
              await prefs.remove('nutrition_active_template_json');
              await prefs.remove('nutrition_plan_start_date');
              await prefs.remove('custom_meal_plan');
              await prefs.remove('ai_coach_plan');
              
              // Find and remove all custom_meal_times_ keys
              final keys = prefs.getKeys().where((k) => k.startsWith('custom_meal_times_')).toList();
              for (String k in keys) {
                await prefs.remove(k);
              }
              
              if (!ctx.mounted) return;
              Navigator.pop(ctx); // pop dialog
              Navigator.pop(context); // pop bottom sheet
              navigator.popUntil((route) => route.settings.name == '/');
            },
            child: Text('change_strategy'.tr(context), style: TextStyle(color: const Color(0xFFFF3B30), fontSize: 14.sp, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
