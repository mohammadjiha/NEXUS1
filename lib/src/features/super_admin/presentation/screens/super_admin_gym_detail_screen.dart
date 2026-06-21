import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../data/super_admin_service.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../admin/presentation/screens/import_players_screen.dart';

/// Super Admin → Gym Detail
/// Shows coaches + players for a specific gym.
class SuperAdminGymDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> gym;

  const SuperAdminGymDetailScreen({super.key, required this.gym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymId   = gym['id'] as String? ?? '';
    final gymName = gym['name'] as String? ?? 'Gym';
    final city    = gym['city'] as String? ?? '';
    final isActive = gym['isActive'] as bool? ?? true;

    final coachesAsync  = ref.watch(gymCoachesStreamProvider(gymId));
    final playersAsync  = ref.watch(gymPlayersStreamProvider(gymId));
    final allPlayers    = playersAsync.asData?.value ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gymName,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800)),
            if (city.isNotEmpty)
              Text(city,
                  style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 4.w),
            padding:
                EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF34C759).withOpacity(0.15)
                  : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'نشط' : 'موقوف',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF3B30),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          children: [
            // ── Stats strip ──────────────────────────────────────────
            _StatsStrip(coachesAsync: coachesAsync, playersAsync: playersAsync),
            SizedBox(height: 2.h),

            // ── Coaches section ──────────────────────────────────────
            _SectionHeader(
              icon: Icons.sports_rounded,
              label: 'المدربون',
              count: coachesAsync.asData?.value.length,
            ),
            SizedBox(height: 1.h),
            coachesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF3B30))),
              error: (e, _) => _ErrorTile('$e'),
              data: (coaches) {
                if (coaches.isEmpty) {
                  return _EmptyState(
                      icon: '🧑‍💼', message: 'لا يوجد مدربون في هذا النادي');
                }
                return Column(
                  children: coaches
                      .map((c) => _CoachCard(
                            coach: c,
                            allPlayers: allPlayers,
                          ))
                      .toList(),
                );
              },
            ),

            SizedBox(height: 2.5.h),

            // ── Players section ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _SectionHeader(
                    icon: Icons.fitness_center_rounded,
                    label: 'اللاعبون',
                    count: playersAsync.asData?.value.length,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImportPlayersScreen(overrideGymId: gymId),
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA8FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file_rounded,
                            color: const Color(0xFF5BA8FF), size: 11.sp),
                        SizedBox(width: 1.w),
                        Text('استيراد',
                            style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF5BA8FF))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.h),
            playersAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF3B30))),
              error: (e, _) => _ErrorTile('$e'),
              data: (players) {
                if (players.isEmpty) {
                  return _EmptyState(
                      icon: '🏋️', message: 'لا يوجد لاعبون في هذا النادي');
                }
                return Column(
                  children: players.map((p) => _PlayerTile(player: p)).toList(),
                );
              },
            ),

            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }
}

// ── Stats strip ───────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> coachesAsync;
  final AsyncValue<List<Map<String, dynamic>>> playersAsync;

  const _StatsStrip({required this.coachesAsync, required this.playersAsync});

  @override
  Widget build(BuildContext context) {
    final coachCount  = coachesAsync.asData?.value.length ?? 0;
    final playerCount = playersAsync.asData?.value.length ?? 0;
    final active = playersAsync.asData?.value
            .where((p) => p['isActive'] as bool? ?? true)
            .length ??
        0;

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFC0392B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Row(
        children: [
          _Stat(coachCount.toString(), 'مدرب'),
          _vDivider(),
          _Stat(playerCount.toString(), 'لاعب'),
          _vDivider(),
          _Stat(active.toString(), 'نشط'),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 0.5,
        height: 5.h,
        color: Colors.white24,
        margin: EdgeInsets.symmetric(horizontal: 2.w),
      );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1)),
          SizedBox(height: 0.4.h),
          Text(label,
              style: TextStyle(
                  fontSize: 8.sp,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;

  const _SectionHeader(
      {required this.icon, required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF3B30), size: 16.sp),
        SizedBox(width: 2.w),
        Text(label,
            style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800)),
        if (count != null) ...[
          SizedBox(width: 2.w),
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.2.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ],
    );
  }
}

