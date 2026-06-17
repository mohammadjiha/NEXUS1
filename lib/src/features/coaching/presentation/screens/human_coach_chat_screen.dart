import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/chat_repository.dart';
import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';

class HumanCoachChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String participantName;
  final bool isCoachView; // If true, the current user is the coach.

  const HumanCoachChatScreen({
    super.key,
    required this.chatId,
    required this.participantName,
    this.isCoachView = false,
  });

  @override
  ConsumerState<HumanCoachChatScreen> createState() =>
      _HumanCoachChatScreenState();
}

class _HumanCoachChatScreenState extends ConsumerState<HumanCoachChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(currentUserModelProvider).value;
      if (currentUser != null) {
        ref
            .read(chatRepositoryProvider)
            .markAsRead(widget.chatId, currentUser.uid);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text, BuildContext context) async {
    if (text.trim().isEmpty) return;

    final currentUser = ref.read(currentUserModelProvider).value;
    if (currentUser == null) return;

    final msgText = text.trim();
    _controller.clear();

    final msg = MessageModel(
      id: const Uuid().v4(),
      senderId: currentUser.uid,
      text: msgText,
      timestamp: DateTime.now(),
    );
    final messenger = ScaffoldMessenger.of(context);
    final failedMessage = 'failed_to_send_message'.tr(context);

    try {
      final receiverUid = widget.chatId
          .split('_')
          .firstWhere((id) => id != currentUser.uid, orElse: () => '');
      final senderName = currentUser.firstName?.isNotEmpty ?? false
          ? '${currentUser.firstName} ${currentUser.lastName}'.trim()
          : currentUser.email;

      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            chatId: widget.chatId,
            message: msg,
            receiverUid: receiverUid,
            senderName: senderName,
            receiverName: widget.participantName,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$failedMessage: $e')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final currentUser = ref.watch(currentUserModelProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
              ),
              error: (err, _) => Center(
                child: Text(
                  '${'error'.tr(context)}: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && messages.isNotEmpty) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'no_messages_yet_say_hi'.tr(context),
                      style: TextStyle(
                        color: const Color(0xFF8E8E93),
                        fontSize: 14.sp,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUser?.uid;

                    // Simple date logic
                    Widget? dateDivider;
                    if (index == 0) {
                      dateDivider = _buildDateDivider(msg.timestamp, context);
                    } else {
                      final prevMsg = messages[index - 1];
                      if (msg.timestamp.difference(prevMsg.timestamp).inDays >
                              0 ||
                          msg.timestamp.day != prevMsg.timestamp.day) {
                        dateDivider = _buildDateDivider(msg.timestamp, context);
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ?dateDivider,
                        isMe ? _buildMyMessage(msg) : _buildOtherMessage(msg),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInputBar(context),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Color(0xFF1C1C1E),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8FFF0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.isCoachView ? 'P' : 'C',
                  style: TextStyle(fontSize: 19.sp),
                ),
              ),
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: Container(
                  width: 3.w,
                  height: 3.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF34C759),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.participantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                Text(
                  'online_now'.tr(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF34C759),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(color: const Color(0xFFE5E5EA), height: 0.5),
      ),
    );
  }

  Widget _buildDateDivider(DateTime date, BuildContext context) {
    String text;
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      text = 'today'.tr(context);
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      text = 'yesterday'.tr(context);
    } else {
      text = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherMessage(MessageModel msg) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: const BoxDecoration(
              color: Color(0xFFE8FFF0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              widget.isCoachView ? '💪' : '👨‍💼',
              style: TextStyle(fontSize: 15.sp),
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 1.5.h,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: const Color(0xFF1C1C1E),
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Padding(
                  padding: EdgeInsetsDirectional.only(start: 2.w),
                  child: Text(
                    DateFormat('h:mm a').format(msg.timestamp),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFFC7C7CC),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 15.w),
        ],
      ),
    );
  }

  Widget _buildMyMessage(MessageModel msg) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.w,
                    vertical: 1.5.h,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Padding(
                  padding: EdgeInsetsDirectional.only(end: 2.w),
                  child: Text(
                    '${DateFormat('h:mm a').format(msg.timestamp)} ✓',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFFC7C7CC),
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

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 4.h),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText:
                      '${'message'.tr(context)} ${widget.participantName}...',
                  hintStyle: TextStyle(
                    color: const Color(0xFFC7C7CC),
                    fontSize: 16.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 1.5.h),
                ),
                style: TextStyle(
                  fontSize: 16.sp,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text, context),
            child: Container(
              width: 12.w,
              height: 12.w,
              decoration: const BoxDecoration(
                color: Color(0xFF1A7A30),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.send_rounded, color: Colors.white, size: 21.sp),
            ),
          ),
        ],
      ),
    );
  }
}
