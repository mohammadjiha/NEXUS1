import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../user/models/user_model.dart';
import '../../data/coach_repository.dart';

class CoachPlayersView extends ConsumerStatefulWidget {
  const CoachPlayersView({super.key});

  @override
  ConsumerState<CoachPlayersView> createState() => _CoachPlayersViewState();
}

class _CoachPlayersViewState extends ConsumerState<CoachPlayersView> {
  String _searchQuery = '';
  String _selectedFilter = 'coach_all';

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(coachMembersProvider);

    return SafeArea(
      child: Column(
        children: [
          _buildTopbar(context),
          Expanded(
            child: playersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: EdgeInsets.all(5.w),
                  child: Text(
                    'error_prefix'.tr(context) + error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.sp, color: Colors.red),
                  ),
                ),
              ),
              data: (players) => _buildPlayersList(context, players),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopbar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'coach_players_dashboard'.tr(context),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/members_management'),
            child: Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.manage_accounts_rounded,
                size: 15.sp,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList(BuildContext context, List<UserModel> players) {
    if (players.isEmpty && _searchQuery.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.groups_2_outlined,
                size: 42.sp,
                color: const Color(0xFFC7C7CC),
              ),
              SizedBox(height: 2.h),
              Text(
                'coach_no_players_linked_yet'.tr(context),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'coach_players_appear_here'.tr(context),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final activeCount = players.where((player) => !_isExpired(player)).length;
    final attentionCount = players.where(_needsAttention).length;

    // Filter Logic
    var filteredPlayers = players.where((p) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final name = _displayName(p).toLowerCase();
      final email = p.email.toLowerCase();
      final phone = p.phone?.toLowerCase() ?? '';
      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();

    if (_selectedFilter != 'coach_all') {
      filteredPlayers = filteredPlayers.where((p) {
        if (_selectedFilter == 'coach_attention') return _needsAttention(p);
        if (_selectedFilter == 'coach_inactive') return _isExpired(p);
        if (_selectedFilter == 'coach_active') return !_isExpired(p);
        return true;
      }).toList();
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: 12.h, top: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                Expanded(
                  child: _summaryTile(
                    'coach_players'.tr(context),
                    '${players.length}',
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _summaryTile(
                    'coach_active'.tr(context),
                    '$activeCount',
                  ),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: _summaryTile(
                    'coach_attention'.tr(context),
                    '$attentionCount',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),

          // SEARCH BAR
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'coach_search_players'.tr(context),
                hintStyle: TextStyle(
                  color: const Color(0xFF8E8E93),
                  fontSize: 12.sp,
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8E8E93)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(vertical: 1.5.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3.w),
                  borderSide: const BorderSide(
                    color: Color(0xFFE5E5EA),
                    width: 0.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3.w),
                  borderSide: const BorderSide(
                    color: Color(0xFFE5E5EA),
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(3.w),
                  borderSide: const BorderSide(color: Color(0xFF1C1C1E)),
                ),
              ),
            ),
          ),
          SizedBox(height: 1.5.h),

          // FILTERS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                _buildFilterChip(context, 'coach_all'),
                _buildFilterChip(context, 'coach_active'),
                _buildFilterChip(context, 'coach_attention'),
                _buildFilterChip(context, 'coach_inactive'),
              ],
            ),
          ),
          SizedBox(height: 2.h),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
            child: Text(
              '${filteredPlayers.length} ${'coach_players_found'.tr(context)}',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF8E8E93),
                letterSpacing: 0.5,
              ),
            ),
          ),

          if (filteredPlayers.isEmpty)
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Center(
                child: Text(
                  'coach_no_players_match'.tr(context),
                  style: TextStyle(
                    color: const Color(0xFF8E8E93),
                    fontSize: 12.sp,
                  ),
                ),
              ),
            )
          else
            ...filteredPlayers.map(
              (player) => Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: _buildPlayerCard(context, player),
              ),
            ),

          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/members_management'),
              icon: const Icon(Icons.manage_accounts_rounded),
              label: Text('coach_manage_player_access'.tr(context)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1C1C1E),
                minimumSize: Size(double.infinity, 5.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.w),
                  side: const BorderSide(color: Color(0xFFD1D1D6), width: 0.5),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      child: Container(
        margin: EdgeInsetsDirectional.only(end: 2.w),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1C1C1E)
                : const Color(0xFFE5E5EA),
          ),
        ),
        child: Text(
          filterKey.tr(context),
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF6E6E73),
          ),
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(BuildContext context, UserModel player) {
    final status = _status(player);
    final name = _displayName(player);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.w),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: status.color, width: 3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(4.w),
              onTap: () => context.push('/coach_player_detail', extra: player),
              child: Padding(
                padding: EdgeInsets.all(3.w),
                child: Row(
                  children: [
                    Container(
                      width: 13.w,
                      height: 13.w,
                      decoration: BoxDecoration(
                        color: status.bg,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: EdgeInsets.all(1.w),
                          child: Text(
                            _initials(player),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                              color: status.color,
                            ),
                          ),
                        ),
                      ),
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
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          SizedBox(height: 0.3.h),
                          Text(
                            _meta(player, context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.5.w,
                        vertical: 0.7.h,
                      ),
                      decoration: BoxDecoration(
                        color: status.bg,
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      child: Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: status.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _displayName(UserModel player) {
    final name = [
      player.firstName,
      player.lastName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');
    return name.trim().isEmpty ? player.email : name.trim();
  }

  String _initials(UserModel player) {
    final first = (player.firstName ?? player.email).trim();
    final last = (player.lastName ?? '').trim();
    final raw =
        '${first.isNotEmpty ? first[0] : 'P'}${last.isNotEmpty ? last[0] : ''}';
    return raw.toUpperCase();
  }

  String _meta(UserModel player, BuildContext context) {
    final goal = _label(player.goal ?? 'get_fit');
    final weight = player.weight == null
        ? '-'
        : '${player.weight!.toStringAsFixed(0)} kg';
    final height = player.height == null
        ? '-'
        : '${player.height!.toStringAsFixed(0)} cm';
    final coach = player.assignedCoachName?.trim().isEmpty == false
        ? player.assignedCoachName!.trim()
        : 'coach'.tr(context);
    return '$goal - $weight - $height - $coach';
  }

  String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  bool _isExpired(UserModel player) {
    final end = player.subscriptionEnd;
    return end != null && end.isBefore(DateTime.now());
  }

  bool _needsAttention(UserModel player) {
    final remaining = player.amountRemaining ?? 0;
    final end = player.subscriptionEnd;
    final expiring = end != null && end.difference(DateTime.now()).inDays <= 7;
    return remaining > 0 || expiring;
  }

  _PlayerStatus _status(UserModel player) {
    final remaining = player.amountRemaining ?? 0;
    final end = player.subscriptionEnd;
    if (remaining > 0) {
      return _PlayerStatus(
        'coach_payment'.tr(context),
        const Color(0xFFE53935),
        const Color(0xFFFFF0F0),
      );
    }
    if (end != null && end.isBefore(DateTime.now())) {
      return _PlayerStatus(
        'coach_expired'.tr(context),
        const Color(0xFFE53935),
        const Color(0xFFFFF0F0),
      );
    }
    if (end != null && end.difference(DateTime.now()).inDays <= 7) {
      return _PlayerStatus(
        'coach_expiring'.tr(context),
        const Color(0xFFFF9500),
        const Color(0xFFFFF8E8),
      );
    }
    return _PlayerStatus(
      'coach_active'.tr(context),
      const Color(0xFF1A7A30),
      const Color(0xFFE8FFF0),
    );
  }
}

class _PlayerStatus {
  final String label;
  final Color color;
  final Color bg;

  const _PlayerStatus(this.label, this.color, this.bg);
}