// ── Coach card ────────────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  final Map<String, dynamic> coach;
  final List<Map<String, dynamic>> allPlayers;

  const _CoachCard({required this.coach, required this.allPlayers});

  @override
  Widget build(BuildContext context) {
    final uid       = coach['uid'] as String? ?? '';
    final firstName = coach['firstName'] as String? ?? '';
    final lastName  = coach['lastName'] as String? ?? '';
    final name      = '$firstName $lastName'.trim();
    final email     = coach['email'] as String? ?? '';
    final phone     = coach['phone'] as String? ?? '';
    final isActive  = coach['isActive'] as bool? ?? true;

    final assignedPlayers =
        allPlayers.where((p) => p['assignedCoachUid'] == uid).toList();

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
            color: const Color(0xFFFF3B30).withOpacity(0.2), width: 0.5),
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 12.w,
                height: 12.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF3B30)),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? email : name,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 0.3.h),
                    Text(email,
                        style:
                            TextStyle(color: Colors.white38, fontSize: 9.sp)),
                    if (phone.isNotEmpty)
                      Text(phone,
                          style: TextStyle(
                              color: Colors.white38, fontSize: 9.sp)),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 2.5.w, vertical: 0.4.h),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF34C759).withOpacity(0.15)
                      : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'نشط' : 'موقوف',
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                  ),
                ),
              ),
            ],
          ),

          if (assignedPlayers.isNotEmpty) ...[
            SizedBox(height: 1.5.h),
            Divider(color: Colors.white.withOpacity(0.06)),
            SizedBox(height: 1.h),
            Text('اللاعبون المسندون (${assignedPlayers.length})',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 0.8.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 0.8.h,
              children: assignedPlayers.map((p) {
                final pFirst = p['firstName'] as String? ?? '';
                final pLast  = p['lastName'] as String? ?? '';
                final pName  = '$pFirst $pLast'.trim();
                final pActive = p['isActive'] as bool? ?? true;
                return Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 2.5.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: pActive
                              ? const Color(0xFF34C759)
                              : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 1.5.w),
                      Text(pName.isEmpty ? '?' : pName,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            SizedBox(height: 1.h),
            Text('لا يوجد لاعبون مسندون',
                style:
                    TextStyle(color: Colors.white24, fontSize: 9.sp)),
          ],
        ],
      ),
    );
  }
}

// ── Player tile ───────────────────────────────────────────────────────────────

final _saPlayerPaymentsProvider =
    StreamProvider.autoDispose.family<List<PaymentRecord>, String>((ref, uid) {
  return ref.watch(adminRepositoryProvider).getPlayerPaymentsStream(uid);
});

class _PlayerTile extends ConsumerWidget {
  final Map<String, dynamic> player;
  const _PlayerTile({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = player['firstName'] as String? ?? '';
    final lastName  = player['lastName'] as String? ?? '';
    final name      = '$firstName $lastName'.trim();
    final email     = player['email'] as String? ?? '';
    final plan      = player['subscriptionPlan'] as String? ?? '—';
    final isActive  = player['isActive'] as bool? ?? true;
    final coachName = player['assignedCoachName'] as String?;
    final uid         = player['uid'] as String? ?? '';
    final totalAmount = (player['totalAmount'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => _showPaymentSheet(context, ref, uid, name.isEmpty ? email : name, totalAmount),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          border: Border.all(
              color: Colors.white.withOpacity(0.07), width: 0.5),
          borderRadius: BorderRadius.circular(3.w),
        ),
        child: Row(
          children: [
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? email : name,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 0.2.h),
                  Text(
                    [
                      plan,
                      if (coachName != null && coachName.isNotEmpty)
                        'مدرب: $coachName',
                    ].join('  •  '),
                    style: TextStyle(color: Colors.white38, fontSize: 8.sp),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 18),
            SizedBox(width: 1.w),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF34C759) : Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, WidgetRef ref, String uid,
      String displayName, double totalAmount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuperAdminPaymentSheet(
        uid: uid,
        displayName: displayName,
        totalAmount: totalAmount,
      ),
    );
  }
}

// ── Super Admin Payment Sheet ─────────────────────────────────────────────────

class _SuperAdminPaymentSheet extends ConsumerWidget {
  final String uid;
  final String displayName;
  final double totalAmount;

