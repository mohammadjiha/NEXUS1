import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../coach/data/coach_repository.dart';
import '../../../user/models/user_model.dart';
import '../../data/admin_repository.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/import_players_screen.dart';

final adminPlayerFilterProvider = StateProvider<String>((ref) => 'all');
final adminPlayerTabProvider = StateProvider<int>((ref) => 0);

// ─── Admin Players View ───────────────────────────────────────────────────────

class AdminPlayersView extends ConsumerStatefulWidget {
  const AdminPlayersView({super.key});

  @override
  ConsumerState<AdminPlayersView> createState() => _AdminPlayersViewState();
}

class _AdminPlayersViewState extends ConsumerState<AdminPlayersView> {
  bool _searchOpen = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final gymId = user?.gymId ?? '';

    final playersAsync = ref.watch(adminPlayersProvider(gymId));
    final players = playersAsync.asData?.value ?? [];

    final filter = ref.watch(adminPlayerFilterProvider);
    final tabIndex = ref.watch(adminPlayerTabProvider);

    var filtered = _applyFilter(players, filter);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.toLowerCase();
        final email = p.email.toLowerCase();
        return name.contains(q) || email.contains(q);
      }).toList();
    }

    return SafeArea(
      child: Column(
        children: [
          _buildTopbar(context, ref, players.length, gymId),
          if (_searchOpen) _buildSearchBar(),
          _buildFilterRow(ref, filter, players),
          _buildTabs(ref, tabIndex),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminPlayersProvider(gymId)),
              color: const Color(0xFFFF3B30),
              backgroundColor: const Color(0xFF1C1C1E),
              child: _buildTabContent(context, ref, tabIndex, filtered, gymId),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  List<UserModel> _applyFilter(List<UserModel> players, String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'active':
        // Active = فعال ومش قارب ينتهي (أكثر من 7 أيام متبقية)
        return players.where((p) {
          if (p.isActive != true) return false;
          if (p.subscriptionEnd == null) return true;
          return p.subscriptionEnd!.difference(now).inDays > 7;
        }).toList();
      case 'suspended':
        return players.where((p) => p.isActive != true).toList();
      case 'elite':
        return players
            .where((p) =>
                p.subscriptionPlan?.toLowerCase().contains('elite') == true)
            .toList();
      case 'pro':
        return players
            .where((p) =>
                p.subscriptionPlan?.toLowerCase().contains('pro') == true)
            .toList();
      case 'expiring':
        return players.where((p) {
          if (p.subscriptionEnd == null) return false;
          final days = p.subscriptionEnd!.difference(now).inDays;
          return days >= 0 && days <= 7;
        }).toList();
      case 'all':
      default:
        return players;
    }
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────

  Widget _buildTopbar(
      BuildContext context, WidgetRef ref, int totalPlayers, String gymId) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    ref.read(adminBottomNavProvider.notifier).setIndex(0),
                child: Container(
                  width: 9.w,
                  height: 9.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 14.sp),
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                'Players ($totalPlayers)',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Import players button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ImportPlayersScreen(),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 4.w, vertical: 1.2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5BA8FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.upload_file_rounded,
                          color: const Color(0xFF5BA8FF), size: 15.sp),
                      SizedBox(width: 2.w),
                      Text('استيراد',
                          style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF5BA8FF))),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              _buildTopBtn(
                icon: Icons.person_add_rounded,
                onTap: () => _showAddPlayerSheet(context, ref, gymId),
              ),
              SizedBox(width: 2.w),
              _buildTopBtn(
                icon: Icons.search_rounded,
                onTap: () {
                  setState(() {
                    _searchOpen = !_searchOpen;
                    if (!_searchOpen) {
                      _searchQuery = '';
                      _searchCtrl.clear();
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 9.w,
        height: 9.w,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 14.sp),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.h),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: TextStyle(color: Colors.white, fontSize: 13.sp),
        decoration: InputDecoration(
          hintText: 'Search by name or email…',
          hintStyle:
              TextStyle(color: Colors.white54, fontSize: 13.sp),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Colors.white54),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchQuery = '';
                      _searchCtrl.clear();
                    });
                  },
                  child: const Icon(Icons.clear, color: Colors.white54),
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3.w),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  // ── Filter chips ──────────────────────────────────────────────────────────────

  Widget _buildFilterRow(
      WidgetRef ref, String currentFilter, List<UserModel> allPlayers) {
    final now = DateTime.now();
    // Active = فعال ومش قارب ينتهي
    final cActive = allPlayers.where((p) {
      if (p.isActive != true) return false;
      if (p.subscriptionEnd == null) return true;
      return p.subscriptionEnd!.difference(now).inDays > 7;
    }).length;
    final cSuspended = allPlayers.where((p) => p.isActive != true).length;
    final cElite = allPlayers
        .where((p) =>
            p.subscriptionPlan?.toLowerCase().contains('elite') == true)
        .length;
    final cPro = allPlayers
        .where(
            (p) => p.subscriptionPlan?.toLowerCase().contains('pro') == true)
        .length;
    final cExpiring = allPlayers.where((p) {
      if (p.subscriptionEnd == null) return false;
      final days = p.subscriptionEnd!.difference(now).inDays;
      return days >= 0 && days <= 7;
    }).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.5.h),
      child: Row(
        children: [
          _buildFilterChip(ref, 'all', currentFilter,
              'All (${allPlayers.length})', const Color(0xFFFF3B30)),
          _buildFilterChip(ref, 'active', currentFilter, 'Active ($cActive)',
              Colors.white),
          _buildFilterChip(ref, 'expiring', currentFilter,
              'Expiring ($cExpiring)', const Color(0xFFFF9500)),
          _buildFilterChip(ref, 'suspended', currentFilter,
              'Suspended ($cSuspended)', const Color(0xFFFF3B30)),
          _buildFilterChip(
              ref, 'elite', currentFilter, 'Elite ($cElite)', Colors.white),
          _buildFilterChip(
              ref, 'pro', currentFilter, 'Pro ($cPro)', Colors.white),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String filterVal, String currentFilter,
      String label, Color baseColor) {
    final isSel = filterVal == currentFilter;
    return GestureDetector(
      onTap: () =>
          ref.read(adminPlayerFilterProvider.notifier).state = filterVal,
      child: Container(
        margin: EdgeInsets.only(right: 2.w),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSel
              ? baseColor
              : (baseColor == Colors.white
                  ? Colors.white.withOpacity(0.07)
                  : baseColor.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(5.w),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isSel
                ? (baseColor == Colors.white
                    ? const Color(0xFF0A0A0F)
                    : Colors.white)
                : (baseColor == Colors.white
                    ? Colors.white.withOpacity(0.5)
                    : baseColor),
          ),
        ),
      ),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────────

  Widget _buildTabs(WidgetRef ref, int tabIndex) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(0.5.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        children: [
          _buildTab(ref, 0, tabIndex, 'All Players'),
          _buildTab(ref, 1, tabIndex, 'Performance'),
          _buildTab(ref, 2, tabIndex, 'Issues'),
        ],
      ),
    );
  }

  Widget _buildTab(
      WidgetRef ref, int index, int currentIndex, String label) {
    final isSel = index == currentIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () =>
            ref.read(adminPlayerTabProvider.notifier).state = index,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.h),
          decoration: BoxDecoration(
            color: isSel
                ? Colors.white.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(2.5.w),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color:
                  isSel ? Colors.white : Colors.white.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab content ───────────────────────────────────────────────────────────────

  Widget _buildTabContent(BuildContext context, WidgetRef ref, int tabIndex,
      List<UserModel> players, String gymId) {
    if (tabIndex == 0) {
      if (players.isEmpty) {
        return Center(
          child: Text('No players found',
              style:
                  TextStyle(color: Colors.white54, fontSize: 14.sp)),
        );
      }
      return ListView.builder(
        padding: EdgeInsets.only(top: 1.h, bottom: 12.h),
        itemCount: players.length,
        itemBuilder: (ctx, i) => _buildPlayerRow(
            context, ref, players[i], gymId),
      );
    } else if (tabIndex == 1) {
      return _buildPerformanceTab(players);
    } else {
      return _buildIssuesTab(players);
    }
  }

  // ── Performance tab ───────────────────────────────────────────────────────────

  Widget _buildPerformanceTab(List<UserModel> players) {
    if (players.isEmpty) {
      return Center(
          child: Text('No player data yet',
              style: TextStyle(color: Colors.white54, fontSize: 12.sp)));
    }

    final now = DateTime.now();
    final total      = players.length;
    final active     = players.where((p) => p.isActive).length;
    final inactive   = total - active;
    final expired    = players.where((p) =>
        p.subscriptionEnd != null && p.subscriptionEnd!.isBefore(now)).length;
    final expiring   = players.where((p) =>
        p.subscriptionEnd != null &&
        !p.subscriptionEnd!.isBefore(now) &&
        p.subscriptionEnd!.difference(now).inDays <= 7).length;
    final noCoach    = players.where((p) =>
        p.assignedCoachUid == null || p.assignedCoachUid!.isEmpty).length;
    final totalDebt  = players.fold(0.0, (s, p) => s + (p.amountRemaining ?? 0));
    final avgDebt    = total > 0 ? totalDebt / total : 0.0;

    // Goal breakdown
    final goalCounts = <String, int>{};
    for (final p in players) {
      final g = p.goal ?? 'unknown';
      goalCounts[g] = (goalCounts[g] ?? 0) + 1;
    }

    // Avg metrics
    final withWeight = players.where((p) => (p.weight ?? 0) > 0).toList();
    final withBMI    = players.where((p) =>
        (p.weight ?? 0) > 0 && (p.height ?? 0) > 0).toList();
    final avgWeight  = withWeight.isEmpty ? 0.0
        : withWeight.fold(0.0, (s, p) => s + p.weight!) / withWeight.length;
    final avgBMI     = withBMI.isEmpty ? 0.0
        : withBMI.fold(0.0, (s, p) =>
            s + p.weight! / ((p.height! / 100) * (p.height! / 100))) /
          withBMI.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 12.h),
      children: [
        // ── Status breakdown ───────────────────────────────────────────────
        _perfSection('MEMBERSHIP STATUS'),
        _statBar('Active',   active,   total, const Color(0xFF34C759)),
        _statBar('Inactive', inactive, total, const Color(0xFFFF3B30)),
        _statBar('Expired',  expired,  total, const Color(0xFFFF9500)),
        _statBar('Expiring ≤7d', expiring, total, const Color(0xFFFFCC00)),
        SizedBox(height: 2.h),

        // ── Financial snapshot ─────────────────────────────────────────────
        _perfSection('FINANCIAL SNAPSHOT'),
        Row(children: [
          Expanded(child: _kpiCard('Total Debt',
              '${totalDebt.toStringAsFixed(0)} JD',
              const Color(0xFFFF9500))),
          SizedBox(width: 3.w),
          Expanded(child: _kpiCard('Avg / Player',
              '${avgDebt.toStringAsFixed(0)} JD',
              const Color(0xFF5BA8FF))),
        ]),
        SizedBox(height: 2.h),

        // ── Coach coverage ─────────────────────────────────────────────────
        _perfSection('COACH COVERAGE'),
        _statBar('Assigned', total - noCoach, total, const Color(0xFF5BA8FF)),
        _statBar('No coach', noCoach, total, Colors.white30),
        SizedBox(height: 2.h),

        // ── Goal distribution ──────────────────────────────────────────────
        if (goalCounts.isNotEmpty) ...[
          _perfSection('GOAL DISTRIBUTION'),
          ...goalCounts.entries.map((e) {
            final label = {
              'build_muscle': 'Build Muscle 💪',
              'lose_fat':     'Lose Fat 🔥',
              'maintain':     'Maintain ⚖️',
              'get_fit':      'Get Fit 🏃',
            }[e.key] ?? e.key;
            return _statBar(label, e.value, total, const Color(0xFFBF5AF2));
          }),
          SizedBox(height: 2.h),
        ],

        // ── Avg body metrics ───────────────────────────────────────────────
        if (withWeight.isNotEmpty) ...[
          _perfSection('AVG BODY METRICS'),
          Row(children: [
            Expanded(child: _kpiCard('Avg Weight',
                '${avgWeight.toStringAsFixed(1)} kg',
                Colors.white70)),
            SizedBox(width: 3.w),
            Expanded(child: _kpiCard('Avg BMI',
                withBMI.isEmpty ? '—' : avgBMI.toStringAsFixed(1),
                _bmiColor(avgBMI))),
          ]),
        ],
      ],
    );
  }

  Color _bmiColor(double bmi) {
    if (bmi <= 0)  return Colors.white38;
    if (bmi < 18.5) return const Color(0xFF5BA8FF);
    if (bmi < 25)   return const Color(0xFF34C759);
    if (bmi < 30)   return const Color(0xFFFF9500);
    return const Color(0xFFFF3B30);
  }

  Widget _perfSection(String title) => Padding(
        padding: EdgeInsets.only(bottom: 1.h, top: 0.5.h),
        child: Text(title,
            style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white38,
                letterSpacing: 0.5)),
      );

  Widget _statBar(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: EdgeInsets.only(bottom: 1.2.h),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white, fontSize: 10.sp,
                    fontWeight: FontWeight.w600)),
            Text('$count / $total',
                style: TextStyle(color: color, fontSize: 10.sp,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        SizedBox(height: 0.4.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ]),
    );
  }

  Widget _kpiCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16.sp, fontWeight: FontWeight.w800)),
        SizedBox(height: 0.3.h),
        Text(label,
            style: TextStyle(
                color: Colors.white54, fontSize: 9.sp,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Issues tab ────────────────────────────────────────────────────────────────

  Widget _buildIssuesTab(List<UserModel> players) {
    final now = DateTime.now();

    final expired = players.where((p) =>
        p.subscriptionEnd != null && p.subscriptionEnd!.isBefore(now)).toList();
    final expiringSoon = players.where((p) =>
        p.subscriptionEnd != null &&
        !p.subscriptionEnd!.isBefore(now) &&
        p.subscriptionEnd!.difference(now).inDays <= 7).toList();
    final unpaid = players.where((p) => (p.amountRemaining ?? 0) > 0)
        .toList()
      ..sort((a, b) =>
          (b.amountRemaining ?? 0).compareTo(a.amountRemaining ?? 0));
    final noCoach = players.where((p) =>
        p.assignedCoachUid == null || p.assignedCoachUid!.isEmpty).toList();
    final suspended = players.where((p) => !p.isActive).toList();

    final totalIssues = expired.length + expiringSoon.length +
        unpaid.length + noCoach.length + suspended.length;

    if (totalIssues == 0) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('✅', style: TextStyle(fontSize: 48.sp)),
          SizedBox(height: 2.h),
          Text('No issues found',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700)),
          SizedBox(height: 0.5.h),
          Text('All players are in good standing',
              style:
                  TextStyle(color: Colors.white38, fontSize: 11.sp)),
        ]),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 12.h),
      children: [
        // ── Summary chips ──────────────────────────────────────────────────
        Wrap(spacing: 2.w, runSpacing: 1.h, children: [
          if (expired.isNotEmpty)
            _issueChip('${expired.length} Expired', const Color(0xFFFF3B30)),
          if (expiringSoon.isNotEmpty)
            _issueChip('${expiringSoon.length} Expiring', const Color(0xFFFF9500)),
          if (unpaid.isNotEmpty)
            _issueChip('${unpaid.length} Unpaid', const Color(0xFFFFCC00)),
          if (noCoach.isNotEmpty)
            _issueChip('${noCoach.length} No Coach', const Color(0xFF5BA8FF)),
          if (suspended.isNotEmpty)
            _issueChip('${suspended.length} Suspended', Colors.white38),
        ]),
        SizedBox(height: 2.h),

        // ── Expired subscriptions ──────────────────────────────────────────
        if (expired.isNotEmpty) ...[
          _issueSection('🔴 EXPIRED SUBSCRIPTIONS', expired.length),
          ...expired.map((p) => _issuePlayerRow(
              p,
              '${p.subscriptionEnd!.difference(now).inDays.abs()}d ago',
              const Color(0xFFFF3B30))),
          SizedBox(height: 1.5.h),
        ],

        // ── Expiring soon ──────────────────────────────────────────────────
        if (expiringSoon.isNotEmpty) ...[
          _issueSection('🟠 EXPIRING IN ≤ 7 DAYS', expiringSoon.length),
          ...expiringSoon.map((p) {
            final days = p.subscriptionEnd!.difference(now).inDays;
            return _issuePlayerRow(
                p,
                days == 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}',
                const Color(0xFFFF9500));
          }),
          SizedBox(height: 1.5.h),
        ],

        // ── Unpaid balances ────────────────────────────────────────────────
        if (unpaid.isNotEmpty) ...[
          _issueSection('💰 UNPAID BALANCES', unpaid.length),
          ...unpaid.take(10).map((p) => _issuePlayerRow(
              p,
              '${(p.amountRemaining ?? 0).toStringAsFixed(0)} JD owed',
              const Color(0xFFFFCC00))),
          if (unpaid.length > 10)
            Padding(
              padding: EdgeInsets.only(left: 2.w, bottom: 0.5.h),
              child: Text('+ ${unpaid.length - 10} more',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 10.sp)),
            ),
          SizedBox(height: 1.5.h),
        ],

        // ── No coach ──────────────────────────────────────────────────────
        if (noCoach.isNotEmpty) ...[
          _issueSection('👤 NO COACH ASSIGNED', noCoach.length),
          ...noCoach.map((p) =>
              _issuePlayerRow(p, 'Unassigned', const Color(0xFF5BA8FF))),
          SizedBox(height: 1.5.h),
        ],

        // ── Suspended ─────────────────────────────────────────────────────
        if (suspended.isNotEmpty) ...[
          _issueSection('⛔ SUSPENDED ACCOUNTS', suspended.length),
          ...suspended.map((p) =>
              _issuePlayerRow(p, 'Suspended', Colors.white38)),
        ],
      ],
    );
  }

  Widget _issueChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.7.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5.w),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _issueSection(String title, int count) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Text('$title ($count)',
          style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white38,
              letterSpacing: 0.4)),
    );
  }

  Widget _issuePlayerRow(UserModel p, String tag, Color tagColor) {
    final name =
        '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
    return Container(
      margin: EdgeInsets.only(bottom: 0.8.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(2.5.w),
        border: Border.all(
            color: Colors.white.withOpacity(0.07), width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 8.w, height: 8.w,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Text(
            name.isEmpty ? p.email : name,
            style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(1.5.w),
          ),
          child: Text(tag,
              style: TextStyle(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w700,
                  color: tagColor)),
        ),
      ]),
    );
  }

  // ── Player row ────────────────────────────────────────────────────────────────

  Widget _buildPlayerRow(
      BuildContext context, WidgetRef ref, UserModel player, String gymId) {
    final now = DateTime.now();
    bool isExpiring = false;
    int daysLeft = 999;
    if (player.subscriptionEnd != null) {
      daysLeft = player.subscriptionEnd!.difference(now).inDays;
      if (daysLeft >= 0 && daysLeft <= 7) isExpiring = true;
    }

    final borderColor = isExpiring
        ? const Color(0xFFFF9500)
        : (player.isActive
            ? const Color(0xFF34C759)
            : const Color(0xFFFF3B30));
    final badgeColor =
        isExpiring ? const Color(0xFFFF9500) : const Color(0xFF5BA8FF);

    return GestureDetector(
      onTap: () => _showPlayerDetailSheet(context, ref, player, gymId),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
          borderRadius: BorderRadius.circular(3.5.w),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3.5.w),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored left accent bar
                Container(width: 3, color: borderColor),
                // Card content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(3.w),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 11.w,
                          height: 11.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${player.firstName?.isNotEmpty == true ? player.firstName![0] : '?'}'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: borderColor,
                            ),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        // Name + status + coach
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${player.firstName ?? ''} ${player.lastName ?? ''}'.trim().isEmpty
                                    ? player.email
                                    : '${player.firstName ?? ''} ${player.lastName ?? ''}'.trim(),
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 0.3.h),
                              Text(
                                isExpiring
                                    ? 'Expires in $daysLeft days ⚠️'
                                    : (player.isActive ? 'Active' : 'Suspended'),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: isExpiring
                                      ? const Color(0xFFFF9500)
                                      : (player.isActive
                                          ? Colors.white54
                                          : const Color(0xFFFF3B30)),
                                ),
                              ),
                              SizedBox(height: 0.2.h),
                              Row(
                                children: [
                                  Icon(Icons.fitness_center_rounded,
                                      size: 10.sp, color: Colors.white24),
                                  SizedBox(width: 1.w),
                                  Flexible(
                                    child: Text(
                                      player.assignedCoachName?.trim().isNotEmpty == true
                                          ? player.assignedCoachName!
                                          : 'No coach',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: player.assignedCoachName?.trim().isNotEmpty == true
                                            ? const Color(0xFF5BA8FF)
                                            : Colors.white38,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 2.w),
                        // Plan badge + date + chevron
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 2.w, vertical: 0.5.h),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(2.w),
                              ),
                              child: Text(
                                player.subscriptionPlan ?? 'Basic',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              player.subscriptionEnd != null
                                  ? DateFormat('MMM d').format(player.subscriptionEnd!)
                                  : '-',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Icon(Icons.chevron_right_rounded,
                                color: Colors.white30, size: 14.sp),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Player detail bottom sheet ────────────────────────────────────────────────

  void _showPlayerDetailSheet(
      BuildContext context, WidgetRef ref, UserModel player, String gymId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerDetailSheet(
        player: player,
        gymId: gymId,
        adminRepo: ref.read(adminRepositoryProvider),
        onRefresh: () => ref.invalidate(adminPlayersProvider(gymId)),
      ),
    );
  }

  // ── Add player bottom sheet ───────────────────────────────────────────────────

  void _showAddPlayerSheet(
      BuildContext context, WidgetRef ref, String gymId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPlayerSheet(
        gymId: gymId,
        onAdded: () => ref.invalidate(adminPlayersProvider(gymId)),
      ),
    );
  }
}

