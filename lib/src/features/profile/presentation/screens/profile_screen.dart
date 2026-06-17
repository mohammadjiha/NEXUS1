import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../coaching/presentation/screens/human_coach_chat_screen.dart';
import '../../providers/body_metrics_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/inbody_ai_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeroSection(context, ref),
                    SizedBox(height: 1.5.h),
                    _buildSegmentTabs(ref),
                    SizedBox(height: 1.5.h),
                    _buildTabContent(context, ref),
                    SizedBox(height: 12.h), // padding for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.5.h),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14.sp,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          Text(
            'nav_profile'.tr(context),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/profile_settings'),
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Icon(
                Icons.settings_outlined,
                size: 16.sp,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(profileUserProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) =>
          Center(child: Text('${'error_loading_profile'.tr(context)}: $e')),
      data: (user) {
        return Container(
          color: Colors.white,
          padding: EdgeInsets.only(bottom: 2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image
              Container(
                width: double.infinity,
                height: 10.h,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1C1C1E),
                      Color(0xFF2C2C2E),
                      Color(0xFF1C1C1E),
                    ],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                ),
                // We can add a pattern here if we want using CustomPaint, but keeping it simple gradient for now
              ),
              // Avatar and Info
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.8.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -3.h),
                      child: Stack(
                        children: [
                          Container(
                            width: 20.w,
                            height: 20.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              image:
                                  (user['photoUrl'] as String?)?.isNotEmpty ??
                                      false
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        user['photoUrl'] as String,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child:
                                (user['photoUrl'] as String?)?.isNotEmpty ??
                                    false
                                ? null
                                : Text(
                                    user['initials'] as String,
                                    style: TextStyle(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          PositionedDirectional(
                            bottom: 4,
                            end: 0,
                            child: Container(
                              width: 4.w,
                              height: 4.w,
                              decoration: BoxDecoration(
                                color: const Color(0xFF34C759),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.translate(
                      offset: Offset(0, -2.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['name'] as String,
                            style: TextStyle(
                              fontSize: 23.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 0.2.h),
                          Text(
                            '${user['handle']} · ${user['gym']}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            user['bio'] as String,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF3A3A3C),
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 1.5.h),
                          Wrap(
                            spacing: 2.w,
                            runSpacing: 1.h,
                            children: (user['tags'] as List)
                                .cast<Map<String, Object>>()
                                .map<Widget>((tag) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 3.w,
                                      vertical: 0.5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(tag['bg'] as int),
                                      borderRadius: BorderRadius.circular(3.w),
                                    ),
                                    child: Text(
                                      tag['name'] as String,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Color(tag['color'] as int),
                                      ),
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      context.push('/profile_settings'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1C1C1E),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 1.5.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(3.w),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'edit_profile'.tr(context),
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 2.w),
                              if (user['role'] == 'coach' ||
                                  user['role'] == 'admin' ||
                                  user['role'] == 'owner' ||
                                  user['role'] == 'gym_admin')
                                GestureDetector(
                                  onTap: () =>
                                      context.push('/members_management'),
                                  child: Container(
                                    width: 12.w,
                                    height: 12.w,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF007AFF,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3.w),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF007AFF,
                                        ).withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.people_alt_rounded,
                                      color: const Color(0xFF005BB5),
                                      size: 20.sp,
                                    ),
                                  ),
                                ),
                              if (user['role'] == 'coach' ||
                                  user['role'] == 'admin' ||
                                  user['role'] == 'owner' ||
                                  user['role'] == 'gym_admin')
                                SizedBox(width: 2.w),
                              GestureDetector(
                                onTap: () => _handleRenewTap(context, user),
                                child: Container(
                                  width: 12.w,
                                  height: 12.w,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(3.w),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFFD700,
                                      ).withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.workspace_premium_rounded,
                                    color: const Color(0xFFB8860B),
                                    size: 20.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 2.w),
                              GestureDetector(
                                onTap: () => context.push('/profile_settings'),
                                child: _buildIconButton(
                                  Icons.settings_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stats Row
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFF0F0F5)),
                    bottom: BorderSide(color: Color(0xFFF0F0F5)),
                  ),
                ),
                child: Row(
                  children: [
                    _buildStatItem(user['workouts'] as String, 'Workouts'),
                    _buildDivider(),
                    _buildStatItem(user['streak'] as String, 'Streak'),
                    _buildDivider(),
                    _buildStatItem(
                      user['progress'] as String,
                      'Progress',
                      valColor: const Color(0xFF34C759),
                    ),
                    _buildDivider(),
                    _buildStatItem(user['thisWeek'] as String, 'This Week'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleRenewTap(BuildContext context, Map<String, dynamic> user) {
    final coachUid = (user['assignedCoachUid'] as String?)?.trim();
    final playerUid = (user['uid'] as String?)?.trim();
    final gymId = (user['gymId'] as String?)?.trim();

    if (coachUid != null &&
        coachUid.isNotEmpty &&
        playerUid != null &&
        playerUid.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HumanCoachChatScreen(
            chatId: '${playerUid}_$coachUid',
            participantName:
                (user['assignedCoachName'] as String?)?.trim().isNotEmpty ??
                    false
                ? (user['assignedCoachName'] as String).trim()
                : 'dash_assigned_coach'.tr(context),
          ),
        ),
      );
      return;
    }

    if (gymId != null && gymId.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('renew_contact_gym'.tr(context))));
      return;
    }

    context.push('/payment');
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      width: 12.w,
      height: 12.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Icon(icon, color: const Color(0xFF3A3A3C), size: 18.sp),
    );
  }

  Widget _buildStatItem(String val, String lbl, {Color? valColor}) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 1.w),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                val,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: valColor ?? const Color(0xFF1C1C1E),
                ),
              ),
            ),
            SizedBox(height: 0.3.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                lbl.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8E8E93),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 5.h, color: const Color(0xFFF0F0F5));
  }

  Widget _buildSegmentTabs(WidgetRef ref) {
    final currentTab = ref.watch(profileTabProvider);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.8.w),
      padding: EdgeInsets.all(0.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        children: [
          _buildTabItem(ref, 'Overview', ProfileTab.overview, currentTab),
          _buildTabItem(ref, 'Stats', ProfileTab.stats, currentTab),
          _buildTabItem(ref, 'Records', ProfileTab.records, currentTab),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    WidgetRef ref,
    String label,
    ProfileTab tab,
    ProfileTab currentTab,
  ) {
    final isSelected = currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(profileTabProvider.notifier).setTab(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(vertical: 1.2.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(2.5.w),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(profileTabProvider);
    switch (currentTab) {
      case ProfileTab.overview:
        return _buildOverviewTab(context, ref);
      case ProfileTab.stats:
        return _buildStatsTab(context, ref);
      case ProfileTab.records:
        return _buildRecordsTab(context, ref);
    }
  }

  Widget _buildOverviewTab(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(profileMetricsUiProvider);
    return Column(
      children: [
        _buildSection(
          title: 'body_metrics'.tr(context),
          actionText: 'update'.tr(context),
          onActionTap: () => _showUpdateMetricsBottomSheet(context, ref),
          child: Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.2,
                ),
                itemCount: metrics.length,
                itemBuilder: (ctx, idx) {
                  final m = metrics[idx];
                  final isRightEdge = (idx + 1) % 3 == 0;
                  final isBottomEdge = idx >= metrics.length - 3;
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: isRightEdge
                            ? BorderSide.none
                            : const BorderSide(color: Color(0xFFF0F0F5)),
                        bottom: isBottomEdge
                            ? BorderSide.none
                            : const BorderSide(color: Color(0xFFF0F0F5)),
                      ),
                    ),
                    padding: EdgeInsets.all(2.5.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: m['val'] as String,
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              TextSpan(
                                text: m['unit'] as String,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 0.3.h),
                        Text(
                          m['label'] as String,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          m['trend'] as String,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: m['isNeutral'] as bool
                                ? const Color(0xFF8E8E93)
                                : (m['isUp'] as bool
                                      ? const Color(0xFF34C759)
                                      : const Color(0xFFFF3B30)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard(String month, String change, Color bg) {
    return Container(
      width: 20.w,
      height: 26.w,
      margin: EdgeInsetsDirectional.only(end: 2.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Stack(
        children: [
          Align(
            child: Icon(
              Icons.person,
              color: Colors.white.withValues(alpha: 0.15),
              size: 18.w,
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            start: 0,
            end: 0,
            child: Container(
              padding: EdgeInsets.all(1.5.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    month,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    change,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF34C759),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhotoCard() {
    return Container(
      width: 20.w,
      height: 26.w,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(
          color: const Color(0xFFD1D1D6),
        ), // Dashboard dash pattern requires custom painter
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(1.5.w),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: Icon(
              Icons.add_rounded,
              color: const Color(0xFF8E8E93),
              size: 16.sp,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Add Photo',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(
    String emoji,
    String title,
    Color bg, {
    bool locked = false,
  }) {
    return Container(
      width: 18.w,
      margin: EdgeInsetsDirectional.only(end: 2.w),
      child: Opacity(
        opacity: locked ? 0.4 : 1.0,
        child: Column(
          children: [
            Container(
              width: 14.w,
              height: 14.w,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(4.w),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: TextStyle(fontSize: 22.sp)),
            ),
            SizedBox(height: 1.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF3A3A3C),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(BuildContext context, WidgetRef ref) {
    final freq = ref.watch(muscleFreqProvider);
    final volume = ref.watch(monthlyVolumeProvider);
    final activity = ref.watch(weeklyActivityProvider);

    return Column(
      children: [
        _buildSection(
          title: 'weekly_activity'.tr(context),
          actionText: 'current_week'.tr(context),
          child: Padding(
            padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActivityBar(
                  'S',
                  activity[5],
                  const Color(0xFF1C1C1E),
                  isToday: DateTime.now().weekday == 6,
                ),
                _buildActivityBar(
                  'S',
                  activity[6],
                  const Color(0xFF1C1C1E),
                  isToday: DateTime.now().weekday == 7,
                ),
                _buildActivityBar(
                  'M',
                  activity[0],
                  const Color(0xFF1C1C1E),
                  isToday: DateTime.now().weekday == 1,
                ),
                _buildActivityBar(
                  'T',
                  activity[1],
                  const Color(0xFF1C1C1E),
                  isToday: DateTime.now().weekday == 2,
                ),
                _buildActivityBar(
                  'W',
                  activity[2],
                  const Color(0xFF1C1C1E),
                  isToday: DateTime.now().weekday == 3,
                ),
                _buildActivityBar(
                  'T',
                  activity[3],
                  const Color(0xFF1C1C1E),
                  isToday: DateTime.now().weekday == 4,
                ),
                _buildActivityBar(
                  'F',
                  activity[4],
                  const Color(0xFF1C1C1E),
                  isToday: DateTime.now().weekday == 5,
                ),
              ],
            ),
          ),
        ),
        _buildSection(
          title: 'last_30_days_volume'.tr(context),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              _buildVolGridItem(
                volume['sessions'] as String,
                'sessions'.tr(context),
                '',
              ),
              _buildVolGridItem(
                volume['totalSets'] as String,
                'total_sets'.tr(context),
                '',
              ),
              _buildVolGridItem(
                volume['gymTime'] as String,
                'gym_time'.tr(context),
                '',
              ),
            ],
          ),
        ),
        _buildSection(
          title: 'muscle_frequency'.tr(context),
          actionText: 'last_7_days'.tr(context),
          child: Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
            child: freq.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Text(
                        'no_data_yet'.tr(context),
                        style: const TextStyle(color: Color(0xFF8E8E93)),
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final maxSets = freq.fold<int>(
                        18,
                        (max, m) =>
                            (m['sets'] as int) > max ? (m['sets'] as int) : max,
                      );
                      return Column(
                        children: freq.map((m) {
                          final double percent = ((m['sets'] as int) / maxSets)
                              .clamp(0.0, 1.0);
                          return Padding(
                            padding: EdgeInsets.only(bottom: 1.h),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20.w,
                                  child: Text(
                                    m['name'] as String,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF3A3A3C),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 0.8.h,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F0F5),
                                      borderRadius: BorderRadius.circular(1.w),
                                    ),
                                    alignment: AlignmentDirectional.centerStart,
                                    child: FractionallySizedBox(
                                      widthFactor: percent,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Color(m['color'] as int),
                                          borderRadius: BorderRadius.circular(
                                            1.w,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 3.w),
                                SizedBox(
                                  width: 8.w,
                                  child: Text(
                                    '${m['sets']}',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF3A3A3C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolGridItem(
    String val,
    String lbl,
    String trend, {
    bool neutral = false,
    double? valSize,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFF0F0F5)),
          bottom: BorderSide(color: Color(0xFFF0F0F5)),
        ),
      ),
      padding: EdgeInsets.all(2.5.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: valSize ?? 20.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 0.3.h),
          Text(
            lbl,
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
          ),
          SizedBox(height: 0.5.h),
          Text(
            trend,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: neutral
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF34C759),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBar(
    String day,
    int val,
    Color color, {
    bool isToday = false,
  }) {
    const maxVal = 20; // assumed max sets per day for scaling
    final heightFactor = (val / maxVal).clamp(0.0, 1.0);
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 10.h,
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFactor > 0 ? heightFactor : 0.05,
              child: Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 0.5.w),
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF007AFF)
                      : color.withValues(alpha: val == 0 ? 0.2 : 1.0),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(1.w),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            day,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
              color: isToday
                  ? const Color(0xFF1C1C1E)
                  : const Color(0xFFC7C7CC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTab(BuildContext context, WidgetRef ref) {
    final records = ref.watch(profileRecordsProvider);
    return _buildSection(
      title: 'personal_records'.tr(context),
      actionText: 'all_arrow'.tr(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
        child: records.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Text(
                    'no_records_yet_go_lift'.tr(context),
                    style: const TextStyle(color: Color(0xFF8E8E93)),
                  ),
                ),
              )
            : Column(
                children: records.map((r) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 1.h),
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9FB),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7.w,
                          height: 7.w,
                          decoration: BoxDecoration(
                            color: Color(r['rankBg'] as int),
                            borderRadius: BorderRadius.circular(2.w),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            r['rank'] as String,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              color: Color(r['rankColor'] as int),
                            ),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['name'] as String,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              SizedBox(height: 0.2.h),
                              Text(
                                r['date'] as String,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: const Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              r['val'] as String,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1C1C1E),
                              ),
                            ),
                            SizedBox(height: 0.3.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 2.w,
                                vertical: 0.3.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8FFF0),
                                borderRadius: BorderRadius.circular(1.5.w),
                              ),
                              child: Text(
                                r['badge'] as String,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A7A30),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    String? actionText,
    VoidCallback? onActionTap,
    required Widget child,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                if (actionText != null)
                  GestureDetector(
                    onTap: onActionTap,
                    child: Text(
                      actionText,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  void _showUpdateMetricsBottomSheet(BuildContext context, WidgetRef ref) {
    final currentMetrics = ref.read(bodyMetricsProvider).value ?? BodyMetrics();
    final weightCtrl = TextEditingController(
      text: currentMetrics.weight.toString(),
    );
    final heightCtrl = TextEditingController(
      text: currentMetrics.height.toString(),
    );
    final fatCtrl = TextEditingController(
      text: currentMetrics.bodyFat.toString(),
    );
    final muscleCtrl = TextEditingController(
      text: currentMetrics.muscleMass.toString(),
    );
    final waistCtrl = TextEditingController(
      text: currentMetrics.waist.toString(),
    );

    // New Fields
    final fatFreeMassCtrl = TextEditingController(
      text: currentMetrics.fatFreeMass.toString(),
    );
    final waterCtrl = TextEditingController(
      text: currentMetrics.water.toString(),
    );
    final bmrCtrl = TextEditingController(text: currentMetrics.bmr.toString());
    final visceralFatCtrl = TextEditingController(
      text: currentMetrics.visceralFat.toString(),
    );
    final metabolicAgeCtrl = TextEditingController(
      text: currentMetrics.metabolicAge.toString(),
    );
    bool isAnalyzing = false;
    String errorMsg = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> handlePickAndScan() async {
              setState(() {
                isAnalyzing = true;
                errorMsg = '';
              });

              try {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: [
                    'jpg',
                    'jpeg',
                    'png',
                    'webp',
                    'pdf',
                    'doc',
                    'docx',
                  ],
                  withData: true,
                );

                final image = result?.files.single;
                if (image != null) {
                  final bytes = image.bytes;
                  if (bytes == null || bytes.isEmpty) {
                    throw Exception('Selected file is empty or cannot be read');
                  }

                  final aiService = ref.read(inbodyAiServiceProvider);
                  final mime = aiService.mimeTypeFor(image.name);

                  final data = await aiService.parseInBodyFile(
                    fileBytes: bytes,
                    mimeType: mime,
                  );

                  setState(() {
                    weightCtrl.text = data['weight'].toString();
                    heightCtrl.text = data['height'].toString();
                    fatCtrl.text = data['bodyFat'].toString();
                    muscleCtrl.text = data['muscleMass'].toString();
                    fatFreeMassCtrl.text = data['fatFreeMass'].toString();
                    waterCtrl.text = data['water'].toString();
                    bmrCtrl.text = data['bmr'].toString();
                    visceralFatCtrl.text = data['visceralFat'].toString();
                    metabolicAgeCtrl.text = data['metabolicAge'].toString();
                  });

                  await ref
                      .read(bodyMetricsProvider.notifier)
                      .updateMetrics(
                        weight: _toDouble(data['weight']),
                        height: _toDouble(data['height']),
                        bodyFat: _toDouble(data['bodyFat']),
                        muscleMass: _toDouble(data['muscleMass']),
                        fatFreeMass: _toDouble(data['fatFreeMass']),
                        water: _toDouble(data['water']),
                        bmr: _toDouble(data['bmr']),
                        visceralFat: _toDouble(data['visceralFat']),
                        metabolicAge: _toDouble(data['metabolicAge']),
                      );
                }
              } catch (e) {
                setState(() => errorMsg = e.toString());
              } finally {
                setState(() => isAnalyzing = false);
              }
            }

            return Container(
              height: 90.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
              ),
              padding: EdgeInsets.fromLTRB(
                5.w,
                2.h,
                5.w,
                MediaQuery.of(ctx).viewInsets.bottom + 2.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 12.w,
                      height: 0.6.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(1.w),
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'update_body_metrics'.tr(context),
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 3.h),

                  // InBody Scan Button
                  GestureDetector(
                    onTap: isAnalyzing ? null : handlePickAndScan,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 2.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                        ),
                        borderRadius: BorderRadius.circular(3.w),
                      ),
                      child: isAnalyzing
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.document_scanner_rounded,
                                  color: Colors.white,
                                  size: 18.sp,
                                ),
                                SizedBox(width: 2.w),
                                Text(
                                  'scan_inbody_file_ai'.tr(context),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Center(
                    child: Text(
                      'extracts_scan_file_desc'.tr(context),
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                  if (errorMsg.isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    Text(
                      errorMsg,
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: 3.h),

                  // Manual Inputs
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput('Weight (kg)', weightCtrl),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: _buildInput('Height (cm)', heightCtrl),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput('Body Fat (%)', fatCtrl),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: _buildInput('Muscle (kg)', muscleCtrl),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput(
                                  'Fat Free (kg)',
                                  fatFreeMassCtrl,
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: _buildInput('Water (kg)', waterCtrl),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput('BMR (kcal)', bmrCtrl),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: _buildInput(
                                  'Visceral Fat',
                                  visceralFatCtrl,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInput(
                                  'Metabolic Age',
                                  metabolicAgeCtrl,
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: _buildInput('Waist (cm)', waistCtrl),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                        ],
                      ),
                    ),
                  ),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final weight = double.tryParse(weightCtrl.text.trim());
                        final height = double.tryParse(heightCtrl.text.trim());
                        final bodyFat = double.tryParse(fatCtrl.text.trim());
                        final muscleMass = double.tryParse(
                          muscleCtrl.text.trim(),
                        );

                        if (weight == null ||
                            weight <= 0 ||
                            height == null ||
                            height <= 0 ||
                            bodyFat == null ||
                            bodyFat <= 0 ||
                            muscleMass == null ||
                            muscleMass <= 0) {
                          setState(() {
                            errorMsg =
                                'Please fill weight, height, body fat, and muscle mass.';
                          });
                          return;
                        }

                        final newMetrics = ref.read(
                          bodyMetricsProvider.notifier,
                        );
                        await newMetrics.updateMetrics(
                          weight: weight,
                          height: height,
                          bodyFat: bodyFat,
                          muscleMass: muscleMass,
                          waist: double.tryParse(waistCtrl.text.trim()),
                          bmr: double.tryParse(bmrCtrl.text.trim()),
                          visceralFat: double.tryParse(visceralFatCtrl.text),
                          fatFreeMass: double.tryParse(
                            fatFreeMassCtrl.text.trim(),
                          ),
                          water: double.tryParse(waterCtrl.text.trim()),
                          metabolicAge: double.tryParse(
                            metabolicAgeCtrl.text.trim(),
                          ),
                        );
                        if (context.mounted) context.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        padding: EdgeInsets.symmetric(vertical: 1.8.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'save_changes'.tr(context),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8E8E93),
          ),
        ),
        SizedBox(height: 0.8.h),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF5F5F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3.w),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 1.8.h,
            ),
          ),
        ),
      ],
    );
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
