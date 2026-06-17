import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/intl_formatter.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../coaching/presentation/screens/human_coach_chat_screen.dart';
import '../../../smart_workout/providers/split_setup_provider.dart';
import '../../../user/models/user_model.dart';
import '../../data/coach_repository.dart';
import '../../models/payment_record.dart';
import '../../providers/coach_player_plan_provider.dart';

class CoachPlayerDetailScreen extends ConsumerStatefulWidget {
  final UserModel? player;
  final String? playerName;

  const CoachPlayerDetailScreen({super.key, this.player, this.playerName});

  @override
  ConsumerState<CoachPlayerDetailScreen> createState() =>
      _CoachPlayerDetailScreenState();
}

class _CoachPlayerDetailScreenState
    extends ConsumerState<CoachPlayerDetailScreen> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final player = _currentPlayer();
    if (player == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(player),
            Expanded(
              child: SingleChildScrollView(child: _buildCurrentTab(player)),
            ),
          ],
        ),
      ),
    );
  }

  UserModel? _currentPlayer() {
    if (widget.player != null) return widget.player;
    final players = ref.watch(coachMembersProvider).asData?.value ?? [];
    try {
      return players.firstWhere(
        (p) => '${p.firstName} ${p.lastName}'.trim() == widget.playerName,
      );
    } catch (e) {
      return null;
    }
  }

  String _displayName(UserModel player) {
    return '${player.firstName ?? ''} ${player.lastName ?? ''}'.trim();
  }

  String _formatDob(DateTime? date) {
    if (date == null) return 'unknown'.tr(context);
    return AppIntl.shortDateYear(context, date);
  }

  String _formatLastLogin(DateTime? date) {
    if (date == null) return 'never'.tr(context);
    return AppIntl.fullDateTime(context, date);
  }

  Widget _buildTopbar(UserModel player) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(Icons.arrow_back_ios_new_rounded, () => context.pop()),
          Expanded(
            child: Column(
              children: [
                Text(
                  _tabTitle(),
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 11.w),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 11.w,
        height: 11.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 19.sp, color: const Color(0xFF1C1C1E)),
      ),
    );
  }

  String _tabTitle() {
    switch (_currentTab) {
      case 0:
        return 'Player Profile';
      case 1:
        return 'Training Plan';
      case 2:
        return 'Body & Vitals';
      case 3:
        return 'Activity History';
      case 4:
        return 'Finance';
      default:
        return 'Player';
    }
  }

  Widget _buildCurrentTab(UserModel player) {
    switch (_currentTab) {
      case 0:
        return _buildOverviewTab(player);
      case 1:
        return _buildTrainingTab(player, context);
      case 2:
        return _buildBodyTab(player, context);
      case 3:
        return _buildHistoryTab(player, context);
      case 4:
        return _buildFinanceTab(player, context);
      default:
        return const SizedBox();
    }
  }

  Widget _buildOverviewTab(UserModel player) {
    return Column(
      children: [
        _buildHeroSection(player),
        _buildQuickActions(player),
        _buildPersonalInfoCard(player, context),
        _buildAccountInfoCard(player, context),
        SizedBox(height: 4.h),
      ],
    );
  }

  Widget _buildHeroSection(UserModel player) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF242A32),
        borderRadius: BorderRadius.circular(6.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 18.w,
                height: 18.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF333942),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('💪', style: TextStyle(fontSize: 28.sp)),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(player),
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'ID: #${player.uid.substring(0, 4).toUpperCase()} · Member since ${DateFormat('d MMM yyyy').format(player.subscriptionStart ?? player.createdAt)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: [
                        _buildHeroBadge(
                          'Gamma Membership Plan',
                          const Color(0xFF1B406B),
                          Colors.blue[300]!,
                        ),
                        _buildHeroBadge(
                          player.isSubscriptionExpired
                              ? '🔴 Expired'
                              : (player.isActive ? '🟢 Active' : '🔴 Inactive'),
                          player.isSubscriptionExpired || !player.isActive
                              ? const Color(0xFF4A1A1A)
                              : const Color(0xFF1A4731),
                          player.isSubscriptionExpired || !player.isActive
                              ? Colors.redAccent
                              : Colors.greenAccent,
                        ),
                        _buildHeroBadge(
                          '${player.currentStreak}🔥 Streak',
                          const Color(0xFF3A3B3C),
                          Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.5.h),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          SizedBox(height: 2.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHeroStat('${player.totalSessionsCompleted}', 'SESSIONS'),
              _buildHeroVerticalDivider(),
              _buildHeroStat('${player.adherenceScore.toInt()}%', 'ADHERENCE'),
              _buildHeroVerticalDivider(),
              _buildHeroStat(
                '${player.weightProgress > 0 ? '+' : ''}${player.weightProgress} kg',
                'PROGRESS',
              ),
              _buildHeroVerticalDivider(),
              _buildHeroStat(
                '${player.subscriptionEnd != null ? (player.subscriptionEnd!.difference(DateTime.now()).inDays > 0 ? player.subscriptionEnd!.difference(DateTime.now()).inDays : 0) : 0}d',
                'REMAINING',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(2.w),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildHeroStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroVerticalDivider() {
    return Container(
      height: 4.h,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildQuickActions(UserModel player) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 3.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildQaItem('💬', 'Message', () {
            final coachUid = ref.read(currentUserModelProvider).value?.uid;
            if (coachUid != null && widget.player != null) {
              final name = [
                widget.player!.firstName,
                widget.player!.lastName,
              ].where((p) => p != null).join(' ');
              final displayName = name.trim().isEmpty
                  ? widget.player!.email
                  : name.trim();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HumanCoachChatScreen(
                    chatId: '${widget.player!.uid.trim()}_${coachUid.trim()}',
                    participantName: displayName,
                    isCoachView: true,
                  ),
                ),
              );
            }
          }),
          _buildQaItem(
            '🤖',
            'AI Track',
            () => _showAiTrackingSheet(player, context),
          ),
          _buildQaItem('💰', 'Payment', () => setState(() => _currentTab = 4)),
          _buildQaItem('📅', 'Renew', () => _showRenewSheet(player)),
          _buildQaItem(
            '📋',
            'Monitor',
            () => context.push('/coach_monitoring', extra: player),
          ),
        ],
      ),
    );
  }

  Widget _buildQaItem(String emoji, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 17.w,
        padding: EdgeInsets.symmetric(vertical: 1.5.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3.w),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: 24.sp)),
            SizedBox(height: 1.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiTrackingSheet(UserModel player, BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            5.w,
            4.h,
            5.w,
            MediaQuery.of(ctx).viewInsets.bottom + 6.h,
          ),
          height: 75.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'coach_ai_nutrition_tracking'.tr(context),
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 0.8.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5FF),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Text(
                      'today'.tr(context),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Text(
                "Monitor ${_displayName(player)}'s daily macro adherence.",
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              SizedBox(height: 4.h),
              _buildMacroProgress('Protein', 150, 200, Colors.blue),
              SizedBox(height: 2.h),
              _buildMacroProgress('Carbs', 200, 250, Colors.orange),
              SizedBox(height: 2.h),
              _buildMacroProgress('Fats', 50, 70, Colors.red),
              SizedBox(height: 4.h),
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: const Color(0xFF007AFF),
                      size: 24.sp,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        'coach_ai_analysis_macro_warning'.tr(context),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF1C1C1E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 6.5.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'close'.tr(context),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
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
  }

  Widget _buildMacroProgress(
    String label,
    int current,
    int target,
    Color color,
  ) {
    double progress = current / target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
            Text(
              '$current / $target g',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(2.w),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 1.5.h,
            backgroundColor: const Color(0xFFE5E5EA),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  void _showRenewSheet(UserModel player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RenewSubscriptionSheet(player: player),
    );
  }

  Widget _buildPersonalInfoCard(UserModel player, BuildContext context) {
    return _buildCard(
      title: 'personal_info'.tr(context),
      icon: '👤',
      iconBg: const Color(0xFFE6F2FF),
      iconColor: const Color(0xFF007AFF),
      children: [
        _buildInfoRow('full_name'.tr(context), _displayName(player)),
        _buildDivider(),
        _buildInfoRow(
          'date_of_birth'.tr(context),
          _formatAgeAndDob(player.dateOfBirth, context),
        ),
        _buildDivider(),
        _buildInfoRow('gender'.tr(context), player.gender ?? 'male'),
        _buildDivider(),
        _buildInfoRow(
          'phone'.tr(context),
          player.phone ?? '0780805230',
          valueColor: const Color(0xFF007AFF),
        ),
        _buildDivider(),
        _buildInfoRow(
          'email'.tr(context),
          player.email,
          valueColor: const Color(0xFF007AFF),
        ),
        _buildDivider(),
        _buildInfoRow(
          'gym'.tr(context),
          '${player.gymId ?? 'Iron Peak Gym'} 📍',
        ),
        _buildDivider(),
        _buildInfoRow(
          'coach'.tr(context),
          player.assignedCoachName ?? 'qutaiba',
        ),
        _buildDivider(),
        _buildInfoRow(
          'training_mode'.tr(context),
          '${player.trainingMode ?? 'gym_only'} 🏋️',
        ),
      ],
    );
  }

  String _formatAgeAndDob(DateTime? date, BuildContext context) {
    if (date == null) return 'Dec 31, 2006 (20 ${'years_short'.tr(context)})';
    int age = DateTime.now().year - date.year;
    return '${DateFormat('MMM d, yyyy').format(date)} ($age ${'years_short'.tr(context)})';
  }

  Widget _buildAccountInfoCard(UserModel player, BuildContext context) {
    return _buildCard(
      title: 'account'.tr(context),
      icon: '🔐',
      iconBg: const Color(0xFFF3E8FF),
      iconColor: Colors.purple,
      children: [
        _buildInfoRow(
          'username'.tr(context),
          '@${player.firstName ?? 'غالب'}',
          valueColor: const Color(0xFF007AFF),
        ),
        _buildDivider(),
        _buildInfoRow('login_email'.tr(context), player.email),
        _buildDivider(),
        _buildInfoRow('password'.tr(context), '........'),
        _buildDivider(),
        _buildInfoRow(
          'account_status'.tr(context),
          player.isSubscriptionExpired
              ? 'coach_expired'.tr(context)
              : (player.isActive
                    ? 'active'.tr(context)
                    : 'suspended'.tr(context)),
          valueColor: player.isSubscriptionExpired || !player.isActive
              ? Colors.red
              : Colors.green,
        ),
        _buildDivider(),
        _buildInfoRow(
          'last_login'.tr(context),
          _formatLastLogin(player.lastLogin),
        ),
        _buildDivider(),
        _buildInfoRow('device'.tr(context), 'iPhone 15 Pro'),
        _buildDivider(),
        _buildInfoRow('app_version'.tr(context), 'NEXUS v2.4.1'),
        _buildDivider(),
        _buildResetPasswordRow(context),
      ],
    );
  }

  Widget _buildResetPasswordRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text('🔑', style: TextStyle(fontSize: 16.sp)),
              SizedBox(width: 2.w),
              Text(
                'coach_reset_password'.tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Text(
            'coach_send_email'.tr(context),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF007AFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(color: Color(0xFFF2F2F7), height: 1, thickness: 1);
  }

  Widget _buildTrainingTab(UserModel player, BuildContext context) {
    return _CoachPlanTab(player: player);
  }

  Widget _buildBodyTab(UserModel player, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Center(
        child: Text(
          'coach_body_vitals_area'.tr(context),
          style: TextStyle(fontSize: 16.sp, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(UserModel player, BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Center(
        child: Text(
          'coach_activity_history_area'.tr(context),
          style: TextStyle(fontSize: 16.sp, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildFinanceTab(UserModel player, BuildContext context) {
    final isExpired =
        player.subscriptionEnd != null &&
        player.subscriptionEnd!.isBefore(DateTime.now());

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2.h),
          _buildSubscriptionCard(player, isExpired, context),
          if (isExpired) _buildRenewalAlert(player, context),
          SizedBox(height: 3.h),
          _buildFinancialSummary(player),
          SizedBox(height: 3.h),
          Text(
            'coach_payment_history'.tr(context),
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 2.h),
          _buildPaymentHistoryList(player, context),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    UserModel player,
    bool isExpired,
    BuildContext context,
  ) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired
              ? [Colors.redAccent, Colors.red]
              : [const Color(0xFF007AFF), const Color(0xFF0056B3)],
        ),
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'coach_current_subscription'.tr(context),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13.sp,
                ),
              ),
              Icon(
                isExpired ? Icons.warning_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(
            player.subscriptionPlan ?? 'coach_custom_plan'.tr(context),
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'coach_expires_on'.tr(context),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.sp,
                    ),
                  ),
                  Text(
                    player.subscriptionEnd != null
                        ? DateFormat(
                            'MMM dd, yyyy',
                          ).format(player.subscriptionEnd!)
                        : 'Never',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'coach_status'.tr(context),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.sp,
                    ),
                  ),
                  Text(
                    isExpired ? 'Expired' : 'Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
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

  Widget _buildRenewalAlert(UserModel player, BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.red, size: 22.sp),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              'coach_subscription_expired_suspended'.tr(context),
              style: TextStyle(
                color: Colors.red[800],
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(UserModel player) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryBox(
            'Total Paid',
            '\$${player.amountPaid ?? 0}',
            Colors.green,
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: _buildSummaryBox(
            'Remaining',
            '\$${player.amountRemaining ?? 0}',
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBox(String label, String amount, Color color) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            amount,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryList(UserModel player, BuildContext context) {
    final paymentsAsync = ref.watch(coachPaymentsProvider(player.uid));
    return paymentsAsync.when(
      data: (payments) {
        final visiblePayments = payments.isEmpty
            ? _fallbackPaymentRecords(player, context)
            : payments;
        if (visiblePayments.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Text(
                'coach_no_payment_history'.tr(context),
                style: TextStyle(color: Colors.grey, fontSize: 14.sp),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visiblePayments.length,
          itemBuilder: (context, index) {
            return _buildPaymentRecordCard(visiblePayments[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('${'error_prefix'.tr(context)} $e')),
    );
  }

  List<PaymentRecord> _fallbackPaymentRecords(
    UserModel player,
    BuildContext context,
  ) {
    if (!player.isActive) return const [];

    final total = player.totalAmount ?? 0.0;
    final paid = player.amountPaid ?? 0.0;
    final remaining = player.amountRemaining ?? 0.0;

    final start = player.subscriptionStart ?? player.createdAt;
    final end = player.subscriptionEnd ?? start;
    return [
      PaymentRecord(
        id: 'current-finance',
        planName: player.subscriptionPlan ?? 'coach_custom_plan'.tr(context),
        amount: paid,
        totalAmount: total,
        discountAmount: player.discountAmount ?? 0.0,
        amountRemaining: remaining,
        paymentMethod: player.paymentMethod ?? 'Pending',
        paymentDate: start,
        durationDays: end.difference(start).inDays,
        type: 'current_balance',
      ),
    ];
  }

  Widget _buildPaymentRecordCard(PaymentRecord p) {
    final isFallback = p.type == 'current_balance';

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  p.planName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                isFallback
                    ? '-\$${p.amountRemaining.toStringAsFixed(2)}'
                    : '+\$${p.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: isFallback ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 0.6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM dd, yyyy').format(p.paymentDate),
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
              Text(
                p.paymentMethod,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
              ),
            ],
          ),
          if (isFallback || p.totalAmount > 0 || p.amountRemaining > 0) ...[
            SizedBox(height: 1.2.h),
            Container(height: 1, color: const Color(0xFFF0F0F5)),
            SizedBox(height: 1.2.h),
            Row(
              children: [
                Expanded(
                  child: _buildMiniFinanceValue(
                    'Total',
                    p.totalAmount,
                    const Color(0xFF1C1C1E),
                  ),
                ),
                Expanded(
                  child: _buildMiniFinanceValue('Paid', p.amount, Colors.green),
                ),
                Expanded(
                  child: _buildMiniFinanceValue(
                    'Remaining',
                    p.amountRemaining,
                    isFallback ? Colors.red : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniFinanceValue(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
        ),
        SizedBox(height: 0.3.h),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String icon,
    required Color iconBg,
    required Color iconColor,
    String? actionText,
    VoidCallback? onAction,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Text(icon, style: TextStyle(fontSize: 18.sp)),
              ),
              SizedBox(width: 3.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              const Spacer(),
              if (actionText != null && onAction != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionText,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: const Color(0xFF8E8E93),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class RenewSubscriptionSheet extends ConsumerStatefulWidget {
  final UserModel player;
  const RenewSubscriptionSheet({super.key, required this.player});

  @override
  ConsumerState<RenewSubscriptionSheet> createState() =>
      _RenewSubscriptionSheetState();
}

class _RenewSubscriptionSheetState
    extends ConsumerState<RenewSubscriptionSheet> {
  late DateTime _startDate;
  int _selectedMonths = 1;
  late DateTime _endDate;
  String _paymentMethod = 'cash';
  double _totalAmount = 0.0;
  double _amount = 0.0;
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startDate =
    widget.player.subscriptionEnd != null &&
        widget.player.subscriptionEnd!.isAfter(DateTime.now())
        ? widget.player.subscriptionEnd!
        : DateTime.now();
    _updateEndDate();
  }

  @override
  void dispose() {
    _totalController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double get _remainingAmount =>
      (_totalAmount - _amount).clamp(0.0, double.infinity).toDouble();

  void _updateEndDate() {
    setState(() {
      _endDate = DateTime(
        _startDate.year,
        _startDate.month + _selectedMonths,
        _startDate.day,
      );
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _updateEndDate();
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _selectedMonths = ((_endDate
            .difference(_startDate)
            .inDays) / 30)
            .round();
        if (_selectedMonths < 1) _selectedMonths = 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery
              .of(context)
              .size
              .height * 0.85,
        ),
        padding: EdgeInsets.fromLTRB(
          6.w,
          2.w,
          6.w,
          MediaQuery.of(context).viewInsets.bottom + 14.w,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 12.w,
                height: 5,
                margin: EdgeInsets.only(bottom: 2.h),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'coach_renew_subscription'.tr(context),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.close, color: Color(0xFF1C1C1E)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${'enter_renewal_details_for'.tr(context)} ${widget
                            .player.firstName ?? ''}:',
                        style: TextStyle(
                            fontSize: 14.sp, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 3.h),

                      // Start Date
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'coach_start_date'.tr(context),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(_startDate),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF007AFF),
                        ),
                        onTap: _pickStartDate,
                      ),
                      Divider(color: Colors.grey[200]),

                      // Duration in Months
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'coach_duration_months'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          DropdownButton<int>(
                            value: _selectedMonths,
                            dropdownColor: Colors.white,
                            items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
                                .map(
                                  (m) =>
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      '$m Months',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                  ),
                            )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedMonths = v;
                                  _updateEndDate();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      Divider(color: Colors.grey[200]),

                      // End Date
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'coach_end_date'.tr(context),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy').format(_endDate),
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF007AFF),
                          ),
                        ),
                        trailing: const Icon(
                          Icons.edit_calendar,
                          color: Color(0xFF007AFF),
                        ),
                        onTap: _pickEndDate,
                      ),
                      Divider(color: Colors.grey[200]),

                      // Payment Method
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'coach_payment_method'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          DropdownButton<String>(
                            value: _paymentMethod,
                            dropdownColor: Colors.white,
                            items: ['cash', 'visa', 'bank_transfer', 'wallet']
                                .map(
                                  (m) =>
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      'coach_$m'.tr(context),
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                  ),
                            )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _paymentMethod = v);
                            },
                          ),
                        ],
                      ),
                      Divider(color: Colors.grey[200]),

                      SizedBox(height: 2.h),

                      // Total Amount
                      TextField(
                        controller: _totalController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                            fontSize: 14.sp, color: const Color(0xFF1C1C1E)),
                        decoration: InputDecoration(
                          labelText: 'coach_total_amount'.tr(context),
                          labelStyle: TextStyle(color: const Color(0xFF8E8E93)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3.w),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        onChanged: (v) {
                          setState(() =>
                          _totalAmount = double.tryParse(v) ?? 0.0);
                        },
                      ),

                      SizedBox(height: 1.5.h),

                      // Amount Paid
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                            fontSize: 14.sp, color: const Color(0xFF1C1C1E)),
                        decoration: InputDecoration(
                          labelText: 'coach_amount_paid_usd'.tr(context),
                          labelStyle: TextStyle(color: const Color(0xFF8E8E93)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(3.w),
                          ),
                          prefixIcon: const Icon(Icons.attach_money),
                        ),
                        onChanged: (v) {
                          setState(() => _amount = double.tryParse(v) ?? 0.0);
                        },
                      ),

                      SizedBox(height: 1.5.h),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(3.w),
                          border: Border.all(color: const Color(0xFFE5E5EA)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'coach_remaining'.tr(context),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF3A3A3C),
                              ),
                            ),
                            Text(
                              '\$${_remainingAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w900,
                                color: _remainingAmount > 0
                                    ? Colors.orange
                                    : const Color(0xFF34C759),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 4.h),
                      SizedBox(
                        width: double.infinity,
                        height: 6.5.h,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3.w),
                            ),
                          ),
                          onPressed: () async {
                            if (_totalAmount <= 0 ||
                                _amount < 0 ||
                                _amount > _totalAmount) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'coach_please_fill_required'.tr(context)),
                                ),
                              );
                              return;
                            }

                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            final successMessage = 'coach_subscription_renewed'
                                .tr(
                              context,
                            );
                            await ref
                                .read(coachRepositoryProvider)
                                .renewSubscription(
                              uid: widget.player.uid,
                              startDate: _startDate,
                              endDate: _endDate,
                              totalAmount: _totalAmount,
                              amountPaid: _amount,
                              amountRemaining: _remainingAmount,
                              planName: '$_selectedMonths Month(s) Plan',
                              paymentMethod: _paymentMethod,
                            );
                            if (!mounted) return;
                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(content: Text(successMessage)),
                            );
                          },
                          child: Text(
                            'coach_confirm_renewal'.tr(context),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ]

        )
    );
  }
}

