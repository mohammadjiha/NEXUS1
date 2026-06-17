import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/intl_formatter.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../coaching/models/chat_room_model.dart';
import '../../../coaching/presentation/screens/human_coach_chat_screen.dart';
import '../../../coaching/providers/chat_provider.dart';
import '../../data/coach_repository.dart';

class CoachMessagesView extends ConsumerWidget {
  const CoachMessagesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachUid = ref.watch(currentUserModelProvider).value?.uid;

    if (coachUid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeChatsAsync = ref.watch(activeChatsProvider(coachUid));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(context),
            Expanded(
              child: activeChatsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
                ),
                error: (error, _) => Center(
                  child: Text(
                    '${'error_prefix'.tr(context)} $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                data: (chats) {
                  if (chats.isEmpty) {
                    return Center(
                      child: Text(
                        'no_active_conversations'.tr(context),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF8E8E93),
                          fontSize: 14.sp,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.only(bottom: 12.h, top: 1.h),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      return _buildActiveChatTile(context, ref, chat, coachUid);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF007AFF),
          onPressed: () => _showNewChatModal(context, ref, coachUid),
          child: const Icon(Icons.add_comment_rounded, color: Colors.white),
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
          Text(
            'coach_messages'.tr(context),
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChatTile(
    BuildContext context,
    WidgetRef ref,
    ChatRoomModel chat,
    String coachUid,
  ) {
    // Find the other participant's UID and name
    final playerUid = chat.participants.firstWhere(
      (uid) => uid != coachUid,
      orElse: () => '',
    );
    final name = chat.participantNames[playerUid] ?? 'Player';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final unreadCount = chat.unreadCounts[coachUid] ?? 0;

    String timeStr = '';
    if (chat.lastMessageTime != null) {
      final now = DateTime.now();
      if (now.difference(chat.lastMessageTime!).inDays == 0) {
        timeStr = AppIntl.time(context, chat.lastMessageTime!);
      } else {
        timeStr = AppIntl.shortDate(context, chat.lastMessageTime!);
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HumanCoachChatScreen(
              chatId: chat.id,
              participantName: name,
              isCoachView: true,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 14.w,
              height: 14.w,
              decoration: const BoxDecoration(
                color: Color(0xFFE6F2FF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.all(1.w),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF007AFF),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: unreadCount > 0
                                ? const Color(0xFF007AFF)
                                : const Color(0xFF8E8E93),
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage ?? 'Started a chat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: unreadCount > 0
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFF8E8E93),
                            fontWeight: unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          margin: EdgeInsetsDirectional.only(start: 2.w),
                          padding: EdgeInsets.all(1.5.w),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewChatModal(BuildContext context, WidgetRef ref, String coachUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewChatSheet(coachUid: coachUid),
    );
  }
}

class _NewChatSheet extends ConsumerWidget {
  final String coachUid;
  const _NewChatSheet({required this.coachUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(coachMembersProvider);

    return Container(
      height: 80.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        children: [
          SizedBox(height: 1.5.h),
          Container(
            width: 12.w,
            height: 0.6.h,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(1.w),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(5.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'coach_start_new_chat'.tr(context),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(1.5.w),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F2F7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          Expanded(
            child: playersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) =>
                  Center(child: Text('${'error_prefix'.tr(context)}$err')),
              data: (players) {
                if (players.isEmpty) {
                  return Center(
                    child: Text('no_players_assigned_yet'.tr(context)),
                  );
                }
                return ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final name = (player.firstName?.isNotEmpty ?? false)
                        ? '${player.firstName} ${player.lastName ?? ""}'.trim()
                        : player.email;
                    final initials = name.isNotEmpty
                        ? name[0].toUpperCase()
                        : 'P';

                    return InkWell(
                      onTap: () {
                        Navigator.pop(context); // Close sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HumanCoachChatScreen(
                              chatId: '${player.uid.trim()}_${coachUid!.trim()}',
                              participantName: name,
                              isCoachView: true,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 5.w,
                          vertical: 1.5.h,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFF2F2F7)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12.w,
                              height: 12.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0EEFF),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: EdgeInsets.all(1.w),
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7B5CF0),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: const Color(0xFF007AFF),
                              size: 18.sp,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
