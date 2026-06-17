import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../user/models/user_model.dart';
import '../../data/admin_repository.dart';
import '../screens/admin_dashboard_screen.dart';
import 'admin_subscription_plans_view.dart';
import 'admin_checkin_view.dart';

// ─── Admin More / Coaches View ────────────────────────────────────────────────

class AdminMoreView extends ConsumerWidget {
  const AdminMoreView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final gymId = user?.gymId ?? '';
    final adminUid = user?.uid ?? '';

    final coachesAsync = ref.watch(adminCoachesProvider(gymId));
    final playersAsync = ref.watch(adminPlayersProvider(gymId));
    final allPlayers = playersAsync.asData?.value ?? [];

    return SafeArea(
      child: Column(
        children: [
          _buildTopbar(context, ref, gymId),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(adminCoachesProvider(gymId));
                ref.invalidate(adminPlayersProvider(gymId));
              },
              color: const Color(0xFFFF3B30),
              backgroundColor: const Color(0xFF1C1C1E),
              child: ListView(
                padding: EdgeInsets.only(bottom: 12.h),
                children: [
                  _buildSettingsCard(context, ref, gymId, adminUid),
                  SizedBox(height: 1.h),
                  _buildCoachesSection(
                      context, ref, coachesAsync, allPlayers, gymId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopbar(BuildContext context, WidgetRef ref, String gymId) {
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
                      color: Colors.white, size: 12.sp),
                ),
              ),
              SizedBox(width: 3.w),
              Text(
                'Coaches & Settings',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => _showInviteCoachSheet(context, ref, gymId),
            child: Container(
              width: 9.w,
              height: 9.w,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFFF3B30).withOpacity(0.4)),
              ),
              child: Icon(Icons.person_add_rounded,
                  color: const Color(0xFFFF3B30), size: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings card ─────────────────────────────────────────────────────────

  Widget _buildSettingsCard(
      BuildContext context, WidgetRef ref, String gymId, String adminUid) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border:
            Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showGymSettingsSheet(context, ref, gymId),
            child: _buildSettingsRow(
              Icons.settings_rounded,
              'Gym Settings',
              'Manage business details',
              color: const Color(0xFF5BA8FF),
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.07), height: 3.h),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminSubscriptionPlansView(gymId: gymId),
              ),
            ),
            child: _buildSettingsRow(
              Icons.card_membership_rounded,
              'Subscription Plans',
              'Manage plan names, prices & durations',
              color: const Color(0xFFFF9500),
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.07), height: 3.h),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminCheckinView(
                    gymId: gymId, adminUid: adminUid),
              ),
            ),
            child: _buildSettingsRow(
              Icons.how_to_reg_rounded,
              'Attendance / Check-in',
              'Mark daily player attendance',
              color: const Color(0xFF34C759),
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.07), height: 3.h),
          GestureDetector(
            onTap: () {
              ref.read(authRepositoryProvider).signOut();
              context.go('/login');
            },
            child: Row(
              children: [
                Icon(Icons.logout_rounded,
                    color: const Color(0xFFFF3B30), size: 20.sp),
                SizedBox(width: 3.w),
                Text(
                  'Sign Out',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF3B30)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(IconData icon, String title, String sub,
      {Color? color}) {
    final c = color ?? Colors.white;
    return Row(
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: c.withOpacity(0.12),
            borderRadius: BorderRadius.circular(2.w),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: c, size: 15.sp),
        ),
        SizedBox(width: 3.5.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              SizedBox(height: 0.4.h),
              Text(sub,
                  style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white.withOpacity(0.5))),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16.sp),
      ],
    );
  }

  // ── Coaches section ───────────────────────────────────────────────────────

  Widget _buildCoachesSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<UserModel>> coachesAsync,
    List<UserModel> allPlayers,
    String gymId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4.5.w, 1.h, 4.5.w, 1.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVE COACHES',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 0.5,
                ),
              ),
              coachesAsync.when(
                data: (coaches) => Text(
                  '${coaches.length} total',
                  style: TextStyle(
                      fontSize: 11.sp, color: Colors.white.withOpacity(0.3)),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
        ),
        coachesAsync.when(
          data: (coaches) {
            if (coaches.isEmpty) {
              return Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 4.5.w, vertical: 4.h),
                child: Center(
                  child: Column(
                    children: [
                      Text('👨‍💼', style: TextStyle(fontSize: 36.sp)),
                      SizedBox(height: 1.h),
                      Text('No coaches yet',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 0.5.h),
                      Text('Tap + to invite a coach',
                          style:
                              TextStyle(color: Colors.white30, fontSize: 10.sp)),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: coaches
                  .map((c) =>
                      _buildCoachCard(context, ref, c, allPlayers, gymId))
                  .toList(),
            );
          },
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child:
                      CircularProgressIndicator(color: Color(0xFFFF3B30)))),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: Colors.white54))),
        ),
      ],
    );
  }

  Widget _buildCoachCard(
    BuildContext context,
    WidgetRef ref,
    UserModel coach,
    List<UserModel> allPlayers,
    String gymId,
  ) {
    final assigned =
        allPlayers.where((p) => p.assignedCoachUid == coach.uid).toList();
    final name = '${coach.firstName ?? ''} ${coach.lastName ?? ''}'.trim();

    return GestureDetector(
      onTap: () => _showCoachDetailSheet(
          context, ref, coach, assigned, allPlayers, gymId),
      child: Container(
        margin: EdgeInsets.only(left: 4.w, right: 4.w, bottom: 1.2.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border(
            top: BorderSide(
                color: Colors.white.withOpacity(0.07), width: 0.5),
            right: BorderSide(
                color: Colors.white.withOpacity(0.07), width: 0.5),
            bottom: BorderSide(
                color: Colors.white.withOpacity(0.07), width: 0.5),
            left: BorderSide(
                color: coach.isActive
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF3B30),
                width: 3),
          ),
          borderRadius: BorderRadius.circular(4.5.w),
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: EdgeInsets.all(3.5.w),
              child: Row(
                children: [
                  Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? coach.email : name,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 0.3.h),
                        Text(
                          coach.email,
                          style: TextStyle(
                            fontSize: 8.sp,
                            color: Colors.white.withOpacity(0.4),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 2.5.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: coach.isActive
                          ? const Color(0xFF34C759).withOpacity(0.15)
                          : const Color(0xFFFF3B30).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Text(
                      coach.isActive ? 'Active' : 'Suspended',
                      style: TextStyle(
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w700,
                        color: coach.isActive
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.white30, size: 14.sp),
                ],
              ),
            ),
            // Stats row — real data
            Container(
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.06), width: 0.5)),
              ),
              child: Row(
                children: [
                  _buildCoachStat('${assigned.length}', 'PLAYERS'),
                  _buildCoachStat(
                    assigned.isEmpty
                        ? '—'
                        : '${assigned.fold(0.0, (sum, p) => sum + (p.amountRemaining ?? 0)).toStringAsFixed(0)} JD',
                    'PENDING',
                  ),
                  _buildCoachStat(
                    coach.phone?.trim().isNotEmpty == true
                        ? coach.phone!
                        : '—',
                    'PHONE',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachStat(String val, String lbl, {bool isLast = false}) {
    return Expanded(
      child: Container(
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(
                    right: BorderSide(
                        color: Colors.white.withOpacity(0.06), width: 0.5)),
              ),
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 0.5.h),
            Text(
              lbl,
              style: TextStyle(
                fontSize: 7.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.3),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Coach detail sheet ────────────────────────────────────────────────────

  void _showCoachDetailSheet(
    BuildContext context,
    WidgetRef ref,
    UserModel coach,
    List<UserModel> assignedPlayers,
    List<UserModel> allPlayers,
    String gymId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CoachDetailSheet(
        coach: coach,
        assignedPlayers: assignedPlayers,
        allPlayers: allPlayers,
        gymId: gymId,
        adminRepo: ref.read(adminRepositoryProvider),
        onRefresh: () {
          ref.invalidate(adminCoachesProvider(gymId));
          ref.invalidate(adminPlayersProvider(gymId));
        },
      ),
    );
  }

  // ── Gym Settings sheet ────────────────────────────────────────────────────

  void _showGymSettingsSheet(
      BuildContext context, WidgetRef ref, String gymId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GymSettingsSheet(
        gymId: gymId,
        adminRepo: ref.read(adminRepositoryProvider),
      ),
    );
  }

  // ── Invite Codes sheet ────────────────────────────────────────────────────

  void _showInviteCodesSheet(
      BuildContext context, WidgetRef ref, String gymId, String adminUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteCodesSheet(
        gymId: gymId,
        adminUid: adminUid,
        adminRepo: ref.read(adminRepositoryProvider),
      ),
    );
  }

  // ── Invite coach sheet ────────────────────────────────────────────────────

  void _showInviteCoachSheet(
      BuildContext context, WidgetRef ref, String gymId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteCoachSheet(
        gymId: gymId,
        onInvited: () => ref.invalidate(adminCoachesProvider(gymId)),
      ),
    );
  }
}

// ─── Coach Detail Sheet ───────────────────────────────────────────────────────

class _CoachDetailSheet extends ConsumerStatefulWidget {
  final UserModel coach;
  final List<UserModel> assignedPlayers;
  final List<UserModel> allPlayers;
  final String gymId;
  final AdminRepository adminRepo;
  final VoidCallback onRefresh;

  const _CoachDetailSheet({
    required this.coach,
    required this.assignedPlayers,
    required this.allPlayers,
    required this.gymId,
    required this.adminRepo,
    required this.onRefresh,
  });

  @override
  ConsumerState<_CoachDetailSheet> createState() => _CoachDetailSheetState();
}

class _CoachDetailSheetState extends ConsumerState<_CoachDetailSheet> {
  bool _loading = false;
  int _tab = 0; // 0=info, 1=players

  String get _name =>
      '${widget.coach.firstName ?? ''} ${widget.coach.lastName ?? ''}'.trim();

  // ── Suspend / Reactivate ──────────────────────────────────────────────────

  Future<void> _toggleStatus() async {
    final newIsActive = !widget.coach.isActive;
    setState(() => _loading = true);
    try {
      await widget.adminRepo.updatePlayerStatus(
        gymId: widget.gymId,
        uid: widget.coach.uid,
        isActive: newIsActive,
      );
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
      _snack(newIsActive ? 'Coach reactivated ✅' : 'Coach suspended 🔴');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Demote to player ──────────────────────────────────────────────────────

  Future<void> _demoteToPlayer() async {
    final confirm = await _confirm(
        'Demote to Player?',
        '$_name will lose coach access and become a regular player.');
    if (!confirm) return;
    setState(() => _loading = true);
    try {
      await widget.adminRepo.updateMemberRole(
        gymId: widget.gymId,
        uid: widget.coach.uid,
        role: 'player',
      );
      widget.onRefresh();
      if (mounted) Navigator.pop(context);
      _snack('Demoted to player');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Assign player ─────────────────────────────────────────────────────────

  Future<void> _showAssignPlayer() async {
    final unassigned = widget.allPlayers
        .where((p) => p.assignedCoachUid != widget.coach.uid)
        .toList();

    if (unassigned.isEmpty) {
      _snack('All players are already assigned to this coach');
      return;
    }

    final selected = await showDialog<UserModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('Assign Player to $_name',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unassigned.length,
            itemBuilder: (_, i) {
              final p = unassigned[i];
              final pName =
                  '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white12,
                  child: Text(
                    pName.isNotEmpty ? pName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(pName.isEmpty ? p.email : pName,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(p.subscriptionPlan ?? 'No plan',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 9.sp)),
                onTap: () => Navigator.pop(ctx, p),
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
        ],
      ),
    );

    if (selected == null) return;
    setState(() => _loading = true);
    try {
      await widget.adminRepo.assignCoachToPlayer(
        playerUid: selected.uid,
        coachUid: widget.coach.uid,
        coachName: _name,
        gymId: widget.gymId,
      );
      widget.onRefresh();
      _snack('Player assigned ✅');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Remove player ─────────────────────────────────────────────────────────

  Future<void> _removePlayer(UserModel player) async {
    final pName =
        '${player.firstName ?? ''} ${player.lastName ?? ''}'.trim();
    final confirm = await _confirm(
        'Remove Player?', '$pName will be unassigned from this coach.');
    if (!confirm) return;
    setState(() => _loading = true);
    try {
      await widget.adminRepo.removeCoachFromPlayer(
        playerUid: player.uid,
        gymId: widget.gymId,
      );
      widget.onRefresh();
      _snack('Player removed from coach');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Edit coach info ───────────────────────────────────────────────────────

  void _showEditCoach() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditCoachSheet(
        coach: widget.coach,
        gymId: widget.gymId,
        adminRepo: widget.adminRepo,
        onSaved: () {
          widget.onRefresh();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(title,
            style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700)),
        content: Text(body,
            style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),

          _buildHeader(),
          SizedBox(height: 2.h),
          _buildTabBar(),
          SizedBox(height: 2.h),

          Flexible(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF3B30)))
                : _tab == 0
                    ? _buildInfoTab()
                    : _buildPlayersTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 14.w,
          height: 14.w,
          decoration: const BoxDecoration(
              color: Color(0xFF2C2C2E), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            _name.isNotEmpty ? _name[0].toUpperCase() : '?',
            style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
        ),
        SizedBox(width: 3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name.isEmpty ? widget.coach.email : _name,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 0.4.h),
              Text(widget.coach.email,
                  style: TextStyle(color: Colors.white54, fontSize: 10.sp)),
            ],
          ),
        ),
        GestureDetector(
          onTap: _showEditCoach,
          child: Container(
            padding: EdgeInsets.all(2.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: Icon(Icons.edit_rounded,
                color: Colors.white70, size: 16.sp),
          ),
        ),
        SizedBox(width: 2.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
          decoration: BoxDecoration(
            color: widget.coach.isActive
                ? Colors.green.withOpacity(0.15)
                : Colors.red.withOpacity(0.15),
            borderRadius: BorderRadius.circular(2.w),
          ),
          child: Text(
            widget.coach.isActive ? 'Active' : 'Suspended',
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: widget.coach.isActive
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(3.w),
      ),
      child: Row(
        children: [
          _tabBtn(0, 'Info & Actions'),
          _tabBtn(1, 'Players (${widget.assignedPlayers.length})'),
        ],
      ),
    );
  }

  Widget _tabBtn(int index, String label) {
    final sel = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.2.h),
          decoration: BoxDecoration(
            color: sel
                ? Colors.white.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(3.w),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }

  // ── Info tab ──────────────────────────────────────────────────────────────

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _infoRow('Phone',
              widget.coach.phone?.trim().isNotEmpty == true
                  ? widget.coach.phone!
                  : '—'),
          _infoRow('Gym ID', widget.gymId),
          _infoRow('Players Assigned', '${widget.assignedPlayers.length}'),
          _infoRow(
            'Pending Collection',
            '${widget.assignedPlayers.fold(0.0, (s, p) => s + (p.amountRemaining ?? 0)).toStringAsFixed(0)} JD',
          ),

          SizedBox(height: 3.h),
          Divider(color: Colors.white.withOpacity(0.08)),
          SizedBox(height: 2.h),

          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Assign Player',
                  color: const Color(0xFF5BA8FF),
                  onTap: _showAssignPlayer,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _actionBtn(
                  icon: widget.coach.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_rounded,
                  label: widget.coach.isActive ? 'Suspend' : 'Reactivate',
                  color: widget.coach.isActive
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF34C759),
                  onTap: _toggleStatus,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            height: 5.5.h,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.orange.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.w)),
              ),
              onPressed: _demoteToPlayer,
              icon: Icon(Icons.swap_horiz_rounded,
                  color: Colors.orange, size: 16.sp),
              label: Text('Demote to Player',
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700)),
        ],
      ),
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
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ── Players tab ───────────────────────────────────────────────────────────

  Widget _buildPlayersTab() {
    if (widget.assignedPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏋️', style: TextStyle(fontSize: 36.sp)),
            SizedBox(height: 1.h),
            Text('No players assigned',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 0.5.h),
            Text('Tap "Assign Player" in the Info tab',
                style: TextStyle(color: Colors.white30, fontSize: 10.sp)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: widget.assignedPlayers.length,
      itemBuilder: (_, i) {
        final p = widget.assignedPlayers[i];
        final pName =
            '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
        final isExpired =
            p.subscriptionEnd?.isBefore(DateTime.now()) == true;

        return Container(
          margin: EdgeInsets.only(bottom: 1.2.h),
          padding: EdgeInsets.all(3.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(3.w),
            border: Border.all(
                color: Colors.white.withOpacity(0.07), width: 0.5),
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
                  pName.isNotEmpty ? pName[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pName.isEmpty ? p.email : pName,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 0.3.h),
                    Text(
                      isExpired
                          ? '🔴 Expired'
                          : (p.isActive ? '🟢 Active' : '🔴 Suspended'),
                      style: TextStyle(
                          fontSize: 8.sp,
                          color: Colors.white.withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(p.amountRemaining ?? 0).toStringAsFixed(0)} JD',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: (p.amountRemaining ?? 0) > 0
                          ? const Color(0xFFFF9500)
                          : const Color(0xFF34C759),
                    ),
                  ),
                  Text('remaining',
                      style: TextStyle(
                          fontSize: 7.sp,
                          color: Colors.white.withOpacity(0.3))),
                ],
              ),
              SizedBox(width: 2.w),
              GestureDetector(
                onTap: () => _removePlayer(p),
                child: Container(
                  padding: EdgeInsets.all(1.5.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Icon(Icons.link_off_rounded,
                      color: const Color(0xFFFF3B30), size: 14.sp),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Edit Coach Sheet ─────────────────────────────────────────────────────────

class _EditCoachSheet extends StatefulWidget {
  final UserModel coach;
  final String gymId;
  final AdminRepository adminRepo;
  final VoidCallback onSaved;

  const _EditCoachSheet({
    required this.coach,
    required this.gymId,
    required this.adminRepo,
    required this.onSaved,
  });

  @override
  State<_EditCoachSheet> createState() => _EditCoachSheetState();
}

class _EditCoachSheetState extends State<_EditCoachSheet> {
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.coach.firstName ?? '');
    _lastCtrl = TextEditingController(text: widget.coach.lastName ?? '');
    _phoneCtrl = TextEditingController(text: widget.coach.phone ?? '');
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_firstCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('First name is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.adminRepo.updateCoachInfo(
        gymId: widget.gymId,
        coachUid: widget.coach.uid,
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Coach updated ✅')));
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
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
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
            Text('Edit Coach',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 0.5.h),
            Text(widget.coach.email,
                style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
            SizedBox(height: 3.h),

            Row(
              children: [
                Expanded(child: _field(_firstCtrl, 'First Name')),
                SizedBox(width: 3.w),
                Expanded(child: _field(_lastCtrl, 'Last Name')),
              ],
            ),
            SizedBox(height: 2.h),
            _field(_phoneCtrl, 'Phone', keyboardType: TextInputType.phone),

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
                    : Text('Save',
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
      style: TextStyle(color: Colors.white, fontSize: 12.sp),
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

// ─── Gym Settings Sheet ───────────────────────────────────────────────────────

class _GymSettingsSheet extends StatefulWidget {
  final String gymId;
  final AdminRepository adminRepo;
  const _GymSettingsSheet({required this.gymId, required this.adminRepo});

  @override
  State<_GymSettingsSheet> createState() => _GymSettingsSheetState();
}

class _GymSettingsSheetState extends State<_GymSettingsSheet> {
  final _nameCtrl    = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = true;
  bool _saving  = false;
  String _gymCode = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.adminRepo.getGymSettings(widget.gymId);
      _nameCtrl.text    = data['gymName']  as String? ?? '';
      _cityCtrl.text    = data['gymCity']  as String? ?? '';
      _phoneCtrl.text   = data['phone']    as String? ?? '';
      _addressCtrl.text = data['address']  as String? ?? '';
      _gymCode          = data['gymCode']  as String? ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gym name is required')));
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.adminRepo.updateGymSettings(
        gymId:   widget.gymId,
        gymName: _nameCtrl.text,
        gymCity: _cityCtrl.text,
        phone:   _phoneCtrl.text,
        address: _addressCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gym settings saved ✅')));
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
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w,
          MediaQuery.of(context).viewInsets.bottom + 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 12.w, height: 4,
                      margin: EdgeInsets.only(bottom: 2.h),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5BA8FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2.w),
                        ),
                        child: Icon(Icons.settings_rounded,
                            color: const Color(0xFF5BA8FF), size: 16.sp),
                      ),
                      SizedBox(width: 3.w),
                      Text('Gym Settings',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  if (_gymCode.isNotEmpty) ...[
                    SizedBox(height: 1.5.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_rounded,
                              color: Colors.white54, size: 14.sp),
                          SizedBox(width: 2.w),
                          Text('Gym Code: ',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12.sp)),
                          Text(_gymCode,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 3.h),
                  _field(_nameCtrl, 'Gym Name *'),
                  SizedBox(height: 2.h),
                  _field(_cityCtrl, 'City'),
                  SizedBox(height: 2.h),
                  _field(_phoneCtrl, 'Phone',
                      keyboardType: TextInputType.phone),
                  SizedBox(height: 2.h),
                  _field(_addressCtrl, 'Address'),
                  SizedBox(height: 4.h),
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
                          ? const CircularProgressIndicator(
                              color: Colors.white)
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

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
      decoration: InputDecoration(
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
      ),
    );
  }
}

// ─── Invite Codes Sheet ───────────────────────────────────────────────────────

class _InviteCodesSheet extends StatefulWidget {
  final String gymId;
  final String adminUid;
  final AdminRepository adminRepo;

  const _InviteCodesSheet({
    required this.gymId,
    required this.adminUid,
    required this.adminRepo,
  });

  @override
  State<_InviteCodesSheet> createState() => _InviteCodesSheetState();
}

class _InviteCodesSheetState extends State<_InviteCodesSheet> {
  final _emailCtrl = TextEditingController();
  String _role = 'player';
  bool _adding = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _addInvite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid email')));
      return;
    }
    setState(() => _adding = true);
    try {
      await widget.adminRepo.inviteMember(
        gymId:      widget.gymId,
        email:      email,
        role:       _role,
        addedByUid: widget.adminUid,
      );
      _emailCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$email invited as $_role ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _revoke(String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('Revoke Invite?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700)),
        content: Text(
            '$email will no longer be able to join this gym.',
            style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Revoke',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.adminRepo.removeInvite(
          gymId: widget.gymId, email: email);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invite revoked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w,
          MediaQuery.of(context).viewInsets.bottom + 2.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──
          Center(
            child: Container(
              width: 12.w, height: 4,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          // ── Header ──
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFBF5AF2).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Icon(Icons.group_add_rounded,
                    color: const Color(0xFFBF5AF2), size: 16.sp),
              ),
              SizedBox(width: 3.w),
              Text('Invite Codes',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          SizedBox(height: 2.h),

          // ── Add invite form ──
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(3.w),
              border: Border.all(
                  color: Colors.white.withOpacity(0.08), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ADD INVITE',
                    style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white38,
                        letterSpacing: 0.5)),
                SizedBox(height: 1.5.h),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style:
                      TextStyle(color: Colors.white, fontSize: 11.sp),
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    hintStyle:
                        TextStyle(color: Colors.white24, fontSize: 11.sp),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 3.w, vertical: 1.2.h),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2.w),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 1.h),
                Row(
                  children: [
                    _roleChip('player', 'Player'),
                    SizedBox(width: 2.w),
                    _roleChip('coach', 'Coach'),
                    const Spacer(),
                    SizedBox(
                      height: 4.5.h,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFBF5AF2),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(2.w)),
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w),
                        ),
                        onPressed: _adding ? null : _addInvite,
                        child: _adding
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : Text('Invite',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight:
                                        FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),

          // ── Invite list header ──
          Text('EXISTING INVITES',
              style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white38,
                  letterSpacing: 0.5)),
          SizedBox(height: 1.h),

          // ── Stream of existing invites ──
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream:
                  widget.adminRepo.getMemberEmailsStream(widget.gymId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF3B30)));
                }
                final invites = snap.data ?? [];
                if (invites.isEmpty) {
                  return Center(
                    child: Text('No invites yet',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 11.sp)),
                  );
                }
                return ListView.builder(
                  itemCount: invites.length,
                  itemBuilder: (_, i) {
                    final inv  = invites[i];
                    final email = inv['email'] as String? ?? '';
                    final role  = inv['role']  as String? ?? 'player';
                    final isCoach = role == 'coach';
                    final roleColor = isCoach
                        ? const Color(0xFF5BA8FF)
                        : const Color(0xFF34C759);

                    return Container(
                      margin: EdgeInsets.only(bottom: 1.h),
                      padding: EdgeInsets.symmetric(
                          horizontal: 3.w, vertical: 1.2.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(2.5.w),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.07),
                            width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2.w, vertical: 0.3.h),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(1.5.w),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 7.sp,
                                  fontWeight: FontWeight.w800,
                                  color: roleColor),
                            ),
                          ),
                          SizedBox(width: 2.5.w),
                          Expanded(
                            child: Text(
                              email,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _revoke(email),
                            child: Container(
                              padding: EdgeInsets.all(1.5.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30)
                                    .withOpacity(0.1),
                                borderRadius:
                                    BorderRadius.circular(1.5.w),
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: const Color(0xFFFF3B30),
                                  size: 12.sp),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  Widget _roleChip(String value, String label) {
    final sel = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
        decoration: BoxDecoration(
          color: sel
              ? const Color(0xFFBF5AF2).withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(2.w),
          border: Border.all(
              color: sel
                  ? const Color(0xFFBF5AF2).withOpacity(0.5)
                  : Colors.white.withOpacity(0.08)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: sel
                    ? const Color(0xFFBF5AF2)
                    : Colors.white38)),
      ),
    );
  }
}

