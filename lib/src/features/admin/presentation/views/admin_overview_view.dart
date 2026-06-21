import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../user/models/user_model.dart';
import '../../data/admin_repository.dart';
import '../screens/admin_dashboard_screen.dart';

class AdminOverviewView extends ConsumerWidget {
  const AdminOverviewView({super.key});

  // ── Presence threshold ─────────────────────────────────────────────────────
  // A player is considered "live" if their lastLogin is within 2 hours.
  static const _liveThreshold = Duration(hours: 2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final gymId = user?.gymId ?? '';

    final playersAsync = ref.watch(adminPlayersProvider(gymId));
    final coachesAsync = ref.watch(adminCoachesProvider(gymId));
    final paymentsAsync = ref.watch(adminPaymentsProvider(gymId));
    final gymAsync = ref.watch(gymInfoProvider(gymId));
    final checkinsAsync = ref.watch(todayCheckInsProvider(gymId));

    final players = playersAsync.asData?.value ?? [];
    final coaches = coachesAsync.asData?.value ?? [];
    final payments = paymentsAsync.asData?.value ?? [];
    final gymInfo = gymAsync.asData?.value ?? {};
    final checkins = checkinsAsync.asData?.value ?? [];

    // ── Derived real stats ─────────────────────────────────────────────────
    final now = DateTime.now();

    // Live now: lastLogin within threshold
    final livePlayers = players
        .where((p) =>
            p.lastLogin != null &&
            now.difference(p.lastLogin!) <= _liveThreshold)
        .toList();
    final numLive = livePlayers.length;

    // Revenue — this month
    double thisMonthRevenue = 0;
    double lastMonthRevenue = 0;
    for (var p in payments) {
      if (p.date.year == now.year && p.date.month == now.month) {
        thisMonthRevenue += p.amount;
      }
      final lastMonth = DateTime(now.year, now.month - 1);
      if (p.date.year == lastMonth.year && p.date.month == lastMonth.month) {
        lastMonthRevenue += p.amount;
      }
    }

    // Revenue trend %
    String revenueTrend;
    Color revenueTrendColor;
    if (lastMonthRevenue == 0) {
      revenueTrend = 'New';
      revenueTrendColor = const Color(0xFF5BA8FF);
    } else {
      final pct =
          ((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue * 100)
              .round();
      revenueTrend = pct >= 0 ? '▲ +$pct%' : '▼ $pct%';
      revenueTrendColor =
          pct >= 0 ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    }

    // Monthly chart data — last 6 calendar months
    final monthlyRevenue = _computeMonthlyRevenue(payments, now);

    // Expiring within 7 days
    int expiringSoon = 0;
    for (var p in players) {
      if (p.subscriptionEnd != null) {
        final daysLeft = p.subscriptionEnd!.difference(now).inDays;
        if (daysLeft >= 0 && daysLeft <= 7) expiringSoon++;
      }
    }

    // Active / suspended split
    final activePlayers = players.where((p) => p.isActive).length;
    final suspended = players.length - activePlayers;

    // Average adherence (only players with score > 0)
    final scoredPlayers =
        players.where((p) => p.adherenceScore > 0).toList();
    final avgAdherence = scoredPlayers.isEmpty
        ? null
        : scoredPlayers.fold(0.0, (s, p) => s + p.adherenceScore) /
            scoredPlayers.length;

    // Unassigned players (no coach)
    final unassigned =
        players.where((p) => p.assignedCoachUid == null).length;

    // Gym info
    final gymName = gymInfo['name'] as String? ??
        gymInfo['gymName'] as String? ??
        'My Gym';
    final gymCity = gymInfo['city'] as String? ??
        gymInfo['location'] as String? ??
        '';

    return SafeArea(
      child: Column(
        children: [
          _buildTopbar(context, ref),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(adminPlayersProvider(gymId));
                ref.invalidate(adminCoachesProvider(gymId));
                ref.invalidate(adminPaymentsProvider(gymId));
                ref.invalidate(gymInfoProvider(gymId));
              },
              color: const Color(0xFFFF3B30),
              backgroundColor: const Color(0xFF1C1C1E),
              child: ListView(
                padding: EdgeInsets.only(bottom: 12.h),
                children: [
                  _buildGymHero(
                    activePlayers,
                    coaches.length,
                    thisMonthRevenue,
                    numLive,
                    gymName,
                    gymCity,
                    avgAdherence,
                  ),
                  _buildStatGrid(
                    context,
                    ref,
                    players,
                    checkins,
                    coaches.length,
                    thisMonthRevenue,
                    numLive,
                    expiringSoon,
                    suspended,
                    unassigned,
                    avgAdherence,
                    revenueTrend,
                    revenueTrendColor,
                  ),
                  SizedBox(height: 2.h),
                  _buildRevenueChartCard(ref, monthlyRevenue, now),
                  SizedBox(height: 1.5.h),
                  _buildLiveActivityCard(ref, livePlayers, players),
                  SizedBox(height: 1.5.h),
                  _buildAlerts(expiringSoon, suspended, unassigned, ref),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Monthly revenue by calendar month ────────────────────────────────────

  static List<_MonthStat> _computeMonthlyRevenue(
      List<PaymentRecord> payments, DateTime now) {
    final result = <_MonthStat>[];
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      double total = 0;
      for (var p in payments) {
        if (p.date.year == month.year && p.date.month == month.month) {
          total += p.amount;
        }
      }
      result.add(_MonthStat(month: month, amount: total));
    }
    return result;
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopbar(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMIN PANEL',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white30,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Command Center 🔐',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildTopBtn(
                icon: Icons.notifications_rounded,
                hasBadge: true,
                onTap: () =>
                    ref.read(adminBottomNavProvider.notifier).setIndex(3),
              ),
              SizedBox(width: 2.w),
              _buildTopBtn(
                icon: Icons.settings_rounded,
                onTap: () =>
                    ref.read(adminBottomNavProvider.notifier).setIndex(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBtn({
    required IconData icon,
    required VoidCallback onTap,
    bool hasBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 10.w,
        height: 10.w,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14.sp),
            if (hasBadge)
              Positioned(
                top: 2.w,
                right: 2.w,
                child: Container(
                  width: 2.5.w,
                  height: 2.5.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF0A0A0F), width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _buildGymHero(
    int numPlayers,
    int numCoaches,
    double revenue,
    int numLive,
    String gymName,
    String gymCity,
    double? avgAdherence,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFC0392B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GYM OWNER DASHBOARD',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.5),
                      letterSpacing: 0.7,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    '$gymName ⚡',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (gymCity.isNotEmpty) ...[
                    SizedBox(height: 0.5.h),
                    Text(
                      gymCity,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
              // Live badge — real count
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 2.5.w, vertical: 1.w),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 1.5.w,
                      height: 1.5.w,
                      decoration: BoxDecoration(
                        color: numLive > 0
                            ? const Color(0xFF34C759)
                            : Colors.white30,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 1.5.w),
                    Text(
                      numLive > 0 ? '$numLive LIVE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.5.h),
          Container(
            padding: EdgeInsets.only(top: 1.5.h),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.12))),
            ),
            child: Row(
              children: [
                _buildHeroStat(numPlayers.toString(), 'ACTIVE'),
                _buildHeroStat(numCoaches.toString(), 'COACHES'),
                _buildHeroStat('${revenue.toInt()} JD', 'THIS MONTH'),
                _buildHeroStat(
                  avgAdherence != null
                      ? '${avgAdherence.toInt()}%'
                      : '—',
                  'ADHERENCE',
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String val, String lbl, {bool isLast = false}) {
    return Expanded(
      child: Container(
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                    right: BorderSide(
                        color: Colors.white.withOpacity(0.1))),
              ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              lbl,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stat grid ─────────────────────────────────────────────────────────────

  Widget _buildStatGrid(
    BuildContext context,
    WidgetRef ref,
    List<UserModel> players,
    List<Map<String, dynamic>> checkins,
    int numCoaches,
    double revenue,
    int numLive,
    int expiringSoon,
    int suspended,
    int unassigned,
    double? avgAdherence,
    String revenueTrend,
    Color revenueTrendColor,
  ) {
    final numPlayers = players.length;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 2.w,
        crossAxisSpacing: 2.w,
        childAspectRatio: 1.7,
        children: [
          _buildStatCard(
            '💰',
            revenueTrend,
            '${revenue.toInt()} JD',
            'REVENUE · THIS MONTH',
            revenueTrendColor,
            null,
            () => ref.read(adminBottomNavProvider.notifier).setIndex(2),
          ),
          _buildStatCard(
            '🏋️',
            numLive > 0 ? '● Live' : '○ Offline',
            '$numLive',
            'ACTIVE NOW',
            numLive > 0
                ? const Color(0xFF34C759)
                : Colors.white30,
            null,
            () => ref.read(adminBottomNavProvider.notifier).setIndex(1),
          ),
          _buildStatCard(
            '⚠️',
            expiringSoon > 0 ? '! Urgent' : '✓ Clear',
            '$expiringSoon',
            'EXPIRING ≤7 DAYS',
            expiringSoon > 0
                ? const Color(0xFFFF3B30)
                : const Color(0xFF34C759),
            expiringSoon > 0 ? const Color(0xFFFF9500) : null,
            () => ref.read(adminBottomNavProvider.notifier).setIndex(1),
          ),
          _buildStatCard(
            '🚫',
            suspended > 0 ? '! Review' : '✓ Good',
            '$suspended',
            'SUSPENDED',
            suspended > 0
                ? const Color(0xFFFF3B30)
                : const Color(0xFF34C759),
            null,
            () => ref.read(adminBottomNavProvider.notifier).setIndex(1),
          ),
          _buildStatCard(
            '📋',
            checkins.isNotEmpty ? '▲ اضغط للتفاصيل' : '○ لا يوجد',
            '${checkins.length}',
            'حضور اليوم',
            checkins.isNotEmpty
                ? const Color(0xFF34C759)
                : Colors.white30,
            checkins.isNotEmpty ? const Color(0xFF34C759) : null,
            () => _showTodayAttendanceSheet(context, checkins, players),
          ),
          _buildStatCard(
            '👤',
            unassigned > 0 ? '! Unassigned' : '✓ All set',
            '$unassigned',
            'NO COACH YET',
            unassigned > 0
                ? const Color(0xFFFF9500)
                : const Color(0xFF34C759),
            null,
            () => ref.read(adminBottomNavProvider.notifier).setIndex(4),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String icon,
    String trend,
    String val,
    String lbl,
    Color trendColor,
    Color? valColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
              color: Colors.white.withOpacity(0.08), width: 0.5),
          borderRadius: BorderRadius.circular(3.5.w),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: TextStyle(fontSize: 18.sp)),
                Flexible(
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: trendColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    val,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: valColor ?? Colors.white,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(height: 0.2.h),
                Text(
                  lbl,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white30,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's attendance sheet ─────────────────────────────────────────────

  void _showTodayAttendanceSheet(
    BuildContext context,
    List<Map<String, dynamic>> checkins,
    List<UserModel> players,
  ) {
    // Map uid → player for quick lookup
    final playerMap = {for (final p in players) p.uid: p};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 12.w, height: 4,
                  margin: EdgeInsets.only(top: 1.5.h, bottom: 1.h),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      child: Icon(Icons.how_to_reg_rounded,
                          color: const Color(0xFF34C759), size: 16.sp),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('حضور اليوم',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800)),
                          Text('${checkins.length} لاعب حضر اليوم',
                              style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10.sp)),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 0.8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      child: Text('${checkins.length}',
                          style: TextStyle(
                              color: const Color(0xFF34C759),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.07), height: 1),
              // Table header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                child: Row(
                  children: [
                    Expanded(flex: 3,
                        child: Text('اللاعب', style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2,
                        child: Text('الخطة', style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2,
                        child: Text('وقت الحضور', style: TextStyle(color: Colors.white38, fontSize: 10.sp, fontWeight: FontWeight.w700), textAlign: TextAlign.end)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.05), height: 1),
              // List
              Expanded(
                child: checkins.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('📋', style: TextStyle(fontSize: 28.sp)),
                            SizedBox(height: 1.h),
                            Text('لا يوجد حضور اليوم',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12.sp)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: checkins.length,
                        padding: EdgeInsets.symmetric(vertical: 0.5.h),
                        itemBuilder: (_, i) {
                          final c = checkins[i];
                          final uid = c['playerUid'] as String? ?? '';
                          final player = playerMap[uid];
                          final name = c['playerName'] as String? ??
                              '${player?.firstName ?? ''} ${player?.lastName ?? ''}'.trim();
                          final plan = player?.subscriptionPlan ?? '—';
                          final rawTime = c['checkedInAt'];
                          String timeStr = '—';
                          if (rawTime is String && rawTime.isNotEmpty) {
                            timeStr = rawTime;
                          }

                          final initials = name.isNotEmpty
                              ? name.trim().split(' ').take(2)
                                  .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
                                  .join()
                              : '?';

                          return Container(
                            margin: EdgeInsets.symmetric(
                                horizontal: 4.w, vertical: 0.4.h),
                            padding: EdgeInsets.symmetric(
                                horizontal: 3.w, vertical: 1.2.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(2.5.w),
                              border: Border.all(
                                  color: const Color(0xFF34C759)
                                      .withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                Container(
                                  width: 8.w, height: 8.w,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF34C759)
                                        .withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(initials,
                                        style: TextStyle(
                                            color: const Color(0xFF34C759),
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                SizedBox(width: 2.w),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    name.isEmpty ? uid : name,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    plan,
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10.sp),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    timeStr,
                                    style: TextStyle(
                                        color: const Color(0xFF34C759),
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Revenue chart — real monthly data ────────────────────────────────────

  Widget _buildRevenueChartCard(
    WidgetRef ref,
    List<_MonthStat> monthlyRevenue,
    DateTime now,
  ) {
    final maxAmount =
        monthlyRevenue.fold(0.0, (m, s) => s.amount > m ? s.amount : m);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
            color: Colors.white.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 2.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      alignment: Alignment.center,
                      child: Text('💰',
                          style: TextStyle(fontSize: 14.sp)),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Revenue — Last 6 Months',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () =>
                      ref.read(adminBottomNavProvider.notifier).setIndex(2),
                  child: Text(
                    'Detail →',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5BA8FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 3.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: monthlyRevenue.map((stat) {
                final isNow = stat.month.year == now.year &&
                    stat.month.month == now.month;
                final ratio = maxAmount == 0
                    ? 0.0
                    : (stat.amount / maxAmount).clamp(0.05, 1.0);
                final label = _monthLabel(stat.month);
                return _buildChartBar(label, ratio, isNow: isNow);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return months[d.month - 1];
  }

  Widget _buildChartBar(String label, double heightRatio,
      {bool isNow = false}) {
    return Column(
      children: [
        Container(
          width: 8.w,
          height: 10.h * heightRatio,
          decoration: BoxDecoration(
            color: isNow
                ? const Color(0xFF34C759)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.vertical(top: Radius.circular(1.w)),
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
            color: isNow ? Colors.white : Colors.white30,
          ),
        ),
      ],
    );
  }

  // ── Live activity card — real active players ──────────────────────────────

  Widget _buildLiveActivityCard(
    WidgetRef ref,
    List<UserModel> livePlayers,
    List<UserModel> allPlayers,
  ) {
    // Prefer real live; fall back to recently active (today) if none are "live"
    List<UserModel> shown = livePlayers;
    if (shown.isEmpty) {
      final today = DateTime.now();
      shown = allPlayers
          .where((p) =>
              p.isActive &&
              p.lastLogin != null &&
              p.lastLogin!.year == today.year &&
              p.lastLogin!.month == today.month &&
              p.lastLogin!.day == today.day)
          .take(5)
          .toList();
    }
    final displayList = shown.take(5).toList();
    final isLive = livePlayers.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
            color: Colors.white.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 3.h, 4.w, 2.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      alignment: Alignment.center,
                      child: Text('⚡',
                          style: TextStyle(fontSize: 14.sp)),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      isLive
                          ? 'Live Now (${livePlayers.length})'
                          : 'Active Today (${displayList.length})',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () =>
                      ref.read(adminBottomNavProvider.notifier).setIndex(1),
                  child: Text(
                    'All →',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5BA8FF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (displayList.isEmpty)
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Text(
                'No players active recently.',
                style:
                    TextStyle(color: Colors.white30, fontSize: 13.sp),
              ),
            ),
          for (var p in displayList)
            _buildLiveRow(
              '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim().isEmpty
                  ? p.email
                  : '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim(),
              p.lastLogin != null
                  ? _timeAgo(p.lastLogin!)
                  : 'Active member',
              p.subscriptionPlan ?? 'Member',
              isLive && livePlayers.contains(p)
                  ? const Color(0xFF34C759)
                  : const Color(0xFF5BA8FF),
            ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildLiveRow(
      String name, String meta, String badge, Color badgeColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Row(
        children: [
          Container(
            width: 9.w,
            height: 9.w,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Stack(
              children: [
                Text('💪', style: TextStyle(fontSize: 16.sp)),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 2.5.w,
                    height: 2.5.w,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0A0A0F), width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0.3.h),
                Text(
                  meta,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Alerts — real conditions ──────────────────────────────────────────────

  Widget _buildAlerts(int expiringSoon, int suspended, int unassigned, WidgetRef ref) {
    final alerts = <_Alert>[];

    if (expiringSoon > 0) {
      alerts.add(_Alert(
        icon: '🔴',
        title: '$expiringSoon subscription${expiringSoon > 1 ? 's' : ''} expiring this week',
        sub: 'Go to Players → renew before they lapse',
        color: const Color(0xFFFF3B30),
        navIndex: 1, // Players tab
      ));
    }
    if (suspended > 0) {
      alerts.add(_Alert(
        icon: '🟠',
        title: '$suspended player${suspended > 1 ? 's' : ''} suspended',
        sub: 'Check Players tab to review or reactivate',
        color: const Color(0xFFFF9500),
        navIndex: 1, // Players tab
      ));
    }
    if (unassigned > 0) {
      alerts.add(_Alert(
        icon: '🟡',
        title: '$unassigned player${unassigned > 1 ? 's' : ''} without a coach',
        sub: 'Go to Coaches → assign a coach',
        color: const Color(0xFFFFCC00),
        navIndex: 4, // More tab (Coaches & Settings)
      ));
    }
    if (alerts.isEmpty) {
      alerts.add(_Alert(
        icon: '🟢',
        title: 'All good — no action required',
        sub: 'Gym is running smoothly',
        color: const Color(0xFF34C759),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.5.w, vertical: 1.h),
          child: Text(
            '⚠️ ALERTS',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFF3B30).withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
        ),
        for (var a in alerts) _buildAlertCard(a, ref),
      ],
    );
  }

  Widget _buildAlertCard(_Alert a, WidgetRef ref) {
    final tappable = a.navIndex != null;
    return GestureDetector(
      onTap: tappable
          ? () => ref.read(adminBottomNavProvider.notifier).setIndex(a.navIndex!)
          : null,
      child: Container(
        margin: EdgeInsets.only(left: 4.w, right: 4.w, bottom: 1.5.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: a.color.withOpacity(0.1),
          border: Border.all(color: a.color.withOpacity(tappable ? 0.4 : 0.2), width: 0.5),
          borderRadius: BorderRadius.circular(3.5.w),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.icon, style: TextStyle(fontSize: 18.sp)),
            SizedBox(width: 2.5.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: a.color,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    a.sub,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (tappable) ...[
              SizedBox(width: 2.w),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: a.color.withOpacity(0.6), size: 12.sp),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Data helpers ───────────────────────────────────────────────────────────────

class _MonthStat {
  final DateTime month;
  final double amount;
  const _MonthStat({required this.month, required this.amount});
}

class _Alert {
  final String icon;
  final String title;
  final String sub;
  final Color color;
  final int? navIndex; // null = no navigation (e.g. "all clear")
  const _Alert({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
    this.navIndex,
  });
}