// ─── Coach Plan Tab ───────────────────────────────────────────────────────────

class _CoachPlanTab extends ConsumerStatefulWidget {
  final UserModel player;
  const _CoachPlanTab({required this.player});

  @override
  ConsumerState<_CoachPlanTab> createState() => _CoachPlanTabState();
}

class _CoachPlanTabState extends ConsumerState<_CoachPlanTab> {

  @override
  Widget build(BuildContext context) {
    final setupAsync = ref.watch(playerSplitSetupProvider(widget.player.uid));
    final planAsync = ref.watch(playerGeneratedPlanProvider(widget.player.uid));

    return setupAsync.when(
      data: (setup) => _buildContent(context, setup, planAsync),
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF1C1C1E))),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SplitSetupData setup,
    AsyncValue<List<WorkoutDay>> planAsync,
  ) {
    final name = '${widget.player.firstName ?? ''} ${widget.player.lastName ?? ''}'.trim();
    final hasPlan = setup.splitType.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2.h),

          // ── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasPlan ? 'Active Training Plan' : 'No Plan Set',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              GestureDetector(
                onTap: () => _showEditSheet(context, setup),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(2.5.w),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasPlan ? Icons.edit_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                      SizedBox(width: 1.5.w),
                      Text(
                        hasPlan ? 'Edit Plan' : 'Set Plan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 2.h),

          if (!hasPlan) ...[
            // ── No Plan Placeholder ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(4.w),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Column(
                children: [
                  Text('📋', style: TextStyle(fontSize: 36.sp)),
                  SizedBox(height: 1.h),
                  Text(
                    'No training plan assigned',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Tap "Set Plan" to create a plan for $name',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Plan Config Card ───────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(4.w),
              ),
              child: Column(
                children: [
                  _configRow('Split', setup.splitType, Icons.fitness_center_rounded),
                  Divider(color: Colors.white.withOpacity(0.08), height: 2.5.h),
                  _configRow(
                    'Days / Week',
                    '${setup.daysPerWeek} days',
                    Icons.calendar_today_rounded,
                  ),
                  Divider(color: Colors.white.withOpacity(0.08), height: 2.5.h),
                  _configRow(
                    'Training Days',
                    setup.trainingDays.join(' · '),
                    Icons.event_available_rounded,
                  ),
                  Divider(color: Colors.white.withOpacity(0.08), height: 2.5.h),
                  _configRow(
                    'Start Date',
                    setup.planStartDate != null
                        ? DateFormat('MMM d, yyyy').format(setup.planStartDate!)
                        : 'Today',
                    Icons.play_arrow_rounded,
                  ),
                ],
              ),
            ),

            SizedBox(height: 3.h),

            // ── Weekly Schedule ────────────────────────────────────────────
            Text(
              'Weekly Schedule',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            SizedBox(height: 1.5.h),

            planAsync.when(
              data: (plan) => _buildWeekStrip(plan),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
              ),
              error: (_, __) => const SizedBox(),
            ),
          ],

          SizedBox(height: 6.h),
        ],
      ),
    );
  }

  Widget _configRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2.w),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 14.sp),
        ),
        SizedBox(width: 3.w),
        Text(
          label,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }

  Widget _buildWeekStrip(List<WorkoutDay> plan) {
    if (plan.isEmpty) return const SizedBox();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: plan.map((day) {
          final isRest = day.isRest;
          return Container(
            width: 30.w,
            margin: EdgeInsetsDirectional.only(end: 2.5.w),
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: isRest ? const Color(0xFFF5F5F7) : Colors.white,
              borderRadius: BorderRadius.circular(3.5.w),
              border: Border.all(
                color: isRest
                    ? const Color(0xFFE5E5EA)
                    : const Color(0xFF1C1C1E).withOpacity(0.15),
                width: isRest ? 0.5 : 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.dayName,
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(height: 0.8.h),
                Text(
                  isRest ? 'Rest' : day.title,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1.h),
                Icon(
                  isRest
                      ? Icons.weekend_rounded
                      : Icons.fitness_center_rounded,
                  size: 14.sp,
                  color: isRest
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF1C1C1E),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEditSheet(BuildContext context, SplitSetupData current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPlanSheet(
        player: widget.player,
        current: current,
        onSaved: () {
          ref.invalidate(playerSplitSetupProvider(widget.player.uid));
          ref.invalidate(playerGeneratedPlanProvider(widget.player.uid));
        },
      ),
    );
  }
}

// ─── Edit Plan Sheet ──────────────────────────────────────────────────────────

class _EditPlanSheet extends ConsumerStatefulWidget {
  final UserModel player;
  final SplitSetupData current;
  final VoidCallback onSaved;

  const _EditPlanSheet({
    required this.player,
    required this.current,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditPlanSheet> createState() => _EditPlanSheetState();
}

class _EditPlanSheetState extends ConsumerState<_EditPlanSheet> {
  static const _dayOrder = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _splitTypes = [
    'Push/Pull/Legs',
    'Upper/Lower',
    'Full Body',
    'Bro Split',
    'Arnold Split',
    'Custom',
  ];

  late int _daysPerWeek;
  late String _splitType;
  late List<String> _trainingDays;
  late DateTime _startDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _daysPerWeek = widget.current.daysPerWeek;
    _splitType = widget.current.splitType.isNotEmpty
        ? widget.current.splitType
        : _splitTypes.first;
    _trainingDays = List<String>.from(widget.current.trainingDays);
    _startDate = widget.current.planStartDate ?? DateTime.now();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark(),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (_trainingDays.length != _daysPerWeek) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Select exactly $_daysPerWeek training days (${_trainingDays.length} selected)'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(coachRepositoryProvider).savePlayerSplitSetup(
            playerUid: widget.player.uid,
            daysPerWeek: _daysPerWeek,
            splitType: _splitType,
            trainingDays: _trainingDays,
            planStartDate: _startDate,
          );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Training plan saved ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      padding: EdgeInsets.fromLTRB(
          5.w, 2.h, 5.w, MediaQuery.of(context).viewInsets.bottom + 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 12.w,
              height: 4,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set Training Plan',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Plan for ${widget.player.firstName ?? ''} ${widget.player.lastName ?? ''}'.trim(),
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          ),

          SizedBox(height: 2.h),

          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Days per week ────────────────────────────────────────
                  _sectionTitle('Days per Week'),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [3, 4, 5, 6].map((d) {
                      final sel = _daysPerWeek == d;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _daysPerWeek = d;
                              // Keep only d days
                              if (_trainingDays.length > d) {
                                _trainingDays = _trainingDays.take(d).toList();
                              }
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: d < 6 ? 2.w : 0),
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Text(
                                  '$d',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: sel
                                        ? Colors.white
                                        : const Color(0xFF1C1C1E),
                                  ),
                                ),
                                Text(
                                  'days',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: sel
                                        ? Colors.white70
                                        : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 3.h),

                  // ── Split type ───────────────────────────────────────────
                  _sectionTitle('Split Type'),
                  SizedBox(height: 1.h),
                  Wrap(
                    spacing: 2.w,
                    runSpacing: 1.h,
                    children: _splitTypes.map((s) {
                      final sel = _splitType == s;
                      return GestureDetector(
                        onTap: () => setState(() => _splitType = s),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 3.5.w, vertical: 1.2.h),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(2.w),
                            border: sel
                                ? null
                                : Border.all(
                                    color: const Color(0xFFE5E5EA)),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 3.h),

                  // ── Training days ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle('Training Days'),
                      Text(
                        '${_trainingDays.length} / $_daysPerWeek selected',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: _trainingDays.length == _daysPerWeek
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _dayOrder.map((d) {
                      final sel = _trainingDays.contains(d);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (sel) {
                                _trainingDays.remove(d);
                              } else if (_trainingDays.length <
                                  _daysPerWeek) {
                                _trainingDays.add(d);
                                _trainingDays.sort((a, b) =>
                                    _dayOrder.indexOf(a)
                                        .compareTo(_dayOrder.indexOf(b)));
                              }
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(
                                right: d != 'SUN' ? 1.w : 0),
                            padding:
                                EdgeInsets.symmetric(vertical: 1.5.h),
                            decoration: BoxDecoration(
                              color: sel
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              d.substring(0, 1),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                color: sel
                                    ? Colors.white
                                    : Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 3.h),

                  // ── Start date ───────────────────────────────────────────
                  _sectionTitle('Plan Start Date'),
                  SizedBox(height: 1.h),
                  GestureDetector(
                    onTap: _pickStartDate,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                          horizontal: 4.w, vertical: 1.8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(3.w),
                        border:
                            Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 16.sp,
                              color: const Color(0xFF1C1C1E)),
                          SizedBox(width: 3.w),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy')
                                .format(_startDate),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.grey, size: 16.sp),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 4.h),

                  // ── Save ─────────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 6.5.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : Text(
                              'Save Training Plan',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1C1C1E),
      ),
    );
  }
}