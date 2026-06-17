import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../data/admin_repository.dart';
import '../../../user/models/user_model.dart';

class AdminCheckinView extends ConsumerStatefulWidget {
  final String gymId;
  final String adminUid;
  const AdminCheckinView(
      {super.key, required this.gymId, required this.adminUid});

  @override
  ConsumerState<AdminCheckinView> createState() => _AdminCheckinViewState();
}

class _AdminCheckinViewState extends ConsumerState<AdminCheckinView> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkIn(UserModel player) async {
    final repo = ref.read(adminRepositoryProvider);
    try {
      await repo.checkInPlayer(
        gymId: widget.gymId,
        playerUid: player.uid,
        playerName:
            '${player.firstName ?? ''} ${player.lastName ?? ''}'.trim(),
        addedByUid: widget.adminUid,
      );
      ref.invalidate(todayCheckInsProvider(widget.gymId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${player.firstName ?? player.email} checked in ✅'),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(adminPlayersProvider(widget.gymId));
    final checkinsAsync =
        ref.watch(todayCheckInsProvider(widget.gymId));

    final checkedInUids = checkinsAsync.maybeWhen(
      data: (list) => list.map((c) => c['playerUid'] as String).toSet(),
      orElse: () => <String>{},
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Attendance / Check-in',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Today's summary
          checkinsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (checkins) => Container(
              margin: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 0),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF34C759).withOpacity(0.15),
                    const Color(0xFF34C759).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(4.w),
                border: Border.all(
                    color: const Color(0xFF34C759).withOpacity(0.25)),
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
                        color: Color(0xFF34C759), size: 24),
                  ),
                  SizedBox(width: 3.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Attendance",
                          style: TextStyle(
                              color: Colors.white54, fontSize: 10.sp)),
                      Text('${checkins.length} checked in',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    _todayDate(),
                    style: TextStyle(
                        color: const Color(0xFF34C759),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          // Search
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              style:
                  TextStyle(color: Colors.white, fontSize: 12.sp),
              decoration: InputDecoration(
                hintText: 'Search player...',
                hintStyle:
                    const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3.w),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 4.w, vertical: 1.5.h),
              ),
            ),
          ),

          // Players list
          Expanded(
            child: playersAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF34C759))),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style:
                          const TextStyle(color: Colors.white54))),
              data: (players) {
                final active = players
                    .where((p) =>
                        p.isActive &&
                        !p.isSubscriptionExpired &&
                        (_query.isEmpty ||
                            '${p.firstName} ${p.lastName} ${p.email}'
                                .toLowerCase()
                                .contains(_query)))
                    .toList();

                if (active.isEmpty) {
                  return Center(
                    child: Text('No active players found',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12.sp)),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(
                      horizontal: 4.w, vertical: 1.h),
                  itemCount: active.length,
                  itemBuilder: (_, i) {
                    final p = active[i];
                    final isCheckedIn =
                        checkedInUids.contains(p.uid);
                    return _PlayerCheckinTile(
                      player: p,
                      isCheckedIn: isCheckedIn,
                      onCheckIn: () => _checkIn(p),
                    );
                  },
                );
              },
            ),
          ),

          // Today's check-in log
          checkinsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (checkins) {
              if (checkins.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 28.h,
                decoration: const BoxDecoration(
                  color: Color(0xFF111118),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 1.h),
                      child: Text("Today's Log",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding:
                            EdgeInsets.symmetric(horizontal: 4.w),
                        itemCount: checkins.length,
                        itemBuilder: (_, i) {
                          final c = checkins[i];
                          final name =
                              c['playerName'] as String? ?? 'Unknown';
                          final time =
                              c['checkedInAt'] as String? ?? '';
                          return Padding(
                            padding:
                                EdgeInsets.only(bottom: 1.h),
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF34C759),
                                    size: 18),
                                SizedBox(width: 2.w),
                                Expanded(
                                  child: Text(name,
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11.sp)),
                                ),
                                Text(
                                  _formatTime(time),
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10.sp),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _todayDate() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}';
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return '';
    }
  }
}

// ─── Player Check-in Tile ─────────────────────────────────────────────────────

class _PlayerCheckinTile extends StatelessWidget {
  final UserModel player;
  final bool isCheckedIn;
  final VoidCallback onCheckIn;

  const _PlayerCheckinTile({
    required this.player,
    required this.isCheckedIn,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final name =
        '${player.firstName ?? ''} ${player.lastName ?? ''}'.trim();
    final initials =
        '${player.firstName?.isNotEmpty == true ? player.firstName![0] : ''}${player.lastName?.isNotEmpty == true ? player.lastName![0] : ''}'
            .toUpperCase();

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: isCheckedIn
            ? const Color(0xFF34C759).withOpacity(0.06)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(
          color: isCheckedIn
              ? const Color(0xFF34C759).withOpacity(0.3)
              : Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 5.w,
            backgroundColor: isCheckedIn
                ? const Color(0xFF34C759).withOpacity(0.2)
                : const Color(0xFFFF3B30).withOpacity(0.15),
            child: Text(
              initials.isNotEmpty ? initials : '?',
              style: TextStyle(
                  color: isCheckedIn
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF3B30),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : player.email,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600)),
                if (player.subscriptionPlan != null)
                  Text(player.subscriptionPlan!,
                      style: TextStyle(
                          color: Colors.white38, fontSize: 9.sp)),
              ],
            ),
          ),
          isCheckedIn
              ? Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 3.w, vertical: 0.8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_rounded,
                          color: Color(0xFF34C759), size: 14),
                      SizedBox(width: 1.w),
                      Text('In',
                          style: TextStyle(
                              color: const Color(0xFF34C759),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34C759),
                    padding: EdgeInsets.symmetric(
                        horizontal: 3.w, vertical: 1.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onCheckIn,
                  child: Text('Check In',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700)),
                ),
        ],
      ),
    );
  }
}
