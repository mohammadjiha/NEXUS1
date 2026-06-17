import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../data/super_admin_service.dart';

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
            _SectionHeader(
              icon: Icons.fitness_center_rounded,
              label: 'اللاعبون',
              count: playersAsync.asData?.value.length,
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

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  const _PlayerTile({required this.player});

  @override
  Widget build(BuildContext context) {
    final firstName = player['firstName'] as String? ?? '';
    final lastName  = player['lastName'] as String? ?? '';
    final name      = '$firstName $lastName'.trim();
    final email     = player['email'] as String? ?? '';
    final plan      = player['subscriptionPlan'] as String? ?? '—';
    final isActive  = player['isActive'] as bool? ?? true;
    final coachName = player['assignedCoachName'] as String?;

    return Container(
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