// ─── Player Detail Sheet ──────────────────────────────────────────────────────

class _PlayerDetailSheet extends ConsumerStatefulWidget {
  final UserModel player;
  final String gymId;
  final AdminRepository adminRepo;
  final VoidCallback onRefresh;

  const _PlayerDetailSheet({
    required this.player,
    required this.gymId,
    required this.adminRepo,
    required this.onRefresh,
  });

  @override
  ConsumerState<_PlayerDetailSheet> createState() =>
      _PlayerDetailSheetState();
}

class _PlayerDetailSheetState extends ConsumerState<_PlayerDetailSheet> {
  bool _loading = false;

  // ── Freeze / Unfreeze Subscription ───────────────────────────────────────────

  Future<void> _showFreezeDialog() async {
    final p = widget.player;
    if (p.isFrozen) {
      // Unfreeze
      final confirm = await _confirm(
        'Unfreeze Subscription?',
        'Subscription end date will be extended by ${p.freezeDays} day(s) to compensate.',
      );
      if (!confirm) return;
      setState(() => _loading = true);
      try {
        await widget.adminRepo.unfreezePlayerSubscription(
          gymId: widget.gymId,
          playerUid: p.uid,
          currentSubscriptionEnd: p.subscriptionEnd ?? DateTime.now(),
          frozenDays: p.freezeDays,
        );
        widget.onRefresh();
        if (mounted) Navigator.pop(context);
        _snack('Subscription unfrozen ✅ — end date extended by ${p.freezeDays} days');
      } catch (e) {
        _snack('Error: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      // Show freeze dialog
      int days = 7;
      String reason = 'travel';
      await showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDlg) => AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              title: Text('Freeze Subscription',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Freeze duration (days):',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 14.sp)),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () =>
                            setDlg(() => days = (days - 1).clamp(1, 180)),
                        icon: Icon(Icons.remove_circle_outline,
                            color: Colors.white70, size: 28.sp),
                      ),
                      Text('$days',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w800)),
                      IconButton(
                        onPressed: () =>
                            setDlg(() => days = (days + 1).clamp(1, 180)),
                        icon: Icon(Icons.add_circle_outline,
                            color: Colors.white70, size: 28.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text('Reason:',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 14.sp)),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['travel', 'injury', 'personal', 'other']
                        .map((r) {
                      return GestureDetector(
                        onTap: () => setDlg(() => reason = r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: reason == r
                                ? const Color(0xFF5BA8FF)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(r,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: TextStyle(color: Colors.white54, fontSize: 15.sp))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Freeze',
                        style: TextStyle(color: const Color(0xFF5BA8FF), fontSize: 15.sp))),
              ],
            ),
          );
        },
      ).then((confirmed) async {
        if (confirmed != true) return;
        setState(() => _loading = true);
        try {
          await widget.adminRepo.freezePlayerSubscription(
            gymId: widget.gymId,
            playerUid: p.uid,
            freezeDays: days,
            reason: reason,
          );
          widget.onRefresh();
          if (mounted) Navigator.pop(context);
          _snack('Subscription frozen ❄️ for $days day(s)');
        } catch (e) {
          _snack('Error: $e');
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      });
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(title,
            style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700)),
        content: Text(body,
            style: TextStyle(
                color: Colors.white70, fontSize: 11.sp)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
    return result == true;
  }

