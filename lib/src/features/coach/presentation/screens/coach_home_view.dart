import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../admin/presentation/views/admin_checkin_view.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/models/user_model.dart';
import '../../data/coach_repository.dart';

class CoachHomeView extends ConsumerStatefulWidget {
  const CoachHomeView({super.key});

  @override
  ConsumerState<CoachHomeView> createState() => _CoachHomeViewState();
}

class _CoachHomeViewState extends ConsumerState<CoachHomeView> {
  final _notificationTitleCtrl = TextEditingController();
  final _notificationBodyCtrl = TextEditingController();
  final _playerSearchCtrl = TextEditingController();
  String? _selectedPlayerUid;
  String _selectedType = 'coach_feedback';
  bool _isSendingNotification = false;
  String _playerSearchQuery = '';

  @override
  void dispose() {
    _notificationTitleCtrl.dispose();
    _notificationBodyCtrl.dispose();
    _playerSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userModel = ref.watch(currentUserModelProvider).asData?.value;
    final firstName = userModel?.firstName ?? 'Coach';
    final gymId = userModel?.gymId ?? 'Your Gym';

    return SafeArea(
      child: Column(
        children: [
          _buildTopbar(context, firstName, gymId),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(firstName, context),
                  _buildCheckinCard(context, userModel),
                  _buildSectionHeader(
                    '⚠ Needs Attention',
                    color: const Color(0xFFFF3B30),
                  ),
                  _buildFirebaseNeedsAttention(context),
                  _buildSectionHeader(
                    'coach_all_my_players'.tr(context),
                    linkText: 'see_all_arrow'.tr(context),
                  ),
                  _buildFirebaseAllPlayers(context),
                  _buildSectionHeader(
                    'coach_quick_notification'.tr(context),
                    linkText: 'history_arrow'.tr(context),
                  ),
                  _buildFirebaseQuickNotification(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopbar(BuildContext context, String firstName, String gymId) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gymId,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Coach $firstName 👨‍💼',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildTopBtn(
                icon: Icons.notifications_none_rounded,
                hasBadge: true,
                onTap: () => context.push('/coach_notifications'),
              ),
              SizedBox(width: 2.w),
              _buildTopBtn(
                icon: Icons.more_horiz_rounded,
                onTap: () => context.push('/profile_settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBtn({
    required IconData icon,
    bool hasBadge = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 16.sp, color: const Color(0xFF1C1C1E)),
            if (hasBadge)
              PositionedDirectional(
                top: 2.w,
                end: 2.5.w,
                child: Container(
                  width: 2.w,
                  height: 2.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF5F5F7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinCard(BuildContext context, UserModel? userModel) {
    final gymId  = userModel?.gymId  ?? '';
    final coachUid = userModel?.uid ?? '';

    final checkinsAsync = ref.watch(todayCheckInsProvider(gymId));
    final allCheckins = checkinsAsync.asData?.value ?? [];

    final coachPlayerUids = (ref.watch(coachMembersProvider).asData?.value ?? [])
        .map((p) => p.uid)
        .toSet();

    final myCheckins = allCheckins
        .where((c) => coachPlayerUids.contains(c['playerUid'] as String? ?? ''))
        .length;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminCheckinView(
            gymId: gymId,
            adminUid: coachUid,
            coachUid: coachUid,
          ),
        ),
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: const Color(0xFF34C759).withOpacity(0.12),
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFF34C759).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.how_to_reg_rounded,
                  color: Color(0xFF34C759), size: 22),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Check-in",
                    style: TextStyle(
                        color: const Color(0xFF1C1C1E),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '$myCheckins of ${coachPlayerUids.length} players checked in',
                    style: TextStyle(
                        color: const Color(0xFF1C1C1E).withOpacity(0.5),
                        fontSize: 11.sp),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF34C759), size: 14.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(String firstName, BuildContext context) {
    final players =
        ref.watch(coachMembersProvider).asData?.value ?? const <UserModel>[];
    final attention = players.where(_needsAttentionPlayer).length;
    final active = players.where((player) => !_isExpiredPlayer(player)).length;

    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF007AFF),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -8.w,
            top: -8.w,
            child: Container(
              width: 25.w,
              height: 25.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'coach_today'.tr(context),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 0.7,
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                'Good morning, $firstName! ☀️',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 0.2.h),
              Text(
                '$attention players need your attention today',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _buildHeroStat(
                      '${players.length}',
                      'coach_my_players'.tr(context),
                    ),
                  ),
                  Expanded(
                    child: _buildHeroStat(
                      '$active',
                      'coach_active'.tr(context),
                    ),
                  ),
                  Expanded(
                    child: _buildHeroStat(
                      '$attention',
                      'coach_attention'.tr(context),
                    ),
                  ),
                ],
              ),
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
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    String title, {
    String? linkText,
    Color color = const Color(0xFF8E8E93),
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          if (linkText != null)
            Text(
              linkText,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF007AFF),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFirebaseNeedsAttention(BuildContext context) {
    final playersAsync = ref.watch(coachMembersProvider);
    return playersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Text('${'error_prefix'.tr(context)} $error'),
      ),
      data: (players) {
        final attention = players.where(_needsAttentionPlayer).take(3).toList();
        if (attention.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
            child: _emptyState('coach_all_clear'.tr(context)),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
          child: Column(
            children: [
              ...attention.map(
                (player) => Padding(
                  padding: EdgeInsets.only(bottom: 1.h),
                  child: _buildFirebasePlayerCard(context, player),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFirebaseAllPlayers(BuildContext context) {
    final playersAsync = ref.watch(coachMembersProvider);
    return playersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Text('${'error_prefix'.tr(context)} $error'),
      ),
      data: (players) {
        if (players.isEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
            child: _emptyState('coach_assigned_will_appear'.tr(context)),
          );
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
          child: Column(
            children: [
              ...players
                  .take(5)
                  .map(
                    (player) => Padding(
                      padding: EdgeInsets.only(bottom: 1.h),
                      child: _buildFirebasePlayerCard(context, player),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFirebasePlayerCard(BuildContext context, UserModel player) {
    final status = _playerStatus(player);
    return _buildPlayerCard(
      context: context,
      avatar: _initials(player),
      bg: status.bg,
      name: _displayName(player),
      meta: _playerMeta(player),
      badge: status.label,
      badgeColor: status.color,
      borderColor: status.color,
      player: player,
    );
  }

  // ignore: unused_element
  Widget _buildNeedsAttention(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
      child: Column(
        children: [
          _buildPlayerCard(
            context: context,
            avatar: '😴',
            bg: const Color(0xFFFFF0F0),
            name: 'Yusuf Ibrahim',
            meta: 'Missed 3 sessions · Nutrition 34%',
            badge: 'Alert 🚨',
            badgeColor: const Color(0xFFFF3B30),
            borderColor: const Color(0xFFFF3B30),
            progressRows: [
              _buildProgressRow('Sessions', 28, '2/7', const Color(0xFFFF3B30)),
              _buildProgressRow(
                'Nutrition',
                34,
                '34%',
                const Color(0xFFFF9500),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          _buildPlayerCard(
            context: context,
            avatar: '🏋️',
            bg: const Color(0xFFFFF8E8),
            name: 'Khalid Nasser',
            meta: 'Subscription expires in 3 days',
            badge: 'Expiring ⚠️',
            badgeColor: const Color(0xFFFF9500),
            borderColor: const Color(0xFFFF9500),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildAllPlayers(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
      child: Column(
        children: [
          _buildPlayerCard(
            context: context,
            avatar: '💪',
            bg: const Color(0xFFE8FFF0),
            name: 'Ahmad Bsharat',
            meta: 'Push Day · Recovery 84% ✓',
            badge: 'On Track ✓',
            badgeColor: const Color(0xFF1A7A30),
            borderColor: const Color(0xFF34C759),
            isOnline: true,
          ),
          SizedBox(height: 1.h),
          _buildPlayerCard(
            context: context,
            avatar: '🏆',
            bg: const Color(0xFFFFF8E8),
            name: 'Omar Al-Rashid',
            meta: 'New PR! Bench 110 kg 🏆',
            badge: 'PR Day 🏆',
            badgeColor: const Color(0xFFB07D10),
            borderColor: const Color(0xFF34C759),
            isOnline: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required BuildContext context,
    required String avatar,
    required Color bg,
    required String name,
    required String meta,
    required String badge,
    required Color badgeColor,
    required Color borderColor,
    bool isOnline = false,
    List<Widget>? progressRows,
    UserModel? player,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.w),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: borderColor, width: 3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4.w),
              onTap: () =>
                  context.push('/coach_player_detail', extra: player ?? name),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(3.w),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 13.w,
                              height: 13.w,
                              decoration: BoxDecoration(
                                color: bg,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: EdgeInsets.all(1.w),
                                  child: Text(
                                    avatar,
                                    style: TextStyle(fontSize: 18.sp),
                                  ),
                                ),
                              ),
                            ),
                            if (isOnline)
                              PositionedDirectional(
                                bottom: 0,
                                end: 0,
                                child: Container(
                                  width: 3.w,
                                  height: 3.w,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34C759),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 2.5.w,
                            vertical: 0.6.h,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(2.w),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (progressRows != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(3.w, 0, 3.w, 3.w),
                      child: Column(children: progressRows),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRow(
    String label,
    double percent,
    String val,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.8.h),
      child: Row(
        children: [
          SizedBox(
            width: 26.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5.h,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(1.w),
              ),
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: percent / 100,
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
          SizedBox(
            width: 14.w,
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirebaseQuickNotification(BuildContext context) {
    final playersAsync = ref.watch(coachMembersProvider);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(3.5.w),
            child: Row(
              children: [
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5FF),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: const Color(0xFF007AFF),
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 3.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'coach_send_to_players'.tr(context),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    Text(
                      'coach_select_players_desc'.tr(context),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F7)),
          Padding(
            padding: EdgeInsets.all(3.5.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotifLabel('coach_recipients'.tr(context)),
                _buildRecipientsSelector(playersAsync, context),
                SizedBox(height: 1.5.h),
                _buildNotifLabel('coach_type'.tr(context)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypePill(
                        'coach_feedback'.tr(context),
                        type: 'coach_feedback',
                      ),
                      _buildTypePill(
                        'coach_plan'.tr(context),
                        type: 'coach_plan',
                      ),
                      _buildTypePill(
                        'coach_reminder'.tr(context),
                        type: 'coach_reminder',
                      ),
                      _buildTypePill(
                        'coach_motivation'.tr(context),
                        type: 'coach_motivation',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 1.5.h),
                TextField(
                  controller: _notificationTitleCtrl,
                  decoration: _inpDeco('coach_title_placeholder'.tr(context)),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 1.h),
                TextField(
                  controller: _notificationBodyCtrl,
                  maxLines: 3,
                  decoration: _inpDeco('coach_message_placeholder'.tr(context)),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 1.5.h),
                ElevatedButton(
                  onPressed: _isSendingNotification
                      ? null
                      : () => _sendQuickNotification(
                          playersAsync.asData?.value ?? const [],
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    minimumSize: Size(double.infinity, 5.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSendingNotification)
                        SizedBox(
                          width: 5.w,
                          height: 5.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      SizedBox(width: 2.w),
                      Flexible(
                        child: Text(
                          _sendButtonText(playersAsync.asData?.value ?? const []),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildQuickNotificationLegacy() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(3.5.w),
            child: Row(
              children: [
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5FF),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  alignment: Alignment.center,
                  child: Text('🔔', style: TextStyle(fontSize: 18.sp)),
                ),
                SizedBox(width: 3.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'coach_send_to_players'.tr(context),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    Text(
                      'Select players → write → send',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF5F5F7)),
          Padding(
            padding: EdgeInsets.all(3.5.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildNotifLabel('coach_recipients'.tr(context)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip(
                        'Ahmad',
                        '💪',
                        const Color(0xFFE8FFF0),
                        isSelected: true,
                      ),
                      _buildChip('Sara', '🌟', const Color(0xFFF0EEFF)),
                      _buildChip('Omar', '🏋️', const Color(0xFFFFF8E8)),
                      _buildChip(
                        'All 8',
                        '',
                        const Color(0xFFE8F5FF),
                        color: const Color(0xFF007AFF),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 1.5.h),
                _buildNotifLabel('coach_type'.tr(context)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTypePill('💬 Feedback', isSelected: true),
                      _buildTypePill('✅ Plan'),
                      _buildTypePill('⚠️ Reminder'),
                      _buildTypePill('🏆 Motivation'),
                    ],
                  ),
                ),
                SizedBox(height: 1.5.h),
                TextField(
                  decoration: _inpDeco('coach_title_placeholder'.tr(context)),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 1.h),
                TextField(
                  maxLines: 3,
                  decoration: _inpDeco('coach_message_placeholder'.tr(context)),
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 1.5.h),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    minimumSize: Size(double.infinity, 5.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'send_to_player'
                            .tr(context)
                            .replaceAll('{name}', 'Ahmad'),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientsSelector(
    AsyncValue<List<UserModel>> playersAsync,
    BuildContext context,
  ) {
    return playersAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (err, stack) => Text(
        'Could not load players: $err',
        style: TextStyle(fontSize: 12.sp, color: Colors.red),
      ),
      data: (players) {
        if (players.isEmpty) {
          return Text(
            'add_players_first_notifications'.tr(context),
            style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
          );
        }

        final selectedUid = _selectedPlayerUid;
        final effectiveSelection = selectedUid ?? players.first.uid;
        _selectedPlayerUid ??= effectiveSelection;

        // Filter by search query
        final query = _playerSearchQuery.toLowerCase().trim();
        final filtered = query.isEmpty
            ? players
            : players
                .where((p) => _playerName(p).toLowerCase().contains(query))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search field ──────────────────────────────────────────────
            TextField(
              controller: _playerSearchCtrl,
              onChanged: (v) => setState(() => _playerSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'search_player'.tr(context),
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF8E8E93),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18.sp,
                  color: const Color(0xFF8E8E93),
                ),
                suffixIcon: _playerSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16.sp,
                          color: const Color(0xFF8E8E93),
                        ),
                        onPressed: () {
                          _playerSearchCtrl.clear();
                          setState(() => _playerSearchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 1.2.h,
                  horizontal: 3.w,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.5.w),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            SizedBox(height: 1.2.h),

            // ── Player chips (filtered) ───────────────────────────────────
            if (filtered.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 1.h),
                child: Text(
                  '${'no_results_found_for'.tr(context)} "$_playerSearchQuery"',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...filtered.map(
                      (player) => GestureDetector(
                        onTap: () =>
                            setState(() => _selectedPlayerUid = player.uid),
                        child: _buildChip(
                          _playerName(player),
                          'P',
                          const Color(0xFFE8FFF0),
                          isSelected: effectiveSelection == player.uid,
                        ),
                      ),
                    ),
                    // "All" chip only when no active search filter
                    if (query.isEmpty)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _selectedPlayerUid = 'all'),
                        child: _buildChip(
                          'All ${players.length}',
                          '',
                          const Color(0xFFE8F5FF),
                          isSelected: effectiveSelection == 'all',
                          color: const Color(0xFF007AFF),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotifLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.8.h),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8E8E93),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildChip(
    String label,
    String avatar,
    Color bg, {
    bool isSelected = false,
    Color color = const Color(0xFF3A3A3C),
  }) {
    return Container(
      margin: EdgeInsetsDirectional.only(end: 2.w),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(5.w),
        border: Border.all(
          color: isSelected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          if (avatar.isNotEmpty)
            Container(
              width: 6.w,
              height: 6.w,
              margin: EdgeInsetsDirectional.only(end: 2.w),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(avatar, style: TextStyle(fontSize: 16.sp)),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill(String label, {String? type, bool isSelected = false}) {
    final effectiveType = type ?? label.toLowerCase();
    final selected = type == null ? isSelected : _selectedType == effectiveType;
    return GestureDetector(
      onTap: type == null
          ? null
          : () => setState(() => _selectedType = effectiveType),
      child: Container(
        margin: EdgeInsetsDirectional.only(end: 1.5.w),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(5.w),
          border: Border.all(
            color: selected ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Future<void> _sendQuickNotification(List<UserModel> players) async {
    final title = _notificationTitleCtrl.text.trim();
    final body = _notificationBodyCtrl.text.trim();
    if (players.isEmpty) {
      _showSnack('Add players first.');
      return;
    }
    if (title.isEmpty || body.isEmpty) {
      _showSnack('Write a title and message.');
      return;
    }

    final targets = _selectedPlayerUid == 'all'
        ? players
        : players
              .where(
                (player) =>
                    player.uid == (_selectedPlayerUid ?? players.first.uid),
              )
              .toList();
    if (targets.isEmpty) {
      _showSnack('Select a player.');
      return;
    }

    setState(() => _isSendingNotification = true);
    try {
      await ref
          .read(coachRepositoryProvider)
          .sendQuickNotification(
            targets: targets,
            title: title,
            body: body,
            type: _selectedType,
          );
      _notificationTitleCtrl.clear();
      _notificationBodyCtrl.clear();
      _showSnack('Notification sent.');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSendingNotification = false);
    }
  }

  String _sendButtonText(List<UserModel> players) {
    if (_isSendingNotification) return 'Sending...';
    if (players.isEmpty) return 'No Players';
    if (_selectedPlayerUid == 'all') return 'Send to All ${players.length}';
    final selected = players.firstWhere(
      (player) => player.uid == (_selectedPlayerUid ?? players.first.uid),
      orElse: () => players.first,
    );
    return 'Send to ${_playerName(selected)}';
  }

  String _playerName(UserModel player) {
    final name = [player.firstName, player.lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .join(' ');
    if (name.isNotEmpty) return name;
    return player.email.split('@').first;
  }

  Widget _emptyState(String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
      ),
    );
  }

  String _displayName(UserModel player) => _playerName(player);

  String _initials(UserModel player) {
    final first = (player.firstName ?? player.email).trim();
    final last = (player.lastName ?? '').trim();
    return '${first.isEmpty ? 'P' : first[0]}${last.isEmpty ? '' : last[0]}'
        .toUpperCase();
  }

  String _playerMeta(UserModel player) {
    final goal = _label(player.goal ?? 'get_fit');
    final weight = player.weight == null
        ? '-'
        : '${player.weight!.toStringAsFixed(0)} kg';
    final height = player.height == null
        ? '-'
        : '${player.height!.toStringAsFixed(0)} cm';
    return '$goal · $weight · $height';
  }

  String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  bool _isExpiredPlayer(UserModel player) {
    final end = player.subscriptionEnd;
    return end != null && end.isBefore(DateTime.now());
  }

  bool _needsAttentionPlayer(UserModel player) {
    final remaining = player.amountRemaining ?? 0;
    final end = player.subscriptionEnd;
    final expiring = end != null && end.difference(DateTime.now()).inDays <= 7;
    return remaining > 0 || expiring;
  }

  _HomePlayerStatus _playerStatus(UserModel player) {
    final remaining = player.amountRemaining ?? 0;
    final end = player.subscriptionEnd;
    if (remaining > 0) {
      return const _HomePlayerStatus(
        'Payment',
        Color(0xFFE53935),
        Color(0xFFFFF0F0),
      );
    }
    if (end != null && end.isBefore(DateTime.now())) {
      return const _HomePlayerStatus(
        'Expired',
        Color(0xFFE53935),
        Color(0xFFFFF0F0),
      );
    }
    if (end != null && end.difference(DateTime.now()).inDays <= 7) {
      return const _HomePlayerStatus(
        'Expiring',
        Color(0xFFFF9500),
        Color(0xFFFFF8E8),
      );
    }
    return _HomePlayerStatus(
      'coach_active'.tr(context),
      const Color(0xFF1A7A30),
      const Color(0xFFE8FFF0),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _inpDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFC7C7CC)),
      filled: true,
      fillColor: const Color(0xFFF9F9FB),
      contentPadding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.5.h),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3.w),
        borderSide: const BorderSide(color: Color(0xFFE5E5EA), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3.w),
        borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
      ),
    );
  }
}

class _HomePlayerStatus {
  final String label;
  final Color color;
  final Color bg;

  const _HomePlayerStatus(this.label, this.color, this.bg);
}