// ─── Add Coach Sheet — creates full account + opens SMS ──────────────────────

class _InviteCoachSheet extends StatefulWidget {
  final String gymId;
  final VoidCallback onInvited;

  const _InviteCoachSheet({required this.gymId, required this.onInvited});

  @override
  State<_InviteCoachSheet> createState() => _InviteCoachSheetState();
}

class _InviteCoachSheetState extends State<_InviteCoachSheet> {
  final _firstCtrl    = TextEditingController();
  final _lastCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _saving        = false;
  bool _showPassword  = false;

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
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AdminRepository repo, String addedByUid) async {
    final first = _firstCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (first.isEmpty) {
      _snack('First name is required');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _snack('Enter a valid email');
      return;
    }
    if (phone.isEmpty) {
      _snack('Phone number is required to send SMS');
      return;
    }
    if (password.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }

    setState(() => _saving = true);
    try {
      await repo.addCoach(
        gymId:      widget.gymId,
        email:      email,
        password:   password,
        firstName:  first,
        lastName:   _lastCtrl.text.trim(),
        phone:      phone,
        addedByUid: addedByUid,
      );

      widget.onInvited();

      if (mounted) Navigator.pop(context);

      // Open native SMS app with credentials pre-filled
      final coachName = '$first ${_lastCtrl.text.trim()}'.trim();
      final smsBody = Uri.encodeComponent(
        'مرحباً $coachName 👋\n'
        'تم إضافتك كمدرب في تطبيق NEXUS.\n'
        'بيانات الدخول:\n'
        'الإيميل: $email\n'
        'كلمة المرور: $password\n'
        'حمّل التطبيق وسجّل دخولك مباشرة.',
      );

      // Clean phone — strip spaces/dashes for the SMS URL
      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
      final smsUri = Uri.parse('sms:$cleanPhone?body=$smsBody');

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        // Fallback: just show snackbar with credentials
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Coach account created ✅\nEmail: $email'),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (ctx, ref, _) {
      final adminUid =
          ref.watch(authStateProvider).asData?.value?.uid ?? '';
      final repo = ref.read(adminRepositoryProvider);

      return Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
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
                  width: 12.w, height: 4,
                  margin: EdgeInsets.only(bottom: 2.h),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              Text('Add Coach',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 0.5.h),
              Text(
                'Creates a full account immediately — credentials sent by SMS.',
                style: TextStyle(color: Colors.white54, fontSize: 13.sp),
              ),
              SizedBox(height: 3.h),

              Row(children: [
                Expanded(child: _field(_firstCtrl, 'First Name *')),
                SizedBox(width: 3.w),
                Expanded(child: _field(_lastCtrl, 'Last Name')),
              ]),
              SizedBox(height: 2.h),
              _field(_emailCtrl, 'Email *',
                  keyboardType: TextInputType.emailAddress),
              SizedBox(height: 2.h),
              _field(_phoneCtrl, 'Phone * (for SMS)',
                  keyboardType: TextInputType.phone),
              SizedBox(height: 2.h),

              // Password with show/hide toggle
              TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: 'Temporary Password *',
                  labelStyle:
                      TextStyle(color: Colors.white54, fontSize: 12.sp),
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
                          _showPassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
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
              SizedBox(height: 0.8.h),
              Text(
                'Auto-generated — tap 🔄 to regenerate. SMS will open with credentials pre-filled.',
                style: TextStyle(color: Colors.white38, fontSize: 11.sp),
              ),

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
                  onPressed: _saving ? null : () => _save(repo, adminUid),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Create Account & Send SMS',
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
    });
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.white, fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54, fontSize: 12.sp),
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
