import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../core/localization/app_localizations.dart';
import '../../../user/models/user_model.dart';
import '../../data/coach_repository.dart';

class CoachNotificationsView extends ConsumerStatefulWidget {
  const CoachNotificationsView({super.key});

  @override
  ConsumerState<CoachNotificationsView> createState() =>
      _CoachNotificationsViewState();
}

class _CoachNotificationsViewState
    extends ConsumerState<CoachNotificationsView> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _selectedPlayerUid = 'all';
  String _selectedType = 'coach_feedback';
  String _searchQuery = '';
  bool _isSending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(coachMembersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(context),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(coachMembersProvider);
                  ref.invalidate(coachSentNotificationsProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 4.h, top: 1.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('coach_send_new'.tr(context)),
                      _buildComposer(context, playersAsync),
                      SizedBox(height: 2.h),
                      _buildSectionHeader('coach_sent_by_you'.tr(context)),
                      _buildFirebaseHistoryList(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopbar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
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
                Icons.arrow_back_ios_new_rounded,
                size: 15.sp,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          Text(
            'notifications'.tr(context),
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(width: 10.w),
        ],
      ),
    );
  }

  Widget _buildComposer(
    BuildContext context,
    AsyncValue<List<UserModel>> playersAsync,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 11.w,
                height: 11.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5FF),
                  borderRadius: BorderRadius.circular(2.5.w),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: const Color(0xFF007AFF),
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'coach_send_to_players'.tr(context),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                    SizedBox(height: 0.3.h),
                    Text(
                      'coach_select_players_desc'.tr(context),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          _buildLabel('coach_recipients'.tr(context)),
          _buildRecipientsSelector(context, playersAsync),
          SizedBox(height: 1.5.h),
          _buildLabel('coach_type'.tr(context)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypePill('coach_feedback'.tr(context), 'coach_feedback'),
                _buildTypePill('coach_plan'.tr(context), 'coach_plan'),
                _buildTypePill('coach_reminder'.tr(context), 'coach_reminder'),
                _buildTypePill(
                  'coach_motivation'.tr(context),
                  'coach_motivation',
                ),
              ],
            ),
          ),
          SizedBox(height: 1.5.h),
          TextField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('coach_title_placeholder'.tr(context)),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 1.h),
          TextField(
            controller: _bodyCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: _inputDecoration(
              'coach_message_placeholder'.tr(context),
            ),
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF1C1C1E)),
          ),
          SizedBox(height: 1.5.h),
          ElevatedButton(
            onPressed: _isSending
                ? null
                : () => _sendNotification(playersAsync.asData?.value ?? []),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              disabledBackgroundColor: const Color(0xFFB5D4F4),
              minimumSize: Size(double.infinity, 5.8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3.w),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSending)
                  SizedBox(
                    width: 5.w,
                    height: 5.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(Icons.send_rounded, color: Colors.white, size: 18.sp),
                SizedBox(width: 2.w),
                Flexible(
                  child: Text(
                    _sendButtonText(playersAsync.asData?.value ?? []),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
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
    BuildContext context,
    AsyncValue<List<UserModel>> playersAsync,
  ) {
    return playersAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: 1.h),
        child: const LinearProgressIndicator(color: Color(0xFF007AFF)),
      ),
      error: (err, stack) => Text(
        '${'error_prefix'.tr(context)} $err',
        style: TextStyle(fontSize: 12.sp, color: const Color(0xFFE53935)),
      ),
      data: (players) {
        if (players.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 1.h),
            child: Text(
              'add_players_first_notifications'.tr(context),
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
            ),
          );
        }

        final query = _searchQuery.trim().toLowerCase();
        final filtered = query.isEmpty
            ? players
            : players
                  .where(
                    (player) =>
                        _playerName(player).toLowerCase().contains(query),
                  )
                  .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: _inputDecoration('search_player'.tr(context))
                  .copyWith(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF8E8E93),
                    ),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                  ),
              style: TextStyle(fontSize: 13.sp, color: const Color(0xFF1C1C1E)),
            ),
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: [
                if (query.isEmpty)
                  _buildRecipientChip(
                    label:
                        '${'coach_all_players'.tr(context)} (${players.length})',
                    selected: _selectedPlayerUid == 'all',
                    onTap: () => setState(() => _selectedPlayerUid = 'all'),
                  ),
                ...filtered.map(
                  (player) => _buildRecipientChip(
                    label: _playerName(player),
                    selected: _selectedPlayerUid == player.uid,
                    onTap: () =>
                        setState(() => _selectedPlayerUid = player.uid),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecipientChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.9.h),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(2.5.w),
          border: Border.all(
            color: selected ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }

  Widget _buildTypePill(String label, String type) {
    final selected = _selectedType == type;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: 2.w),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => setState(() => _selectedType = type),
        selectedColor: const Color(0xFF007AFF),
        backgroundColor: const Color(0xFFF5F5F7),
        labelStyle: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : const Color(0xFF1C1C1E),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
        side: BorderSide(
          color: selected ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
        ),
      ),
    );
  }

  Widget _buildFirebaseHistoryList(BuildContext context) {
    final sentAsync = ref.watch(coachSentNotificationsProvider);

    return sentAsync.when(
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Text(
          '${'error_prefix'.tr(context)} $err',
          style: TextStyle(fontSize: 12.sp, color: const Color(0xFFE53935)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Text(
                'coach_no_notifications_sent_yet'.tr(context),
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Column(
            children: items.map((item) {
              final recipient = item.targetCount == 1
                  ? (item.targetNames.isEmpty
                        ? 'player'.tr(context)
                        : item.targetNames.first)
                  : '${'coach_all_players'.tr(context)} (${item.targetCount})';
              return Padding(
                padding: EdgeInsets.only(bottom: 1.h),
                child: _buildHistoryCard(
                  icon: _typeIcon(item.type),
                  bg: _typeBg(item.type),
                  title: '$recipient -> ${item.title}',
                  body: item.body,
                  time: timeago.format(item.createdAt),
                  stat: 'delivered_count'
                      .tr(context)
                      .replaceAll('{count}', '${item.targetCount}'),
                  statColor: const Color(0xFF1A7A30),
                  statBg: const Color(0xFFE8FFF0),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _sendNotification(List<UserModel> players) async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (players.isEmpty) {
      _showSnack('add_players_first_notifications'.tr(context));
      return;
    }
    if (title.isEmpty || body.isEmpty) {
      _showSnack('Write a title and message.');
      return;
    }

    final targets = _selectedPlayerUid == 'all'
        ? players
        : players.where((player) => player.uid == _selectedPlayerUid).toList();
    if (targets.isEmpty) {
      _showSnack('Select a player.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref
          .read(coachRepositoryProvider)
          .sendQuickNotification(
            targets: targets,
            title: title,
            body: body,
            type: _selectedType,
          );
      _titleCtrl.clear();
      _bodyCtrl.clear();
      if (mounted) {
        setState(() {
          _selectedPlayerUid = 'all';
          _selectedType = 'coach_feedback';
        });
      }
      _showSnack('Notification sent.');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _sendButtonText(List<UserModel> players) {
    if (_isSending) return 'Sending...';
    if (players.isEmpty) return 'No Players';
    if (_selectedPlayerUid == 'all') return 'Send to All ${players.length}';

    final selected = players.where((p) => p.uid == _selectedPlayerUid).toList();
    if (selected.isEmpty) return 'Select a Player';
    return 'Send to ${_playerName(selected.first)}';
  }

  String _playerName(UserModel player) {
    final name = [player.firstName, player.lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .join(' ');
    if (name.isNotEmpty) return name;
    if (player.email.trim().isNotEmpty) return player.email.split('@').first;
    return 'Player';
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
      filled: true,
      fillColor: const Color(0xFFF9F9FB),
      contentPadding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.4.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2.5.w),
        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2.5.w),
        borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2.5.w),
        borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.7.h),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF8E8E93),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF8E8E93),
        ),
      ),
    );
  }

  String _typeIcon(String type) {
    switch (type) {
      case 'coach_plan':
      case 'plan':
        return 'P';
      case 'coach_reminder':
      case 'reminder':
        return '!';
      case 'coach_motivation':
      case 'motivation':
        return 'M';
      default:
        return 'F';
    }
  }

  Color _typeBg(String type) {
    switch (type) {
      case 'coach_plan':
      case 'plan':
        return const Color(0xFFE8FFF0);
      case 'coach_reminder':
      case 'reminder':
        return const Color(0xFFFFF8E8);
      case 'coach_motivation':
      case 'motivation':
        return const Color(0xFFF0EEFF);
      default:
        return const Color(0xFFE8F5FF);
    }
  }

  Widget _buildHistoryCard({
    required String icon,
    required Color bg,
    required String title,
    required String body,
    required String time,
    required String stat,
    required Color statColor,
    required Color statBg,
  }) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 11.w,
            height: 11.w,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2.w),
            ),
            alignment: Alignment.center,
            child: Text(
              icon,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 0.4.h),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF6E6E73),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFFC7C7CC),
                ),
              ),
              SizedBox(height: 0.6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
                decoration: BoxDecoration(
                  color: statBg,
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text(
                  stat,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: statColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
