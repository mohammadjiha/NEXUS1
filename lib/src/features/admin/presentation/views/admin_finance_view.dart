import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../user/models/user_model.dart';
import '../../data/admin_repository.dart';
import '../screens/admin_dashboard_screen.dart';

class AdminFinanceView extends ConsumerStatefulWidget {
  const AdminFinanceView({super.key});

  @override
  ConsumerState<AdminFinanceView> createState() => _AdminFinanceViewState();
}

class _AdminFinanceViewState extends ConsumerState<AdminFinanceView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final gymId = user?.gymId ?? '';

    final playersAsync = ref.watch(adminPlayersProvider(gymId));
    final paymentsAsync = ref.watch(adminPaymentsProvider(gymId));
    final expensesAsync = ref.watch(adminExpensesProvider(gymId));

    final players = playersAsync.asData?.value ?? [];
    final payments = paymentsAsync.asData?.value ?? [];
    final expenses = expensesAsync.asData?.value ?? [];

    final now = DateTime.now();

    // ── Revenue calculations ──────────────────────────────────────────────
    double thisMonthRevenue = 0;
    double lastMonthRevenue = 0;
    final lastMonth = DateTime(now.year, now.month - 1);
    for (var p in payments) {
      if (p.date.year == now.year && p.date.month == now.month) {
        thisMonthRevenue += p.amount;
      }
      if (p.date.year == lastMonth.year && p.date.month == lastMonth.month) {
        lastMonthRevenue += p.amount;
      }
    }
    final totalPending =
        players.fold(0.0, (s, p) => s + (p.amountRemaining ?? 0));

    // ── Expense calculations ──────────────────────────────────────────────
    double thisMonthExpenses = 0;
    double totalExpenses = 0;
    for (var e in expenses) {
      final ts = e['date'];
      DateTime? eDate;
      if (ts != null) {
        try {
          eDate = (ts as dynamic).toDate() as DateTime;
        } catch (_) {}
      }
      final amount = (e['amount'] as num?)?.toDouble() ?? 0;
      totalExpenses += amount;
      if (eDate != null &&
          eDate.year == now.year &&
          eDate.month == now.month) {
        thisMonthExpenses += amount;
      }
    }

    final thisMonthProfit = thisMonthRevenue - thisMonthExpenses;

    // ── Monthly chart (last 6 months) ────────────────────────────────────
    final monthlyRevenue = _computeMonthly(payments, now);
    final monthlyExpenses = _computeMonthlyExpenses(expenses, now);

    return SafeArea(
      child: Column(
        children: [
          _buildTopbar(context, ref, user, players, payments, expenses),
          _buildSummaryCard(
            thisMonthRevenue,
            thisMonthExpenses,
            thisMonthProfit,
            totalPending,
            lastMonthRevenue,
          ),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildRevenueTab(
                    payments, players, monthlyRevenue, monthlyExpenses, now),
                _buildExpensesTab(expenses, gymId, user?.uid ?? ''),
                _buildPlayersTab(players),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────

  Widget _buildTopbar(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
    List<UserModel> players,
    List<PaymentRecord> payments,
    List<Map<String, dynamic>> expenses,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0.5.h),
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
                      color: Colors.white, size: 12.sp),
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                'Finance',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _exportPdf(context, user, players, payments, expenses),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.15),
                borderRadius: BorderRadius.circular(3.w),
                border: Border.all(
                    color: const Color(0xFF34C759).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      color: const Color(0xFF34C759), size: 13.sp),
                  SizedBox(width: 1.5.w),
                  Text(
                    'Export PDF',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
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

  // ── Summary card ─────────────────────────────────────────────────────────

  Widget _buildSummaryCard(
    double thisMonthRevenue,
    double thisMonthExpenses,
    double thisMonthProfit,
    double totalPending,
    double lastMonthRevenue,
  ) {
    String trendLabel;
    Color trendColor;
    if (lastMonthRevenue == 0) {
      trendLabel = 'New';
      trendColor = const Color(0xFF5BA8FF);
    } else {
      final pct =
          ((thisMonthRevenue - lastMonthRevenue) / lastMonthRevenue * 100)
              .round();
      trendLabel = pct >= 0 ? '▲ +$pct%' : '▼ $pct%';
      trendColor =
          pct >= 0 ? const Color(0xFF34C759) : const Color(0xFFFF3B30);
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4.5.w),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS MONTH REVENUE',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white38,
                      letterSpacing: 0.4,
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    '${thisMonthRevenue.toStringAsFixed(0)} JD',
                    style: TextStyle(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                ],
              ),
              Text(
                trendLabel,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: trendColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Divider(color: Colors.white.withOpacity(0.07)),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              _summaryMini(
                '${thisMonthExpenses.toStringAsFixed(0)} JD',
                'EXPENSES',
                const Color(0xFFFF3B30),
              ),
              _vDivider(),
              _summaryMini(
                '${thisMonthProfit.toStringAsFixed(0)} JD',
                'NET PROFIT',
                thisMonthProfit >= 0
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF3B30),
              ),
              _vDivider(),
              _summaryMini(
                '${totalPending.toStringAsFixed(0)} JD',
                'PENDING',
                const Color(0xFFFF9500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMini(String val, String lbl, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: 0.3.h),
          Text(
            lbl,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white60,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      width: 0.5,
      height: 5.h,
      color: Colors.white.withOpacity(0.1),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: TabBar(
        controller: _tab,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(3.w),
        ),
        dividerColor: Colors.transparent,
        labelStyle:
            TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        tabs: const [
          Tab(text: 'Revenue'),
          Tab(text: 'Expenses'),
          Tab(text: 'Players'),
        ],
      ),
    );
  }

  // ── Tab 0: Revenue ───────────────────────────────────────────────────────

  Widget _buildRevenueTab(
    List<PaymentRecord> payments,
    List<UserModel> players,
    List<_MonthStat> monthlyRevenue,
    List<_MonthStat> monthlyExpenses,
    DateTime now,
  ) {
    final planMap = <String, double>{};
    for (var p in payments) {
      planMap[p.planName] = (planMap[p.planName] ?? 0) + p.amount;
    }

    final recent = [...payments]..sort((a, b) => b.date.compareTo(a.date));
    final recentDisplay = recent.take(20).toList();

    final expiring = players.where((p) {
      if (p.subscriptionEnd == null) return false;
      final d = p.subscriptionEnd!.difference(now).inDays;
      return d >= 0 && d <= 7;
    }).toList();

    final chartMax = [...monthlyRevenue, ...monthlyExpenses]
        .fold(0.0, (m, s) => s.amount > m ? s.amount : m);

    return ListView(
      padding: EdgeInsets.only(bottom: 12.h, top: 1.h),
      children: [
        // Chart
        _sectionCard(
          icon: '📊',
          title: 'Revenue vs Expenses — 6 Months',
          trailing: _legendRow(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(monthlyRevenue.length, (i) {
                final r = monthlyRevenue[i];
                final e = monthlyExpenses[i];
                final isNow = r.month.year == now.year &&
                    r.month.month == now.month;
                final rRatio = chartMax == 0
                    ? 0.05
                    : (r.amount / chartMax).clamp(0.05, 1.0);
                final eRatio = chartMax == 0
                    ? 0.0
                    : (e.amount / chartMax).clamp(0.0, 1.0);
                return _buildDoubleBar(
                    _monthLabel(r.month), rRatio, eRatio,
                    isNow: isNow);
              }),
            ),
          ),
        ),

        SizedBox(height: 1.5.h),

        // Plan breakdown
        if (planMap.isNotEmpty)
          _sectionCard(
            icon: '📋',
            title: 'Revenue by Plan',
            child: Column(
              children: planMap.entries.map((e) {
                final total = planMap.values.fold(0.0, (s, v) => s + v);
                final pct = total == 0 ? 0.0 : (e.value / total * 100);
                return _buildPlanRow(e.key, e.value, pct);
              }).toList(),
            ),
          ),

        SizedBox(height: 1.5.h),

        // Recent payments
        _sectionCard(
          icon: '💳',
          title: 'Recent Payments',
          child: recentDisplay.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Text('No payments recorded.',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 13.sp)),
                )
              : Column(
                  children: recentDisplay
                      .map((p) => _buildPaymentRow(p))
                      .toList(),
                ),
        ),

        SizedBox(height: 1.5.h),

        if (expiring.isNotEmpty)
          _sectionCard(
            icon: '⚠️',
            title: 'Expiring This Week (${expiring.length})',
            child: Column(
              children: expiring.map((p) {
                final name =
                    '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
                final days = p.subscriptionEnd!.difference(now).inDays;
                return _buildExpiringRow(
                    name, days, p.amountRemaining ?? 0);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _legendRow() {
    return Padding(
      padding: EdgeInsets.only(right: 4.w, top: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _legendDot(const Color(0xFF34C759), 'Revenue'),
          SizedBox(width: 3.w),
          _legendDot(const Color(0xFFFF3B30), 'Expenses'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 2.w,
          height: 2.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 1.w),
        Text(label,
            style: TextStyle(
                fontSize: 11.sp,
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDoubleBar(String label, double rRatio, double eRatio,
      {bool isNow = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 9.h,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 3.5.w,
                height: 9.h * rRatio,
                decoration: BoxDecoration(
                  color: isNow
                      ? const Color(0xFF34C759)
                      : Colors.white.withOpacity(0.15),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(0.8.w)),
                ),
              ),
              SizedBox(width: 0.5.w),
              Container(
                width: 3.5.w,
                height: eRatio == 0 ? 0 : 9.h * eRatio,
                decoration: BoxDecoration(
                  color: isNow
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFFFF3B30).withOpacity(0.35),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(0.8.w)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
            color: isNow ? Colors.white : Colors.white30,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanRow(String plan, double amount, double pct) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(plan,
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Row(
                children: [
                  Text('${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 10.sp, color: Colors.white38)),
                  SizedBox(width: 2.w),
                  Text('${amount.toStringAsFixed(0)} JD',
                      style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF34C759))),
                ],
              ),
            ],
          ),
          SizedBox(height: 0.8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(1.w),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF34C759)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(PaymentRecord p) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 9.w,
            height: 9.w,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.payments_rounded,
                color: const Color(0xFF34C759), size: 12.sp),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.playerName.isEmpty ? 'Player' : p.playerName,
                    style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                SizedBox(height: 0.2.h),
                Text(
                  '${p.planName} · ${p.paymentMethod}',
                  style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.white.withOpacity(0.35)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${p.amount.toStringAsFixed(0)} JD',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF34C759))),
              SizedBox(height: 0.2.h),
              Text(DateFormat('MMM d').format(p.date),
                  style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.white.withOpacity(0.25))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringRow(String name, int days, double remaining) {
    final color = days <= 2
        ? const Color(0xFFFF3B30)
        : days <= 5
            ? const Color(0xFFFF9500)
            : const Color(0xFFFFCC00);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: Text(
              days == 0 ? 'TODAY' : '${days}d',
              style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: color),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(name,
                style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          if (remaining > 0)
            Text(
              '${remaining.toStringAsFixed(0)} JD due',
              style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF9500)),
            ),
        ],
      ),
    );
  }

  // ── Tab 1: Expenses ──────────────────────────────────────────────────────

  Widget _buildExpensesTab(
      List<Map<String, dynamic>> expenses, String gymId, String adminUid) {
    final catTotals = <String, double>{};
    for (var e in expenses) {
      final cat = e['category'] as String? ?? 'Other';
      catTotals[cat] =
          (catTotals[cat] ?? 0) + ((e['amount'] as num?)?.toDouble() ?? 0);
    }
    final totalExp = catTotals.values.fold(0.0, (s, v) => s + v);

    return ListView(
      padding: EdgeInsets.only(bottom: 12.h, top: 1.h),
      children: [
        GestureDetector(
          onTap: () => _showAddExpenseSheet(gymId, adminUid),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
            padding: EdgeInsets.symmetric(vertical: 1.8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.12),
              borderRadius: BorderRadius.circular(3.w),
              border: Border.all(
                  color: const Color(0xFFFF3B30).withOpacity(0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_rounded,
                    color: const Color(0xFFFF3B30), size: 16.sp),
                SizedBox(width: 2.w),
                Text(
                  'Add Expense',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF3B30),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 1.h),
        if (catTotals.isNotEmpty)
          _sectionCard(
            icon: '📂',
            title: 'By Category',
            child: Column(
              children: catTotals.entries.map((e) {
                final pct = totalExp == 0 ? 0.0 : (e.value / totalExp * 100);
                return _buildExpCatRow(
                    e.key, e.value, pct, _catIcon(e.key), _catColor(e.key));
              }).toList(),
            ),
          ),
        SizedBox(height: 1.5.h),
        _sectionCard(
          icon: '🧾',
          title:
              'All Expenses${totalExp > 0 ? ' · ${totalExp.toStringAsFixed(0)} JD' : ''}',
          child: expenses.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Text('No expenses recorded.',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11.sp)),
                )
              : Column(
                  children: expenses
                      .map((e) => _buildExpenseRow(e, gymId))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildExpCatRow(
      String cat, double amount, double pct, String emoji, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 14.sp)),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(cat,
                    style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              Text('${pct.toStringAsFixed(0)}%',
                  style:
                      TextStyle(fontSize: 10.sp, color: Colors.white38)),
              SizedBox(width: 2.w),
              Text('${amount.toStringAsFixed(0)} JD',
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ],
          ),
          SizedBox(height: 0.8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(1.w),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(Map<String, dynamic> e, String gymId) {
    final ts = e['date'];
    DateTime? date;
    try {
      date = (ts as dynamic).toDate() as DateTime;
    } catch (_) {}
    final amount = (e['amount'] as num?)?.toDouble() ?? 0;
    final cat = e['category'] as String? ?? 'Other';
    final desc = e['description'] as String? ?? '';
    final id = e['id'] as String? ?? '';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Row(
        children: [
          Text(_catIcon(cat), style: TextStyle(fontSize: 16.sp)),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc.isNotEmpty ? desc : cat,
                  style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                SizedBox(height: 0.2.h),
                Text(
                  '$cat${date != null ? ' · ${DateFormat('MMM d').format(date)}' : ''}',
                  style: TextStyle(
                      fontSize: 9.sp,
                      color: Colors.white.withOpacity(0.35)),
                ),
              ],
            ),
          ),
          Text(
            '-${amount.toStringAsFixed(0)} JD',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFF3B30),
            ),
          ),
          SizedBox(width: 2.w),
          GestureDetector(
            onTap: () => _deleteExpense(gymId, id),
            child: Container(
              padding: EdgeInsets.all(1.5.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.white30, size: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Players ─────────────────────────────────────────────────────

  Widget _buildPlayersTab(List<UserModel> players) {
    final sorted = [...players]
      ..sort((a, b) =>
          (b.amountRemaining ?? 0).compareTo(a.amountRemaining ?? 0));

    return ListView(
      padding: EdgeInsets.only(bottom: 12.h, top: 1.h),
      children: [
        _sectionCard(
          icon: '👥',
          title: 'Player Payment Status (${players.length})',
          child: sorted.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Text('No players.',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11.sp)),
                )
              : Column(
                  children: sorted
                      .map((p) => _buildPlayerFinanceRow(p))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildPlayerFinanceRow(UserModel p) {
    final name =
        '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
    final total = p.totalAmount ?? 0;
    final paid = p.amountPaid ?? 0;
    final remaining = p.amountRemaining ?? 0;
    final pct = total == 0 ? 1.0 : (paid / total).clamp(0.0, 1.0);
    final isFullyPaid = remaining <= 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.05), width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? p.email : name,
                        style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    SizedBox(height: 0.2.h),
                    Text(p.subscriptionPlan ?? 'No plan',
                        style: TextStyle(
                            fontSize: 11.sp, color: Colors.white60)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isFullyPaid
                        ? '✅ Paid'
                        : '-${remaining.toStringAsFixed(0)} JD',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isFullyPaid
                          ? const Color(0xFF34C759)
                          : const Color(0xFFFF9500),
                    ),
                  ),
                  SizedBox(height: 0.2.h),
                  Text(
                    '${paid.toStringAsFixed(0)}/${total.toStringAsFixed(0)} JD',
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white.withOpacity(0.4)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 1.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(1.w),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation(
                isFullyPaid
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF9500),
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section card ──────────────────────────────────────────────────────────

  Widget _sectionCard({
    required String icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
            color: Colors.white.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trailing != null) trailing,
          Padding(
            padding: EdgeInsets.fromLTRB(
                4.w, trailing != null ? 0 : 3.h, 4.w, 2.h),
            child: Row(
              children: [
                Text(icon, style: TextStyle(fontSize: 16.sp)),
                SizedBox(width: 2.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          child,
          SizedBox(height: 0.5.h),
        ],
      ),
    );
  }

  // ── Add expense ───────────────────────────────────────────────────────────

  void _showAddExpenseSheet(String gymId, String adminUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExpenseSheet(
        gymId: gymId,
        adminUid: adminUid,
        repo: ref.read(adminRepositoryProvider),
        onAdded: () => ref.invalidate(adminExpensesProvider(gymId)),
      ),
    );
  }

  Future<void> _deleteExpense(String gymId, String id) async {
    if (id.isEmpty) return;
    try {
      await ref
          .read(adminRepositoryProvider)
          .deleteExpense(gymId: gymId, expenseId: id);
      ref.invalidate(adminExpensesProvider(gymId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── PDF Export ────────────────────────────────────────────────────────────

  Future<void> _exportPdf(
    BuildContext context,
    UserModel? user,
    List<UserModel> players,
    List<PaymentRecord> payments,
    List<Map<String, dynamic>> expenses,
  ) async {
    final now = DateTime.now();
    final monthStr = DateFormat('MMMM yyyy').format(now);

    double revThisMonth = 0, expThisMonth = 0;
    for (var p in payments) {
      if (p.date.year == now.year && p.date.month == now.month) {
        revThisMonth += p.amount;
      }
    }
    for (var e in expenses) {
      final ts = e['date'];
      DateTime? d;
      try {
        d = (ts as dynamic).toDate() as DateTime;
      } catch (_) {}
      if (d != null && d.year == now.year && d.month == now.month) {
        expThisMonth += (e['amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final Uint8List pdfBytes = await _buildPdfBytes(
      gymId: user?.gymId ?? 'Gym',
      monthStr: monthStr,
      players: players,
      payments: payments,
      expenses: expenses,
      revThisMonth: revThisMonth,
      expThisMonth: expThisMonth,
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: 'NEXUS_Finance_${DateFormat('yyyy_MM').format(now)}.pdf',
    );
  }

  Future<Uint8List> _buildPdfBytes({
    required String gymId,
    required String monthStr,
    required List<UserModel> players,
    required List<PaymentRecord> payments,
    required List<Map<String, dynamic>> expenses,
    required double revThisMonth,
    required double expThisMonth,
  }) async {
    // ── Arabic-supporting font (Cairo via Google Fonts) ───────────────────
    final arabicFont     = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    // Helper: text style with Arabic font
    pw.TextStyle ar({
      double size = 10,
      bool bold = false,
      PdfColor color = PdfColors.black,
    }) =>
        pw.TextStyle(
          font:     bold ? arabicFontBold : arabicFont,
          fontSize: size,
          color:    color,
        );


    final doc = pw.Document();
    final netProfit = revThisMonth - expThisMonth;
    final totalPending =
        players.fold(0.0, (s, p) => s + (p.amountRemaining ?? 0));

    final monthPayments = payments
        .where((p) {
          final now = DateTime.now();
          return p.date.year == now.year && p.date.month == now.month;
        })
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final monthExpenses = expenses.where((e) {
      final ts = e['date'];
      DateTime? d;
      try {
        d = (ts as dynamic).toDate() as DateTime;
      } catch (_) {}
      if (d == null) return false;
      final now = DateTime.now();
      return d.year == now.year && d.month == now.month;
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('NEXUS GYM',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800)),
                  pw.Text('Finance Report — $monthStr',
                      style: pw.TextStyle(
                          fontSize: 12, color: PdfColors.grey600)),
                ],
              ),
              pw.Text('Gym: $gymId',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Text('FINANCIAL SUMMARY',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600)),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _pdfStatBox('Revenue',
                '${revThisMonth.toStringAsFixed(0)} JD', PdfColors.green800),
            pw.SizedBox(width: 16),
            _pdfStatBox('Expenses',
                '${expThisMonth.toStringAsFixed(0)} JD', PdfColors.red700),
            pw.SizedBox(width: 16),
            _pdfStatBox(
                'Net Profit',
                '${netProfit.toStringAsFixed(0)} JD',
                netProfit >= 0 ? PdfColors.green900 : PdfColors.red900),
            pw.SizedBox(width: 16),
            _pdfStatBox('Pending',
                '${totalPending.toStringAsFixed(0)} JD', PdfColors.orange700),
          ]),
          pw.SizedBox(height: 20),
          if (monthPayments.isNotEmpty) ...[
            pw.Text('PAYMENTS THIS MONTH (${monthPayments.length})',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Player', 'Plan', 'Amount', 'Method', 'Date'],
              data: monthPayments
                  .map((p) => [
                        p.playerName.isEmpty ? 'N/A' : p.playerName,
                        p.planName,
                        '${p.amount.toStringAsFixed(0)} JD',
                        p.paymentMethod,
                        DateFormat('MMM d').format(p.date),
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellHeight: 20,
            ),
            pw.SizedBox(height: 20),
          ],
          if (monthExpenses.isNotEmpty) ...[
            pw.Text('EXPENSES THIS MONTH',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600)),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: ['Category', 'Description', 'Amount', 'Date'],
              data: monthExpenses.map((e) {
                final ts = e['date'];
                DateTime? d;
                try {
                  d = (ts as dynamic).toDate() as DateTime;
                } catch (_) {}
                return [
                  e['category'] ?? 'Other',
                  e['description'] ?? '',
                  '${((e['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} JD',
                  d != null ? DateFormat('MMM d').format(d) : '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.red700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellHeight: 20,
            ),
            pw.SizedBox(height: 20),
          ],
          pw.Text('PLAYER PAYMENT STATUS',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Player', 'Plan', 'Total', 'Paid', 'Remaining'],
            data: players.map((p) {
              final name =
                  '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
              return [
                name.isEmpty ? p.email : name,
                p.subscriptionPlan ?? '-',
                '${(p.totalAmount ?? 0).toStringAsFixed(0)} JD',
                '${(p.amountPaid ?? 0).toStringAsFixed(0)} JD',
                '${(p.amountRemaining ?? 0).toStringAsFixed(0)} JD',
              ];
            }).toList(),
            headerStyle: ar(size: 9, bold: true, color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey800),
            cellStyle: ar(size: 9),
            cellHeight: 20,
          ),
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Text(
            'Generated by NEXUS on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _pdfStatBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      ),
    );
  }

  // ── Static helpers ────────────────────────────────────────────────────────

  static List<_MonthStat> _computeMonthly(
      List<PaymentRecord> payments, DateTime now) {
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      final total = payments
          .where((p) =>
              p.date.year == month.year && p.date.month == month.month)
          .fold(0.0, (s, p) => s + p.amount);
      return _MonthStat(month: month, amount: total);
    });
  }

  static List<_MonthStat> _computeMonthlyExpenses(
      List<Map<String, dynamic>> expenses, DateTime now) {
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - (5 - i));
      double total = 0;
      for (var e in expenses) {
        final ts = e['date'];
        DateTime? d;
        try {
          d = (ts as dynamic).toDate() as DateTime;
        } catch (_) {}
        if (d != null && d.year == month.year && d.month == month.month) {
          total += (e['amount'] as num?)?.toDouble() ?? 0;
        }
      }
      return _MonthStat(month: month, amount: total);
    });
  }

  static String _monthLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[d.month - 1];
  }

  static String _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'salary':
        return '💼';
      case 'rent':
        return '🏢';
      case 'electricity':
        return '⚡';
      case 'maintenance':
        return '🔧';
      case 'equipment':
        return '🏋️';
      default:
        return '💸';
    }
  }

  static Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'salary':
        return const Color(0xFF5BA8FF);
      case 'rent':
        return const Color(0xFFFF9500);
      case 'electricity':
        return const Color(0xFFFFCC00);
      case 'maintenance':
        return const Color(0xFFFF6B6B);
      case 'equipment':
        return const Color(0xFF5BA8FF);
      default:
        return const Color(0xFFFF3B30);
    }
  }
}

// ─── Add Expense Sheet ────────────────────────────────────────────────────────

class _AddExpenseSheet extends StatefulWidget {
  final String gymId;
  final String adminUid;
  final AdminRepository repo;
  final VoidCallback onAdded;

  const _AddExpenseSheet({
    required this.gymId,
    required this.adminUid,
    required this.repo,
    required this.onAdded,
  });

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Salary';
  DateTime _date = DateTime.now();
  bool _saving = false;

  final _categories = [
    'Salary', 'Rent', 'Electricity', 'Maintenance', 'Equipment', 'Other'
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.addExpense(
        gymId: widget.gymId,
        category: _category,
        description: _descCtrl.text.trim(),
        amount: amount,
        date: _date,
        addedByUid: widget.adminUid,
      );
      widget.onAdded();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Expense added ✅')));
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(data: ThemeData.dark(), child: child!),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.fromLTRB(
          5.w, 2.h, 5.w, MediaQuery.of(context).viewInsets.bottom + 4.h),
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
            Text('Add Expense',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 3.h),
            Text('CATEGORY',
                style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white38,
                    letterSpacing: 0.4)),
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: _categories.map((c) {
                final sel = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 3.5.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFFFF3B30)
                          : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(5.w),
                      border: Border.all(
                          color: sel
                              ? const Color(0xFFFF3B30)
                              : Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(c,
                        style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : Colors.white60)),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 2.h),
            _field(_amountCtrl, 'Amount (JD)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            SizedBox(height: 2.h),
            _field(_descCtrl, 'Description (optional)'),
            SizedBox(height: 2.h),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: 3.w, vertical: 1.8.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(2.5.w),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        color: Colors.white54, size: 14.sp),
                    SizedBox(width: 2.w),
                    Text(
                      DateFormat('MMM d, yyyy').format(_date),
                      style: TextStyle(
                          color: Colors.white, fontSize: 13.sp),
                    ),
                  ],
                ),
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
                    : Text('Add Expense',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.white, fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54, fontSize: 10.sp),
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
  }
}

// ─── Data helpers ─────────────────────────────────────────────────────────────

class _MonthStat {
  final DateTime month;
  final double amount;
  const _MonthStat({required this.month, required this.amount});
}
