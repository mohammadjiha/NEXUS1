import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../features/coaching/presentation/screens/ai_coach_chat_screen.dart';
import '../../../../features/coaching/presentation/screens/ai_coach_live_screen.dart';
import '../../../../features/coaching/presentation/screens/human_coach_chat_screen.dart';
import '../../../../features/gym/presentation/screens/exercises_screen.dart';
import '../../../../features/nutrition/presentation/screens/ai_food_scanner_screen.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../auth/data/auth_repository.dart';

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.only(start: 5.w, end: 5.w, top: 4.h, bottom: 15.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'the_hub'.tr(context),
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                  letterSpacing: -1,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                'hub_subtitle'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.h),
              
              // AI TOOLS SECTION
              _buildSectionTitle('ai_tools'.tr(context)),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    child: _buildHubCard(
                      context,
                      title: 'food_scanner'.tr(context),
                      subtitle: 'food_scanner_desc'.tr(context),
                      icon: Icons.document_scanner_rounded,
                      color: const Color(0xFF007AFF),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIFoodScannerScreen())),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: _buildHubCard(
                      context,
                      title: 'form_coach'.tr(context),
                      subtitle: 'form_coach_desc'.tr(context),
                      icon: Icons.camera_front_rounded,
                      color: const Color(0xFF34C759),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AICoachLiveScreen())),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 3.w),
              _buildHubCard(
                context,
                title: 'ai_chat_assistant'.tr(context),
                subtitle: 'ai_chat_assistant_desc'.tr(context),
                icon: Icons.smart_toy_rounded,
                color: const Color(0xFF8E2DE2),
                isWide: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiCoachChatScreen())),
              ),
              
              SizedBox(height: 4.h),

              // ACCOUNT & SHOP SECTION
              _buildSectionTitle('lifestyle'.tr(context)),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Expanded(
                    child: _buildHubCard(
                      context,
                      title: 'my_profile'.tr(context),
                      subtitle: 'my_profile_desc'.tr(context),
                      icon: Icons.person_rounded,
                      color: const Color(0xFF1C1C1E),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: _buildHubCard(
                      context,
                      title: 'nexus_shop'.tr(context),
                      subtitle: 'nexus_shop_desc'.tr(context),
                      icon: Icons.shopping_bag_rounded,
                      color: const Color(0xFFFF9500),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('shop_coming_soon'.tr(context)),
                            backgroundColor: const Color(0xFF1C1C1E),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 3.w),
              _buildHubCard(
                context,
                title: 'exercises_label'.tr(context),
                subtitle: 'search_exercises'.tr(context),
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFF5AC8FA),
                isWide: true,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExercisesScreen())),
              ),
              
              SizedBox(height: 4.h),

              // SUPPORT
              _buildSectionTitle('support'.tr(context)),
              SizedBox(height: 2.h),
              _buildHubCard(
                context,
                title: 'human_coach'.tr(context),
                subtitle: 'human_coach_desc'.tr(context),
                icon: Icons.support_agent_rounded,
                color: const Color(0xFFFF2D55),
                isWide: true,
                onTap: () {
                  final currentUser = ref.read(currentUserModelProvider).value;
                  if (currentUser != null && currentUser.assignedCoachUid != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => HumanCoachChatScreen(
                      chatId: '${currentUser.uid.trim()}_${currentUser.assignedCoachUid!.trim()}',
                      participantName: currentUser.assignedCoachName ?? 'Coach',
                    )));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF8E8E93),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isWide = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isWide ? 5.w : 4.5.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.5.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isWide 
            ? Row(
                children: [
                  Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22.sp),
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        SizedBox(height: 0.3.h),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            color: const Color(0xFF8E8E93),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: const Color(0xFFC7C7CC), size: 22.sp),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22.sp),
                  ),
                  SizedBox(height: 2.5.h),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.5.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF8E8E93),
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }
}