  // ── Suspend / Reactivate ──────────────────────────────────────────────────────

  Future<void> _toggleStatus() async {
    final suspending = widget.player.isActive;
    final newActive  = !suspending;
    setState(() => _loading = true);
    try {
      await widget.adminRepo.updatePlayerStatus(
        gymId: widget.gymId,
        uid:   widget.player.uid,
        isActive: newActive,
      );

      // ── إشعار للاعب ──────────────────────────────────────────────────────
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.player.uid)
          .collection('notifications')
          .add({
        'type':      suspending ? 'account_suspended' : 'account_reactivated',
        'title':     suspending ? 'Account Suspended'  : 'Account Reactivated',
        'body':      suspending
            ? 'Your gym account has been temporarily suspended. Please contact your gym admin for more information.'
            : 'Your gym account has been reactivated. Welcome back! 🎉',
        'senderId':  adminUid,
        'isRead':    false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      widget.onRefresh();
      if (mounted) Navigator.pop(context);
      _snack(newActive ? 'Player reactivated ✅' : 'Player suspended 🔴');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Assign Coach ──────────────────────────────────────────────────────────────

  Future<void> _showAssignCoach() async {
    final coachesAsync =
        ref.watch(adminCoachesProvider(widget.gymId));
    final coaches = coachesAsync.asData?.value ?? [];

    if (coaches.isEmpty) {
      _snack('No coaches found in this gym');
      return;
    }

    final selected = await showDialog<UserModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('Assign Coach',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: coaches.length,
            itemBuilder: (_, i) {
              final c = coaches[i];
              final name =
                  '${c.firstName ?? ''} ${c.lastName ?? ''}'.trim();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(name,
                    style:
                        const TextStyle(color: Colors.white)),
                subtitle: Text(c.email,
                    style: TextStyle(
                        color: Colors.white54, fontSize: 12.sp)),
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          if (widget.player.assignedCoachUid != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.adminRepo.removeCoachFromPlayer(
                    playerUid: widget.player.uid, gymId: widget.gymId);
                widget.onRefresh();
                _snack('Coach removed');
              },
              child: const Text('Remove Coach',
                  style: TextStyle(color: Color(0xFFFF3B30))),
            ),
        ],
      ),
    );

    if (selected == null) return;
    setState(() => _loading = true);
    try {
      final coachName =
          '${selected.firstName ?? ''} ${selected.lastName ?? ''}'.trim();
      await widget.adminRepo.assignCoachToPlayer(
        playerUid: widget.player.uid,
        coachUid: selected.uid,
        coachName: coachName,
        gymId: widget.gymId,
      );
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
      _snack('Coach assigned ✅');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Update Subscription ───────────────────────────────────────────────────────

  void _showUpdateSubscription() {
    final adminUid = ref.read(currentUserModelProvider).asData?.value?.uid ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateSubscriptionSheet(
        player: widget.player,
        adminRepo: widget.adminRepo,
        gymId: widget.gymId,
        adminUid: adminUid,
        onUpdated: () {
          widget.onRefresh();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
    final isExpired = p.subscriptionEnd?.isBefore(DateTime.now()) == true;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w,
          MediaQuery.of(context).viewInsets.bottom + 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 12.w,
            height: 4,
            margin: EdgeInsets.only(bottom: 2.h),
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10)),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 14.w,
                height: 14.w,
                decoration: const BoxDecoration(
                    color: Color(0xFF2C2C2E), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('🧑', style: TextStyle(fontSize: 22.sp)),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? p.email : name,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 0.5.h),
                    Text(p.email,
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12.sp)),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 3.w, vertical: 0.6.h),
                decoration: BoxDecoration(
                  color: (p.isActive && !isExpired)
                      ? Colors.green.withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text(
                  isExpired
                      ? 'Expired'
                      : (p.isActive ? 'Active' : 'Suspended'),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: (p.isActive && !isExpired)
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 2.h),
          Divider(color: Colors.white.withOpacity(0.08)),
          SizedBox(height: 2.h),

          // Info grid
          _buildInfoGrid(p, isExpired),

          SizedBox(height: 1.5.h),
          Builder(builder: (_) {
            final total = p.totalAmount ?? 0.0;
            final paid = p.amountPaid ?? 0.0;
            final remaining = p.amountRemaining ?? 0.0;
            final bool noData = total <= 0;
            final double pct =
                noData ? 0.0 : (paid / total).clamp(0.0, 1.0);
            final Color barColor = noData
                ? Colors.white24
                : remaining <= 0
                    ? const Color(0xFF34C759)
                    : paid <= 0
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFFFF9500);
            return ClipRRect(
              borderRadius: BorderRadius.circular(1.w),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(barColor),
                minHeight: 6,
              ),
            );
          }),

          SizedBox(height: 3.h),

          // Action buttons
          if (_loading)
            const CircularProgressIndicator(color: Color(0xFFFF3B30))
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _actionBtn(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Assign Coach',
                            color: const Color(0xFF5BA8FF),
                            onTap: _showAssignCoach)),
                    SizedBox(width: 3.w),
                    Expanded(
                        child: _actionBtn(
                            icon: p.isActive
                                ? Icons.block_rounded
                                : Icons.check_circle_rounded,
                            label:
                                p.isActive ? 'Suspend' : 'Reactivate',
                            color: p.isActive
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFF34C759),
                            onTap: _toggleStatus)),
                  ],
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w)),
                    ),
                    onPressed: _showUpdateSubscription,
                    icon: const Icon(Icons.credit_card_rounded,
                        color: Color(0xFFFF9500)),
                    label: Text('Update Subscription',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.player.isFrozen
                          ? const Color(0xFF34C759).withOpacity(0.12)
                          : const Color(0xFF5BA8FF).withOpacity(0.12),
                      side: BorderSide(
                        color: widget.player.isFrozen
                            ? const Color(0xFF34C759).withOpacity(0.5)
                            : const Color(0xFF5BA8FF).withOpacity(0.5),
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w)),
                    ),
                    onPressed: _showFreezeDialog,
                    icon: Icon(
                      widget.player.isFrozen
                          ? Icons.play_circle_rounded
                          : Icons.ac_unit_rounded,
                      color: widget.player.isFrozen
                          ? const Color(0xFF34C759)
                          : const Color(0xFF5BA8FF),
                    ),
                    label: Text(
                      widget.player.isFrozen
                          ? 'Unfreeze (${widget.player.freezeDays}d frozen)'
                          : 'Freeze Subscription ❄️',
                      style: TextStyle(
                          color: widget.player.isFrozen
                              ? const Color(0xFF34C759)
                              : const Color(0xFF5BA8FF),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30).withOpacity(0.12),
                      side: BorderSide(
                          color: const Color(0xFFFF3B30).withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w)),
                    ),
                    onPressed: _deletePlayer,
                    icon: const Icon(Icons.delete_forever_rounded,
                        color: Color(0xFFFF3B30)),
                    label: Text('حذف المستخدم',
                        style: TextStyle(
                            color: const Color(0xFFFF3B30),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _deletePlayer() async {
    final p = widget.player;
    final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('حذف المستخدم',
            style: TextStyle(
                color: const Color(0xFFFF3B30),
                fontSize: 14.sp,
                fontWeight: FontWeight.w700)),
        content: Text(
          'هل أنت متأكد من حذف "${name.isEmpty ? p.email : name}" نهائياً؟\n\nسيتم حذف بيانات اللاعب من النظام ولا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: Colors.white70, fontSize: 11.sp),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف نهائياً',
                  style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await widget.adminRepo.deletePlayer(
        gymId: widget.gymId,
        playerUid: p.uid,
        playerEmail: p.email,
      );
      widget.onRefresh();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف ${name.isEmpty ? p.email : name} بنجاح'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildInfoGrid(UserModel p, bool isExpired) {
    final rows = <MapEntry<String, String>>[
      MapEntry(
          'Coach',
          p.assignedCoachName?.trim().isNotEmpty == true
              ? p.assignedCoachName!
              : 'Unassigned'),
      MapEntry('Plan', p.subscriptionPlan ?? 'None'),
      MapEntry(
          'Expires',
          p.subscriptionEnd != null
              ? DateFormat('MMM d, yyyy').format(p.subscriptionEnd!)
              : '—'),
      MapEntry('Paid',
          '${(p.amountPaid ?? 0).toStringAsFixed(0)} JD'),
      MapEntry('Remaining',
          '${(p.amountRemaining ?? 0).toStringAsFixed(0)} JD'),
    ];
    return Column(
      children: rows
          .map((e) => Padding(
                padding: EdgeInsets.symmetric(vertical: 0.8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key,
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600)),
                    Text(e.value,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(3.w),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18.sp),
            SizedBox(height: 0.6.h),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─── Update Subscription Sheet ────────────────────────────────────────────────

class _UpdateSubscriptionSheet extends StatefulWidget {
  final UserModel player;
  final AdminRepository adminRepo;
  final VoidCallback onUpdated;
  final String gymId;
  final String adminUid;

  const _UpdateSubscriptionSheet({
    required this.player,
    required this.adminRepo,
    required this.onUpdated,
    required this.gymId,
    required this.adminUid,
  });

  @override
  State<_UpdateSubscriptionSheet> createState() =>
      _UpdateSubscriptionSheetState();
}

class _UpdateSubscriptionSheetState extends State<_UpdateSubscriptionSheet> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _plan = 'Basic';
  String _paymentMethod = 'cash';
  final _totalCtrl = TextEditingController();
  final _paidCtrl = TextEditingController();
  bool _saving = false;

  // Valid options — must match the DropdownButtonFormField items below
  static const _planOptions = ['Basic', 'Pro', 'Elite', 'Custom'];
  static const _methodOptions = [
    'cash', 'visa', 'bank_transfer', 'cliq', 'wallet'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _startDate = p.subscriptionStart ?? DateTime.now();
    _endDate = p.subscriptionEnd ??
        DateTime(DateTime.now().year, DateTime.now().month + 1,
            DateTime.now().day);
    // Guard: if the stored plan isn't in our list, fall back to 'Custom'
    final stored = p.subscriptionPlan ?? '';
    _plan = _planOptions.contains(stored) ? stored : 'Custom';
    final storedMethod = p.paymentMethod ?? '';
    _paymentMethod =
        _methodOptions.contains(storedMethod) ? storedMethod : 'cash';
    _totalCtrl.text = (p.totalAmount ?? 0).toStringAsFixed(0);
    _paidCtrl.text  = (p.amountPaid  ?? 0).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _paidCtrl.dispose();
    super.dispose();
  }

  double get _remaining =>
      ((double.tryParse(_totalCtrl.text) ?? 0) -
              (double.tryParse(_paidCtrl.text) ?? 0))
          .clamp(0.0, double.infinity);

  Future<void> _save() async {
    final total = double.tryParse(_totalCtrl.text) ?? 0;
    final paid = double.tryParse(_paidCtrl.text) ?? 0;
    if (total <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      final playerName =
          '${widget.player.firstName ?? ''} ${widget.player.lastName ?? ''}'
              .trim();
      await widget.adminRepo.updatePlayerSubscription(
        playerUid: widget.player.uid,
        plan: _plan,
        startDate: _startDate,
        endDate: _endDate,
        totalAmount: total,
        amountPaid: paid,
        paymentMethod: _paymentMethod,
        gymId: widget.gymId,
        playerName: playerName.isEmpty ? widget.player.email : playerName,
        registeredByUid: widget.adminUid,
      );
      widget.onUpdated();
      if (mounted) Navigator.pop(context);
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
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w,
          MediaQuery.of(context).viewInsets.bottom + 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 12.w,
                height: 4,
                margin: EdgeInsets.only(bottom: 2.h),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text('Update Subscription',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 0.5.h),
            Text(
                '${widget.player.firstName ?? ''} ${widget.player.lastName ?? ''}'
                    .trim(),
                style:
                    TextStyle(color: Colors.white54, fontSize: 13.sp)),
            SizedBox(height: 3.h),

            // Plan
            _label('Plan'),
            SizedBox(height: 1.h),
            DropdownButtonFormField<String>(
              value: _plan,
              dropdownColor: const Color(0xFF2C2C2E),
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              decoration: _inputDeco(),
              items: _planOptions
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (v) => setState(() => _plan = v ?? _plan),
            ),

            SizedBox(height: 2.h),

            // Dates
            Row(
              children: [
                Expanded(child: _datePicker('Start', _startDate, (d) {
                  setState(() => _startDate = d);
                })),
                SizedBox(width: 3.w),
                Expanded(child: _datePicker('End', _endDate, (d) {
                  setState(() => _endDate = d);
                })),
              ],
            ),

            SizedBox(height: 2.h),

            // Payment method
            _label('Payment Method'),
            SizedBox(height: 1.h),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              dropdownColor: const Color(0xFF2C2C2E),
              style: TextStyle(color: Colors.white, fontSize: 14.sp),
              decoration: _inputDeco(),
              items: _methodOptions
                  .map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v,
                          style: const TextStyle(color: Colors.white))))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _paymentMethod = v ?? _paymentMethod),
            ),

            SizedBox(height: 2.h),

            // Amounts
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _totalCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    decoration:
                        _inputDeco(label: 'Total Amount (\$)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: TextField(
                    controller: _paidCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    decoration: _inputDeco(label: 'Amount Paid (\$)'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            SizedBox(height: 1.5.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Remaining',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 13.sp)),
                  Text('${_remaining.toStringAsFixed(0)} JD',
                      style: TextStyle(
                          color: _remaining > 0
                              ? const Color(0xFFFF9500)
                              : const Color(0xFF34C759),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),

            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Save Changes',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: Colors.white54,
          fontSize: 10.sp,
          fontWeight: FontWeight.w600));

  InputDecoration _inputDeco({String? label}) => InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white54, fontSize: 12.sp),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2.5.w),
          borderSide: BorderSide.none,
        ),
      );

  Widget _datePicker(
      String label, DateTime date, void Function(DateTime) onPick) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark(),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(2.5.w),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white54, fontSize: 11.sp)),
            SizedBox(height: 0.4.h),
            Text(DateFormat('MMM d, yyyy').format(date),
                style: TextStyle(
                    color: const Color(0xFF5BA8FF),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─── Add Player Sheet (full form — same fields as coach) ──────────────────────

class _AddPlayerSheet extends ConsumerStatefulWidget {
  final String gymId;
  final VoidCallback onAdded;

  const _AddPlayerSheet({required this.gymId, required this.onAdded});

  @override
  ConsumerState<_AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends ConsumerState<_AddPlayerSheet> {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _firstCtrl      = TextEditingController();
  final _lastCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _weightCtrl     = TextEditingController();
  final _heightCtrl     = TextEditingController();
  final _bodyFatCtrl    = TextEditingController();
  final _muscleMassCtrl = TextEditingController();
  final _planCtrl       = TextEditingController(text: 'Standard');
  final _durationCtrl   = TextEditingController(text: '1');
  final _totalCtrl      = TextEditingController();
  final _discountCtrl   = TextEditingController(text: '0');
  final _paidCtrl       = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────────
  DateTime? _birthDate;
  DateTime  _startDate = DateTime.now();
  String _goal          = 'build_muscle';
  String _gender        = 'male';
  String _fitnessLevel  = 'beginner';
  String _trainingMode  = 'gym_only';
  String _paymentMethod = 'cash';
  bool   _saving        = false;
  bool   _obscurePassword = true;
  // Coach picker — null means "no coach assigned"
  UserModel? _selectedCoach;

  // ── Phone OTP state ───────────────────────────────────────────────────────────
  final _otpCtrl        = TextEditingController();
  String? _verificationId;
  int?    _resendToken;
  bool    _phoneChecking = false;
  bool    _otpSent       = false;
  bool    _otpVerifying  = false;
  bool    _phoneVerified = false;
  String? _phoneError;
  Timer?  _resendTimer;
  int     _resendSeconds = 0;

  // ── Subscription plan picker ──────────────────────────────────────────────────
  Map<String, dynamic>? _selectedPlan; // null = custom
  bool _useCustomPlan = false;
  DateTime? _endDate; // auto-set when plan selected; manual when custom

  @override
  void initState() {
    super.initState();
    _passwordCtrl.text = _generatePassword();
  }

  String _generatePassword() {
    const upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower   = 'abcdefghjkmnpqrstuvwxyz';
    const digits  = '23456789';
    const special = '@#!%&*';
    final rng = Random.secure();
    final chars = [
      upper[rng.nextInt(upper.length)],
      upper[rng.nextInt(upper.length)],
      lower[rng.nextInt(lower.length)],
      lower[rng.nextInt(lower.length)],
      lower[rng.nextInt(lower.length)],
      lower[rng.nextInt(lower.length)],
      digits[rng.nextInt(digits.length)],
      digits[rng.nextInt(digits.length)],
      special[rng.nextInt(special.length)],
    ]..shuffle(rng);
    return chars.join();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _bodyFatCtrl.dispose();
    _muscleMassCtrl.dispose();
    _planCtrl.dispose();
    _durationCtrl.dispose();
    _totalCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Phone OTP helpers ─────────────────────────────────────────────────────────

  String _normalizePhone(String input) {
    var v = input.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (v.startsWith('00')) v = '+${v.substring(2)}';
    if (v.startsWith('+')) return v;
    if (v.startsWith('962')) return '+$v';
    if (v.startsWith('0')) return '+962${v.substring(1)}';
    return '+962$v';
  }

  void _startOtpCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendPhoneOtp({bool isResend = false}) async {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _phoneError = 'أدخل رقم الهاتف أولاً');
      return;
    }
    setState(() { _phoneChecking = true; _phoneVerified = false; _phoneError = null; });

    try {
      final normalized = _normalizePhone(raw);
      _phoneCtrl.text = normalized;

      if (kDebugMode) {
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalized,
        forceResendingToken: isResend ? _resendToken : null,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          await _verifyPhoneCredential(credential);
        },
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() { _phoneChecking = false; _phoneError = e.message ?? 'فشل إرسال الرمز'; });
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken    = resendToken;
            _otpSent        = true;
            _phoneChecking  = false;
            _phoneError     = null;
          });
          _startOtpCountdown();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _phoneChecking = false; _phoneError = '$e'; });
    }
  }

  Future<void> _verifyOtpCode() async {
    final vid  = _verificationId;
    final code = _otpCtrl.text.trim();
    if (vid == null || code.length < 4) {
      setState(() => _phoneError = 'أدخل رمز التحقق');
      return;
    }
    await _verifyPhoneCredential(
      PhoneAuthProvider.credential(verificationId: vid, smsCode: code),
    );
  }

  Future<void> _verifyPhoneCredential(PhoneAuthCredential credential) async {
    setState(() { _otpVerifying = true; _phoneError = null; });
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'PhoneVerifyAdmin_${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      await secondaryAuth.signInWithCredential(credential);
      await secondaryAuth.signOut();
      if (!mounted) return;
      setState(() { _otpVerifying = false; _phoneVerified = true; _phoneError = null; });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'provider-already-linked' || e.code == 'credential-already-in-use') {
        setState(() { _otpVerifying = false; _phoneVerified = true; _phoneError = null; });
        return;
      }
      setState(() { _otpVerifying = false; _phoneError = e.message ?? 'رمز غير صحيح'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _otpVerifying = false; _phoneError = '$e'; });
    } finally {
      secondaryApp?.delete().catchError((_) {});
    }
  }

  Widget _buildPhoneOtpWidget() {
    // Web doesn't support Firebase Phone Auth without reCAPTCHA setup —
    // just show the plain phone field and mark as verified automatically.
    if (kIsWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(_phoneCtrl, 'Phone *', type: TextInputType.phone),
          SizedBox(height: 0.4.h),
          Text('التحقق عبر OTP غير متاح على الويب',
              style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
                onChanged: (_) {
                  if (_phoneVerified) setState(() { _phoneVerified = false; _otpSent = false; });
                },
                decoration: InputDecoration(
                  labelText: 'Phone *',
                  labelStyle: TextStyle(color: Colors.white54, fontSize: 10.sp),
                  filled: true,
                  fillColor: _phoneVerified
                      ? const Color(0xFF34C759).withOpacity(0.12)
                      : Colors.white.withOpacity(0.07),
                  contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2.5.w),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2.5.w),
                    borderSide: _phoneVerified
                        ? const BorderSide(color: Color(0xFF34C759), width: 1.5)
                        : BorderSide.none,
                  ),
                  suffixIcon: _phoneVerified
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759))
                      : null,
                ),
              ),
            ),
            SizedBox(width: 2.w),
            GestureDetector(
              onTap: _phoneChecking ? null : () => _sendPhoneOtp(isResend: _otpSent),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2.5.w),
                  border: Border.all(color: const Color(0xFF007AFF).withOpacity(0.4)),
                ),
                child: _phoneChecking
                    ? SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          color: const Color(0xFF007AFF), strokeWidth: 2))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.send_rounded, color: const Color(0xFF007AFF), size: 13.sp),
                          SizedBox(width: 1.w),
                          Text(
                            _otpSent ? 'إعادة إرسال' : 'إرسال كود',
                            style: TextStyle(
                                color: const Color(0xFF007AFF),
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),

        // OTP input — shown after code is sent
        if (_otpSent && !_phoneVerified) ...[
          SizedBox(height: 1.h),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 6,
                  style: TextStyle(
                      color: Colors.white, fontSize: 18.sp,
                      fontWeight: FontWeight.w700, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '- - - - - -',
                    hintStyle: TextStyle(
                        color: Colors.white24, fontSize: 16.sp, letterSpacing: 8),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.07),
                    contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2.5.w),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              GestureDetector(
                onTap: _otpVerifying ? null : _verifyOtpCode,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2.5.w),
                    border: Border.all(color: const Color(0xFF34C759).withOpacity(0.4)),
                  ),
                  child: _otpVerifying
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: const Color(0xFF34C759), strokeWidth: 2))
                      : Text('تحقق',
                          style: TextStyle(
                              color: const Color(0xFF34C759),
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          if (_resendSeconds > 0)
            Padding(
              padding: EdgeInsets.only(top: 0.5.h),
              child: Text(
                'إعادة الإرسال بعد $_resendSeconds ثانية',
                style: TextStyle(color: Colors.white38, fontSize: 9.sp),
              ),
            ),
        ],

        // Error
        if (_phoneError != null)
          Padding(
            padding: EdgeInsets.only(top: 0.5.h),
            child: Text(_phoneError!,
                style: TextStyle(color: const Color(0xFFFF3B30), fontSize: 9.sp)),
          ),

        // Verified badge
        if (_phoneVerified)
          Padding(
            padding: EdgeInsets.only(top: 0.5.h),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 14),
              SizedBox(width: 1.w),
              Text('تم التحقق من الرقم',
                  style: TextStyle(color: const Color(0xFF34C759), fontSize: 9.sp, fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  /// Recalculates _endDate from _startDate + selected plan's durationDays.
  void _recalcEndDate() {
    if (_selectedPlan != null && !_useCustomPlan) {
      final days = _selectedPlan!['durationDays'] as int? ?? 30;
      setState(() {
        _endDate = _startDate.add(Duration(days: days));
      });
    }
  }

  // ── Plan picker widget ────────────────────────────────────────────────────────
  Widget _buildPlanPicker() {
    final plansAsync = ref.watch(subscriptionPlansProvider(widget.gymId));
    final plans = plansAsync.asData?.value ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Plan chips row ────────────────────────────────────────────────
        Wrap(
          spacing: 2.w,
          runSpacing: 1.h,
          children: [
            ...plans.map((plan) {
              final isSelected = !_useCustomPlan &&
                  _selectedPlan != null &&
                  _selectedPlan!['id'] == plan['id'];
              final name  = plan['name'] as String? ?? '';
              final days  = plan['durationDays'] as int? ?? 30;
              final price = (plan['price'] as num?)?.toDouble() ?? 0.0;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPlan  = plan;
                    _useCustomPlan = false;
                    _planCtrl.text = name;
                    _durationCtrl.text = (days / 30).round().clamp(1, 999).toString();
                    _totalCtrl.text = price.toStringAsFixed(0);
                    _endDate = _startDate.add(Duration(days: days));
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFF3B30)
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFFF3B30)
                          : Colors.white.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700)),
                      Text(
                        '$days يوم · ${price.toStringAsFixed(0)} JD',
                        style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.white38,
                            fontSize: 9.sp),
                      ),
                    ],
                  ),
                ),
              );
            }),
            // Custom option
            GestureDetector(
              onTap: () {
                setState(() {
                  _useCustomPlan = true;
                  _selectedPlan  = null;
                  _planCtrl.text = '';
                  _durationCtrl.text = '1';
                  _totalCtrl.text = '';
                  _endDate = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: _useCustomPlan
                      ? Colors.white.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _useCustomPlan
                        ? Colors.white54
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded,
                        color: _useCustomPlan ? Colors.white : Colors.white38,
                        size: 12.sp),
                    SizedBox(width: 1.w),
                    Text('مخصص',
                        style: TextStyle(
                            color: _useCustomPlan ? Colors.white : Colors.white38,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),

        if (plansAsync.isLoading) ...[
          SizedBox(height: 1.h),
          const Center(child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(color: Color(0xFFFF3B30), strokeWidth: 2))),
        ],

        // ── Custom plan name field ────────────────────────────────────────
        if (_useCustomPlan) ...[
          SizedBox(height: 1.5.h),
          _field(_planCtrl, 'اسم الخطة'),
        ],

        // ── End date display ──────────────────────────────────────────────
        SizedBox(height: 1.5.h),
        if (_selectedPlan != null && !_useCustomPlan && _endDate != null) ...[
          // Auto-calculated end date — read-only pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.08),
              borderRadius: BorderRadius.circular(2.5.w),
              border: Border.all(color: const Color(0xFF34C759).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded,
                    color: const Color(0xFF34C759), size: 18.sp),
                SizedBox(width: 3.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تاريخ انتهاء الاشتراك',
                        style: TextStyle(fontSize: 9.sp, color: Colors.white38)),
                    Text(
                      DateFormat('dd MMM yyyy').format(_endDate!),
                      style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF34C759)),
                    ),
                  ],
                ),
                const Spacer(),
                Text('تلقائي',
                    style: TextStyle(fontSize: 9.sp, color: Colors.white30)),
              ],
            ),
          ),
        ] else if (_useCustomPlan) ...[
          // Manual end date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                firstDate: _startDate,
                lastDate: DateTime(2100),
                builder: (ctx, child) => Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFFFF3B30),
                      surface: Color(0xFF1C1C1E),
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _endDate = picked);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: _endDate != null
                    ? const Color(0xFFFF3B30).withOpacity(0.08)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(2.5.w),
                border: Border.all(
                  color: _endDate != null
                      ? const Color(0xFFFF3B30).withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      color: _endDate != null
                          ? const Color(0xFFFF3B30)
                          : Colors.white38,
                      size: 18.sp),
                  SizedBox(width: 3.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تاريخ انتهاء الاشتراك *',
                          style: TextStyle(fontSize: 9.sp, color: Colors.white38)),
                      Text(
                        _endDate != null
                            ? DateFormat('dd MMM yyyy').format(_endDate!)
                            : 'اختر تاريخ الانتهاء',
                        style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: _endDate != null
                                ? const Color(0xFFFF3B30)
                                : Colors.white54),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white24, size: 10.sp),
                ],
              ),
            ),
          ),
        ],

        // ── Plan summary card ─────────────────────────────────────────────
        if (_selectedPlan != null && !_useCustomPlan) ...[
          SizedBox(height: 1.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.08),
              borderRadius: BorderRadius.circular(2.5.w),
              border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.card_membership_rounded,
                    color: const Color(0xFFFF3B30), size: 24.sp),
                SizedBox(width: 3.w),
                Expanded(
                  child: Text(
                    '${_selectedPlan!['name']} · '
                    '${_selectedPlan!['durationDays']} يوم · '
                    '${(_selectedPlan!['price'] as num?)?.toStringAsFixed(0) ?? '0'} JD',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Text('تعبئة تلقائية',
                    style: TextStyle(
                        color: const Color(0xFF34C759), fontSize: 13.sp)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _save() async {
    final first    = _firstCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final phone    = _phoneCtrl.text.trim();
    final weight      = double.tryParse(_weightCtrl.text.trim());
    final height      = double.tryParse(_heightCtrl.text.trim());
    final bodyFat     = double.tryParse(_bodyFatCtrl.text.trim());
    final muscleMass  = double.tryParse(_muscleMassCtrl.text.trim());
    final duration    = int.tryParse(_durationCtrl.text.trim());
    final totalAmount = double.tryParse(_totalCtrl.text.trim()) ?? 0.0;
    final discount    = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    final paid        = double.tryParse(_paidCtrl.text.trim()) ?? 0.0;

    if (_selectedPlan == null && !_useCustomPlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر خطة اشتراك أو اختر "مخصص"'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    if (_useCustomPlan && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اختر تاريخ انتهاء الاشتراك'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    if (first.isEmpty || email.isEmpty || password.length < 6 ||
        phone.isEmpty || _birthDate == null ||
        weight == null || weight <= 0 ||
        height == null || height <= 0 ||
        bodyFat == null || bodyFat < 0 ||
        muscleMass == null || muscleMass < 0 ||
        duration == null || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields (*)'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    if (!kIsWeb && !_phoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب التحقق من رقم الهاتف أولاً'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final input = AddPlayerInput(
        firstName:       first,
        lastName:        _lastCtrl.text.trim(),
        email:           email,
        password:        password,
        phone:           phone,
        dateOfBirth:     _birthDate!,
        assignedCoachUid:  _selectedCoach?.uid,
        assignedCoachName: _selectedCoach != null
            ? '${_selectedCoach!.firstName ?? ''} ${_selectedCoach!.lastName ?? ''}'.trim()
            : '',
        weight:          weight,
        height:          height,
        bodyFat:         bodyFat,
        muscleMass:      muscleMass,
        goal:            _goal,
        gender:          _gender,
        fitnessLevel:    _fitnessLevel,
        trainingMode:    _trainingMode,
        subscriptionPlan: _planCtrl.text.trim().isEmpty ? 'Standard' : _planCtrl.text.trim(),
        subscriptionStart: _startDate,
        durationMonths:  duration,
        subscriptionEnd: _endDate,
        totalAmount:     totalAmount,
        discountAmount:  discount,
        amountPaid:      paid,
        paymentMethod:   _paymentMethod,
        gymCode:         widget.gymId,
      );

      await ref.read(coachRepositoryProvider).addPlayer(input);

      widget.onAdded();
      if (mounted) {
        Navigator.pop(context);
        // Show credentials dialog so admin can copy/share
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _CredentialsDialog(
            name: '${_firstCtrl.text.trim()} ${_lastCtrl.text.trim()}'.trim(),
            email: email,
            password: password,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: const Color(0xFFFF3B30)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.95),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 12.w, height: 4,
            margin: EdgeInsets.symmetric(vertical: 1.5.h),
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10)),
          ),
          // Title row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.08),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white70, size: 18),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Register New Player',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800)),
                      Text('Full registration — creates login account',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12.sp)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Account ──────────────────────────────────────────────
                  _section('Account'),
                  _row([
                    _field(_firstCtrl, 'First Name *'),
                    _field(_lastCtrl, 'Last Name'),
                  ]),
                  SizedBox(height: 1.5.h),
                  _field(_emailCtrl, 'Email *',
                      type: TextInputType.emailAddress),
                  SizedBox(height: 1.5.h),
                  // ── Password field — show/hide + regenerate ──────────────
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: Colors.white, fontSize: 15.sp),
                    decoration: InputDecoration(
                      labelText: 'Temporary Password *',
                      labelStyle: TextStyle(color: Colors.white54, fontSize: 13.sp),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 1.5.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(2.5.w),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: Colors.white38,
                              size: 18,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded,
                                color: Color(0xFFFF9500), size: 18),
                            tooltip: 'Generate new password',
                            onPressed: () => setState(
                                () => _passwordCtrl.text = _generatePassword()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 0.6.h),
                  Text(
                    'Auto-generated — player must change on first login.',
                    style: TextStyle(color: Colors.white38, fontSize: 12.sp),
                  ),
                  SizedBox(height: 1.5.h),
                  // ── Phone + OTP ───────────────────────────────────────────
                  _buildPhoneOtpWidget(),
                  SizedBox(height: 1.5.h),
                  _datePicker(
                    label: 'Date of Birth *',
                    value: _birthDate,
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                    onPick: (d) => setState(() => _birthDate = d),
                  ),

                  // ── Coach ────────────────────────────────────────────────
                  _section('Assigned Coach'),
                  _buildCoachPicker(),

                  // ── Body Metrics ─────────────────────────────────────────
                  _section('Body Metrics'),
                  _row([
                    _field(_weightCtrl, 'Weight kg *',
                        type: TextInputType.number),
                    _field(_heightCtrl, 'Height cm *',
                        type: TextInputType.number),
                  ]),
                  SizedBox(height: 1.5.h),
                  _row([
                    _field(_bodyFatCtrl, 'Body Fat % *',
                        type: TextInputType.number),
                    _field(_muscleMassCtrl, 'Muscle Mass kg *',
                        type: TextInputType.number),
                  ]),

                  // ── Goal & Training ───────────────────────────────────────
                  _section('Goal & Training'),
                  _row([
                    _dropdown('Goal', _goal, {
                      'build_muscle': 'Build Muscle',
                      'lose_fat': 'Lose Fat',
                      'maintain': 'Maintain',
                      'get_fit': 'Get Fit',
                    }, (v) => setState(() => _goal = v)),
                    _dropdown('Gender', _gender, {
                      'male': 'Male',
                      'female': 'Female',
                    }, (v) => setState(() => _gender = v)),
                  ]),
                  SizedBox(height: 1.5.h),
                  _row([
                    _dropdown('Level', _fitnessLevel, {
                      'beginner': 'Beginner',
                      'intermediate': 'Intermediate',
                      'advanced': 'Advanced',
                    }, (v) => setState(() => _fitnessLevel = v)),
                    _dropdown('Training', _trainingMode, {
                      'gym_only': 'Gym Only',
                      'home_only': 'Home Only',
                      'hybrid': 'Hybrid',
                    }, (v) => setState(() => _trainingMode = v)),
                  ]),

                  // ── Subscription & Payment ────────────────────────────────
                  _section('Subscription & Payment'),
                  _buildPlanPicker(),
                  SizedBox(height: 1.5.h),
                  _datePicker(
                    label: 'Start Date',
                    value: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                    onPick: (d) {
                      setState(() => _startDate = d);
                      _recalcEndDate();
                    },
                  ),
                  SizedBox(height: 1.5.h),
                  _row([
                    // Duration field — shown always for context / fallback
                    _field(_durationCtrl, 'Duration (months) *',
                        type: TextInputType.number),
                    _field(_totalCtrl, 'Total Amount',
                        type: TextInputType.number),
                  ]),
                  SizedBox(height: 1.5.h),
                  _row([
                    _field(_discountCtrl, 'Discount',
                        type: TextInputType.number),
                    _field(_paidCtrl, 'Paid Now',
                        type: TextInputType.number),
                  ]),
                  SizedBox(height: 1.5.h),
                  _dropdown('Payment Method', _paymentMethod, {
                    'cash': 'Cash',
                    'zain_cash': 'Zain Cash',
                    'cliq': 'CliQ',
                    'card': 'Card',
                    'bank_transfer': 'Bank Transfer',
                  }, (v) => setState(() => _paymentMethod = v)),

                  SizedBox(height: 3.h),
                  SizedBox(
                    width: double.infinity,
                    height: 6.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3.w)),
                      ),
                      onPressed: (_saving || (!kIsWeb && !_phoneVerified)) ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!kIsWeb && !_phoneVerified)
                                  Padding(
                                    padding: EdgeInsets.only(left: 2.w),
                                    child: Icon(Icons.lock_rounded,
                                        color: Colors.white54, size: 14.sp),
                                  ),
                                Text(
                                  (!kIsWeb && !_phoneVerified)
                                      ? 'تحقق من الهاتف أولاً'
                                      : 'Register Player',
                                  style: TextStyle(
                                      color: (!kIsWeb && !_phoneVerified)
                                          ? Colors.white54
                                      : Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Widget _buildCoachPicker() {
    final coaches =
        ref.watch(adminCoachesProvider(widget.gymId)).asData?.value ?? [];
    final selectedName = _selectedCoach != null
        ? '${_selectedCoach!.firstName ?? ''} ${_selectedCoach!.lastName ?? ''}'
            .trim()
        : null;

    return GestureDetector(
      onTap: () async {
        final picked = await showDialog<UserModel?>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: Text('Assign Coach',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  // "No coach" option
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.white12,
                      child: Icon(Icons.person_off_rounded,
                          color: Colors.white54),
                    ),
                    title: Text('No coach',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 12.sp)),
                    onTap: () => Navigator.pop(ctx, null),
                  ),
                  if (coaches.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Text('No coaches available',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11.sp)),
                    ),
                  ...coaches.map((c) {
                    final name =
                        '${c.firstName ?? ''} ${c.lastName ?? ''}'.trim();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            const Color(0xFF5BA8FF).withOpacity(0.2),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFF5BA8FF)),
                        ),
                      ),
                      title: Text(name.isEmpty ? c.email : name,
                          style: TextStyle(
                              color: Colors.white, fontSize: 12.sp)),
                      subtitle: Text(c.email,
                          style: TextStyle(
                              color: Colors.white38, fontSize: 9.sp)),
                      onTap: () => Navigator.pop(ctx, c),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
        // null means user tapped "No coach" or dismissed — treat as no-coach
        if (picked != null || context.mounted) {
          setState(() => _selectedCoach = picked);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.6.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(2.5.w),
        ),
        child: Row(
          children: [
            Icon(Icons.person_rounded,
                color: _selectedCoach != null
                    ? const Color(0xFF5BA8FF)
                    : Colors.white38,
                size: 20.sp),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(
                selectedName?.isNotEmpty == true
                    ? selectedName!
                    : 'No coach assigned (optional)',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: selectedName?.isNotEmpty == true
                      ? Colors.white
                      : Colors.white38,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 12.sp),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────────

  Widget _section(String label) => Padding(
        padding: EdgeInsets.only(top: 2.5.h, bottom: 1.h),
        child: Text(
          label,
          style: TextStyle(
              color: const Color(0xFFFF3B30),
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8),
        ),
      );

  Widget _row(List<Widget> children) => Row(
        children: children
            .expand((w) => [Expanded(child: w), SizedBox(width: 3.w)])
            .toList()
          ..removeLast(),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType type = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(color: Colors.white, fontSize: 15.sp),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white54, fontSize: 13.sp),
          filled: true,
          fillColor: Colors.white.withOpacity(0.07),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2.5.w),
            borderSide: BorderSide.none,
          ),
        ),
      );

  Widget _datePicker({
    required String label,
    required DateTime? value,
    required DateTime firstDate,
    required DateTime lastDate,
    required void Function(DateTime) onPick,
  }) {
    final display = value == null
        ? 'Tap to select'
        : DateFormat('MMM d, yyyy').format(value);
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(2.5.w),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
            SizedBox(height: 0.4.h),
            Text(display,
                style: TextStyle(
                    color: value != null
                        ? const Color(0xFF5BA8FF)
                        : Colors.white38,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String current,
    Map<String, String> options,
    void Function(String) onChanged,
  ) =>
      Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(2.5.w),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: current,
            isExpanded: true,
            dropdownColor: const Color(0xFF2C2C2E),
            style: TextStyle(color: Colors.white, fontSize: 15.sp),
            items: options.entries
                .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value,
                        style: TextStyle(
                            color: Colors.white, fontSize: 15.sp))))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      );
}

// ─── Credentials Dialog ───────────────────────────────────────────────────────
// Shown after player is successfully created so the admin can copy & share
// the login credentials before the sheet closes.

class _CredentialsDialog extends StatelessWidget {
  final String name;
  final String email;
  final String password;

  const _CredentialsDialog({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF34C759), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Player Registered',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share these credentials with $name:',
            style: TextStyle(color: Colors.white60, fontSize: 10.sp),
          ),
          const SizedBox(height: 12),
          _credRow(context, 'Email', email),
          const SizedBox(height: 8),
          _credRow(context, 'Password', password),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFFF9500).withOpacity(0.30)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFFF9500), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Player must change this password on first login.',
                    style:
                        TextStyle(color: const Color(0xFFFF9500), fontSize: 9.sp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Done',
            style: TextStyle(
                color: const Color(0xFFFF3B30),
                fontSize: 12.sp,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _credRow(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied'),
                  backgroundColor: const Color(0xFF1C1C1E),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Icon(Icons.copy_rounded,
                color: Colors.white38, size: 18),
          ),
        ],
      ),
    );
  }
}
