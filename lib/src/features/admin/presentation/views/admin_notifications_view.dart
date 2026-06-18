import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/admin_repository.dart';
import '../screens/admin_dashboard_screen.dart';

final adminNotifHistoryProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, gymId) {
  return ref.watch(adminRepositoryProvider).getNotificationHistory(gymId);
});

class AdminNotificationsView extends ConsumerStatefulWidget {
  const AdminNotificationsView({super.key});

  @override
  ConsumerState<AdminNotificationsView> createState() =>
      _AdminNotificationsViewState();
}

class _AdminNotificationsViewState
    extends ConsumerState<AdminNotificationsView>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  late final TabController _tab;

  List<String> _selectedGroups = ['all_players'];
  String _selectedType = 'general';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _toggleGroup(String group) {
    setState(() {
      if (_selectedGroups.contains(group)) {
        _selectedGroups.remove(group);
      } else {
        _selectedGroups.add(group);
      }
    });
  }

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty ||
        _selectedGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please fill all fields and select a group.')));
      return;
    }
    setState(() => _isSending = true);
    try {
      final user = ref.read(currentUserModelProvider).asData?.value;
      if (user != null) {
        final gymId = user.gymId ?? '';
        final repo = ref.read(adminRepositoryProvider);

        // Write to admin_notifications for history
        await repo.sendNotification(
          gymId: gymId,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          type: _selectedType,
          targetGroups: _selectedGroups,
          adminUid: user.uid,
        );

        // Also fan-out to each targeted player's notifications subcollection
        final playersAsync =
            ref.read(adminPlayersProvider(gymId)).asData?.value ?? [];
        final coachesAsync =
            ref.read(adminCoachesProvider(gymId)).asData?.value ?? [];

        final targets = <String>[];
        if (_selectedGroups.contains('all_players')) {
          targets.addAll(playersAsync.map((p) => p.uid));
        } else {
          if (_selectedGroups.contains('active')) {
            targets.addAll(
                playersAsync.where((p) => p.isActive).map((p) => p.uid));
          }
          if (_selectedGroups.contains('expiring')) {
            final now = DateTime.now();
            targets.addAll(playersAsync
                .where((p) =>
                    p.subscriptionEnd != null &&
                    p.subscriptionEnd!.difference(now).inDays <= 7 &&
                    p.subscriptionEnd!.difference(now).inDays >= 0)
                .map((p) => p.uid));
          }
        }
        if (_selectedGroups.contains('all_coaches')) {
          targets.addAll(coachesAsync.map((c) => c.uid));
        }

        for (final uid in targets.toSet()) {
          await repo.sendDirectNotificationToUser(
            targetUid: uid,
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            type: _selectedType,
            senderUid: user.uid,
          );
        }

        _titleController.clear();
        _bodyController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Sent to ${targets.toSet().length} member(s) ✅')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final gymId = user?.gymId ?? '';
    final historyAsync = ref.watch(adminNotifHistoryProvider(gymId));
    final inboxAsync = ref.watch(superAdminMessagesProvider(gymId));

    // Unread count for badge
    final inboxData = inboxAsync.asData?.value ?? [];
    final unreadCount = inboxData.where((m) => m['read'] != true).length;

    return SafeArea(
      child: Column(
        children: [
          _buildTopbar(context, ref),
          // Tab bar
          Container(
            margin:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
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
              labelStyle: TextStyle(
                  fontSize: 13.sp, fontWeight: FontWeight.w700),
              unselectedLabelStyle: TextStyle(
                  fontSize: 13.sp, fontWeight: FontWeight.w600),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white38,
              tabs: [
                const Tab(text: 'Broadcast'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Super Admin Inbox',
                          style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700)),
                      if (unreadCount > 0) ...[
                        SizedBox(width: 1.5.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 1.5.w, vertical: 0.3.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unreadCount',
                            style: TextStyle(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                // ── Tab 0: Broadcast ──────────────────────────────────
                ListView(
                  padding: EdgeInsets.only(bottom: 12.h),
                  children: [
                    _buildComposer(),
                    _buildHistory(historyAsync),
                  ],
                ),
                // ── Tab 1: Super Admin Inbox ──────────────────────────
                _buildInbox(inboxAsync, gymId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopbar(BuildContext context, WidgetRef ref) {
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
                'Notifications',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border:
            Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  alignment: Alignment.center,
                  child: Text('📢', style: TextStyle(fontSize: 14.sp)),
                ),
                SizedBox(width: 3.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Broadcast Message',
                      style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                    SizedBox(height: 0.2.h),
                    Text(
                      'Send push notifications instantly',
                      style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white.withOpacity(0.4)),
                    ),
                  ],
                )
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.07), height: 1),
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('TO (RECIPIENTS)'),
                Wrap(
                  spacing: 2.w,
                  runSpacing: 1.h,
                  children: [
                    _buildGroupChip('all_players', 'All Players'),
                    _buildGroupChip('active', 'Active'),
                    _buildGroupChip('expiring', 'Expiring Soon'),
                    _buildGroupChip('all_coaches', 'All Coaches'),
                  ],
                ),
                SizedBox(height: 2.h),
                _buildLabel('MESSAGE TYPE'),
                Wrap(
                  spacing: 2.w,
                  runSpacing: 1.h,
                  children: [
                    _buildTypePill('general', 'General'),
                    _buildTypePill('alert', 'Alert'),
                    _buildTypePill('payment', 'Payment'),
                    _buildTypePill('event', 'Event'),
                  ],
                ),
                SizedBox(height: 2.h),
                _buildLabel('CONTENT'),
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Notification Title',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.2)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3.w),
                        borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 4.w, vertical: 1.5.h),
                  ),
                ),
                SizedBox(height: 1.h),
                TextField(
                  controller: _bodyController,
                  style: TextStyle(fontSize: 11.sp, color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write message...',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.2)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3.w),
                        borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 4.w, vertical: 1.5.h),
                  ),
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  height: 6.h,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w)),
                    ),
                    child: _isSending
                        ? const CircularProgressIndicator(
                            color: Colors.white)
                        : Text(
                            'Send Now',
                            style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: Colors.white.withOpacity(0.3),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildGroupChip(String id, String label) {
    final isSel = _selectedGroups.contains(id);
    return GestureDetector(
      onTap: () => _toggleGroup(id),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSel
              ? const Color(0xFFFF3B30)
              : Colors.white.withOpacity(0.07),
          border: Border.all(
              color: isSel
                  ? const Color(0xFFFF3B30)
                  : Colors.white.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(5.w),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: isSel ? Colors.white : Colors.white.withOpacity(0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildTypePill(String id, String label) {
    final isSel = _selectedType == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = id),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSel
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.07),
          border: Border.all(
              color: isSel
                  ? Colors.white.withOpacity(0.2)
                  : Colors.white.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(5.w),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: isSel ? Colors.white : Colors.white.withOpacity(0.45),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(
      AsyncValue<List<Map<String, dynamic>>> historyAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: 4.5.w, vertical: 1.h),
          child: Text(
            'SENT HISTORY',
            style: TextStyle(
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 0.5,
            ),
          ),
        ),
        historyAsync.when(
          data: (history) {
            if (history.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.5.w),
                child: Text('No sent notifications yet.',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 11.sp)),
              );
            }
            return Column(
              children: history.map((doc) {
                final ts = doc['sentAt'] as Timestamp?;
                final dateStr = ts != null
                    ? DateFormat('MMM d · HH:mm').format(ts.toDate())
                    : 'Just now';
                final targets =
                    (doc['targetGroups'] as List?)?.join(', ') ?? '';
                return Container(
                  margin: EdgeInsets.only(
                      left: 4.w, right: 4.w, bottom: 0.8.h),
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.07),
                        width: 0.5),
                    borderRadius: BorderRadius.circular(3.w),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(2.w),
                        ),
                        alignment: Alignment.center,
                        child:
                            Text('📣', style: TextStyle(fontSize: 12.sp)),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc['title'] ?? '',
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            SizedBox(height: 0.3.h),
                            Text(
                              doc['body'] ?? '',
                              style: TextStyle(
                                  fontSize: 9.sp,
                                  color: Colors.white.withOpacity(0.35)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dateStr,
                              style: TextStyle(
                                  fontSize: 8.sp,
                                  color: Colors.white.withOpacity(0.2))),
                          SizedBox(height: 0.5.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2.w, vertical: 0.3.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34C759)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(1.w),
                            ),
                            child: Text(
                              targets,
                              style: TextStyle(
                                  fontSize: 7.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF34C759)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('Error: $e')),
        ),
      ],
    );
  }

  // ── Super Admin Inbox ─────────────────────────────────────────────────

  Widget _buildInbox(
      AsyncValue<List<Map<String, dynamic>>> inboxAsync, String gymId) {
    return inboxAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📬', style: TextStyle(fontSize: 48.sp)),
                SizedBox(height: 2.h),
                Text(
                  'No messages from Super Admin',
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  'System messages will appear here',
                  style: TextStyle(
                      color: Colors.white30, fontSize: 11.sp),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final msg = messages[i];
            final isUnread = msg['read'] != true;
            final ts = msg['sentAt'] as Timestamp?;
            final dateStr = ts != null
                ? DateFormat('MMM d, yyyy · HH:mm').format(ts.toDate())
                : '';
            final id = msg['id'] as String? ?? '';

            return GestureDetector(
              onTap: () {
                if (isUnread && id.isNotEmpty) {
                  ref
                      .read(adminRepositoryProvider)
                      .markSuperAdminMessageRead(gymId, id);
                }
                // Show full message
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _MessageDetailSheet(msg: msg),
                );
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 1.5.h),
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(
                  color: isUnread
                      ? const Color(0xFF5BA8FF).withOpacity(0.08)
                      : Colors.white.withOpacity(0.04),
                  border: Border.all(
                    color: isUnread
                        ? const Color(0xFF5BA8FF).withOpacity(0.25)
                        : Colors.white.withOpacity(0.07),
                    width: isUnread ? 1 : 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4.w),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 13.w,
                      height: 13.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5BA8FF).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child:
                          Text('🛡️', style: TextStyle(fontSize: 18.sp)),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'NEXUS Super Admin',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF5BA8FF),
                                ),
                              ),
                              if (isUnread) ...[
                                SizedBox(width: 2.w),
                                Container(
                                  width: 2.w,
                                  height: 2.w,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF5BA8FF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: 0.7.h),
                          Text(
                            msg['title'] ?? '',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            msg['body'] ?? '',
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white.withOpacity(0.45)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.8.h),
                          Text(
                            dateStr,
                            style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.white.withOpacity(0.25)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white30, size: 16.sp),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30))),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white54))),
    );
  }
}

// ─── Message Detail Sheet ─────────────────────────────────────────────────────

class _MessageDetailSheet extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _MessageDetailSheet({required this.msg});

  @override
  Widget build(BuildContext context) {
    final ts = msg['sentAt'] as Timestamp?;
    final dateStr = ts != null
        ? DateFormat('MMM d, yyyy · HH:mm').format(ts.toDate())
        : '';

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
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
          Row(
            children: [
              Text('🛡️', style: TextStyle(fontSize: 18.sp)),
              SizedBox(width: 2.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NEXUS Super Admin',
                      style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF5BA8FF))),
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 9.sp,
                          color: Colors.white.withOpacity(0.3))),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            msg['title'] ?? '',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 1.5.h),
          Text(
            msg['body'] ?? '',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 12.sp, height: 1.5),
          ),
        ],
      ),
    );
  }
}