  const _SuperAdminPaymentSheet({
    required this.uid,
    required this.displayName,
    this.totalAmount = 0.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(_saPlayerPaymentsProvider(uid));
    final adminRepo = ref.watch(adminRepositoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 12.w,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 2.h),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10)),
            ),
            // Title + Edit Sub button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: Color(0xFFFF9500), size: 20),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text('سجل مدفوعات $displayName',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800)),
                  ),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _SuperAdminEditSubSheet(
                        uid: uid,
                        displayName: displayName,
                      ),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 0.8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5BA8FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2.w),
                        border: Border.all(
                            color: const Color(0xFF5BA8FF).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded,
                              color: const Color(0xFF5BA8FF), size: 12.sp),
                          SizedBox(width: 1.w),
                          Text('تعديل',
                              style: TextStyle(
                                  color: const Color(0xFF5BA8FF),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 1.5.h),
            Divider(color: Colors.white.withOpacity(0.08)),
            // List
            Expanded(
              child: paymentsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF9500))),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: const TextStyle(color: Colors.red))),
                data: (payments) {
                  if (payments.isEmpty) {
                    return Center(
                      child: Text('لا يوجد سجل مدفوعات',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12.sp)),
                    );
                  }

                  // Compute real totals from payment records
                  final totalPaid =
                      payments.fold(0.0, (s, p) => s + p.amount);
                  final effectiveTotal =
                      totalAmount > 0 ? totalAmount : totalPaid;
                  final remaining =
                      (effectiveTotal - totalPaid).clamp(0.0, double.infinity);

                  return Column(
                    children: [
                      // ── Summary banner ────────────────────────────────
                      Padding(
                        padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 1.5.h),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w, vertical: 1.5.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(3.w),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: _chip('الإجمالي', effectiveTotal, Colors.white70)),
                              _vLine(),
                              Expanded(child: _chip('المدفوع', totalPaid, const Color(0xFF34C759))),
                              _vLine(),
                              Expanded(child: _chip('المتبقي', remaining,
                                  remaining > 0 ? const Color(0xFFFF9500) : const Color(0xFF34C759))),
                            ],
                          ),
                        ),
                      ),
                      // ── Records ───────────────────────────────────────
                      Expanded(
                        child: ListView.builder(
                          controller: scrollCtrl,
                          padding: EdgeInsets.symmetric(
                              horizontal: 5.w, vertical: 1.h),
                          itemCount: payments.length,
                          itemBuilder: (_, i) {
                            final p = payments[i];
                            return Container(
                        margin: EdgeInsets.only(bottom: 1.5.h),
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(3.w),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.credit_card_rounded,
                                color: Color(0xFFFF9500), size: 18),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.planName,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700)),
                                  SizedBox(height: 0.3.h),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(p.date) +
                                        '  •  ' +
                                        p.paymentMethod,
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 9.sp),
                                  ),
                                ],
                              ),
                            ),
                            Text('+${p.amount.toStringAsFixed(0)} JD',
                                style: TextStyle(
                                    color: const Color(0xFF34C759),
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(width: 2.w),
                            GestureDetector(
                              onTap: () async {
                                final confirmed =
                                    await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor:
                                        const Color(0xFF1C1C1E),
                                    title: Text('حذف السجل',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14.sp)),
                                    content: Text('هل تريد حذف هذا السجل؟',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12.sp)),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(
                                              ctx, false),
                                          child: const Text('إلغاء',
                                              style: TextStyle(
                                                  color: Colors.white54))),
                                      TextButton(
                                          onPressed: () => Navigator.pop(
                                              ctx, true),
                                          child: const Text('حذف',
                                              style: TextStyle(
                                                  color:
                                                      Color(0xFFFF3B30)))),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await adminRepo.deletePaymentRecord(
                                      uid, p.id);
                                }
                              },
                              child: Icon(Icons.delete_outline_rounded,
                                  color: Colors.red.shade400, size: 18.sp),
                            ),
                          ],
                        ),
                      );
                    },
                  ),    // ListView.builder
                  ),    // Expanded
                ],
              );        // Column
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, double value, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(color: Colors.white54, fontSize: 9.sp)),
        SizedBox(height: 0.4.h),
        Text('${value.toStringAsFixed(0)} JD',
            style: TextStyle(
                color: valueColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _vLine() => Container(
        width: 1,
        height: 4.h,
        color: Colors.white.withOpacity(0.12),
      );
}

// ── Super Admin Edit Subscription Sheet ──────────────────────────────────────

class _SuperAdminEditSubSheet extends ConsumerStatefulWidget {
  final String uid;
  final String displayName;

  const _SuperAdminEditSubSheet({
    required this.uid,
    required this.displayName,
  });

  @override
  ConsumerState<_SuperAdminEditSubSheet> createState() =>
      _SuperAdminEditSubSheetState();
}

class _SuperAdminEditSubSheetState
    extends ConsumerState<_SuperAdminEditSubSheet> {
  late DateTime _startDate;
  late DateTime _endDate;
  double _totalAmount = 0;
  double _amountPaid  = 0;
  String _paymentMethod = 'cash';
  String _planName = '';
  bool _saving = false;
  String _error = '';

  final _totalCtrl = TextEditingController();
  final _paidCtrl  = TextEditingController();
  final _planCtrl  = TextEditingController();

  static const _methods = ['cash', 'visa', 'bank_transfer', 'cliq', 'wallet'];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _endDate   = DateTime.now().add(const Duration(days: 30));
    // Load current subscription data from Firestore
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .get();
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;
      setState(() {
        final startTs = data['subscriptionStart'] as Timestamp?;
        final endTs   = data['subscriptionEnd']   as Timestamp?;
        _startDate     = startTs?.toDate() ?? DateTime.now();
        _endDate       = endTs?.toDate()   ?? _startDate.add(const Duration(days: 30));
        _totalAmount   = (data['totalAmount']  as num?)?.toDouble() ?? 0;
        _amountPaid    = (data['amountPaid']   as num?)?.toDouble() ?? 0;
        _planName      = data['subscriptionPlan'] as String? ?? '';
        final method   = data['paymentMethod']  as String? ?? 'cash';
        _paymentMethod = _methods.contains(method) ? method : 'cash';
        if (_totalAmount > 0) _totalCtrl.text = _totalAmount.toStringAsFixed(0);
        if (_amountPaid  > 0) _paidCtrl.text  = _amountPaid.toStringAsFixed(0);
        _planCtrl.text = _planName;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    _paidCtrl.dispose();
    _planCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) _startDate = picked;
      else _endDate = picked;
    });
  }

  Future<void> _save() async {
    final total = double.tryParse(_totalCtrl.text) ?? 0;
    final paid  = double.tryParse(_paidCtrl.text)  ?? 0;
    final plan  = _planCtrl.text.trim().isNotEmpty ? _planCtrl.text.trim() : 'مخصص';
    if (total < 0 || paid < 0) {
      setState(() => _error = 'المبلغ لا يمكن أن يكون سالباً');
      return;
    }
    setState(() { _saving = true; _error = ''; });
    try {
      await ref.read(adminRepositoryProvider).updatePlayerSubscription(
        playerUid:       widget.uid,
        plan:            plan,
        startDate:       _startDate,
        endDate:         _endDate,
        totalAmount:     total,
        amountPaid:      paid,
        paymentMethod:   _paymentMethod,
        // No gymId passed → no payment record even if delta > 0
        // To enable payment records from SA, pass gymId here
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعديل الاشتراك ✅')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateTile(String label, DateTime date, bool isStart) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
      subtitle: Text(
        '${date.year}/${date.month.toString().padLeft(2,'0')}/${date.day.toString().padLeft(2,'0')}',
        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
      ),
      trailing: Icon(Icons.calendar_today_rounded,
          color: const Color(0xFFFF9500), size: 16.sp),
      onTap: () => _pickDate(isStart),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_totalAmount - _amountPaid).clamp(0.0, double.infinity);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: 12.w, height: 4,
              margin: EdgeInsets.symmetric(vertical: 2.h),
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
            Expanded(child: SingleChildScrollView(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.edit_rounded, color: Color(0xFF5BA8FF), size: 18),
                  SizedBox(width: 2.w),
                  Text('تعديل اشتراك ${widget.displayName}',
                      style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w800)),
                ]),
                SizedBox(height: 2.h),
                Divider(color: Colors.white.withOpacity(0.08)),

                // Plan name
                TextField(
                  controller: _planCtrl,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp),
                  decoration: InputDecoration(
                    labelText: 'اسم الخطة',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2.w),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2.w),
                      borderSide: const BorderSide(color: Color(0xFF5BA8FF)),
                    ),
                  ),
                  onChanged: (v) => _planName = v,
                ),
                SizedBox(height: 1.5.h),

                // Dates
                _dateTile('تاريخ البداية', _startDate, true),
                Divider(color: Colors.white.withOpacity(0.06)),
                _dateTile('تاريخ الانتهاء', _endDate, false),
                Divider(color: Colors.white.withOpacity(0.06)),

                SizedBox(height: 1.h),

                // Total
                TextField(
                  controller: _totalCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp),
                  decoration: InputDecoration(
                    labelText: 'المبلغ الإجمالي (JD)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2.w),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2.w),
                      borderSide: const BorderSide(color: Color(0xFF5BA8FF)),
                    ),
                  ),
                  onChanged: (v) => setState(() => _totalAmount = double.tryParse(v) ?? 0),
                ),
                SizedBox(height: 1.5.h),

                // Paid
                TextField(
                  controller: _paidCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Colors.white, fontSize: 13.sp),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع (JD)',
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2.w),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2.w),
                      borderSide: const BorderSide(color: Color(0xFF5BA8FF)),
                    ),
                  ),
                  onChanged: (v) => setState(() => _amountPaid = double.tryParse(v) ?? 0),
                ),
                SizedBox(height: 1.h),

                // Remaining pill
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المتبقي', style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
                      Text('${remaining.toStringAsFixed(0)} JD',
                          style: TextStyle(
                              color: remaining > 0 ? Colors.orange : const Color(0xFF34C759),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                SizedBox(height: 1.5.h),

                // Payment method
                Row(children: [
                  Text('طريقة الدفع:', style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
                  SizedBox(width: 3.w),
                  DropdownButton<String>(
                    value: _paymentMethod,
                    dropdownColor: const Color(0xFF2C2C2E),
                    style: TextStyle(color: Colors.white, fontSize: 12.sp),
                    items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _paymentMethod = v); },
                  ),
                ]),

                if (_error.isNotEmpty) ...[
                  SizedBox(height: 1.h),
                  Text(_error, style: const TextStyle(color: Color(0xFFFF3B30))),
                ],
                SizedBox(height: 3.h),

                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5BA8FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w)),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : Text('حفظ التعديلات',
                            style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700)),
                  ),
                ),
                SizedBox(height: 2.h),
              ]),
            ))),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: 28.sp)),
            SizedBox(height: 1.h),
            Text(message,
                style:
                    TextStyle(color: Colors.white38, fontSize: 11.sp)),
          ],
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile(this.message);

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: 1.h),
        child: Text('خطأ: $message',
            style: TextStyle(color: Colors.red, fontSize: 10.sp)),
      );
}
