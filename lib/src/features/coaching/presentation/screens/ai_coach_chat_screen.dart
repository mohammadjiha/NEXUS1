import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../player/presentation/screens/player_dashboard_screen.dart';
import '../../../profile/providers/body_metrics_provider.dart';
import '../../../smart_workout/providers/workout_history_provider.dart';
import '../../services/ai_coach_service.dart';

class AiCoachChatScreen extends ConsumerStatefulWidget {
  const AiCoachChatScreen({super.key});

  @override
  ConsumerState<AiCoachChatScreen> createState() => _AiCoachChatScreenState();
}

class _AiCoachChatScreenState extends ConsumerState<AiCoachChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ChatSession? _chatSession;
  bool _isInitializing = true;
  bool _isTyping = false;
  String _error = '';

  final List<Map<String, dynamic>> _messages = [
    {
      'type': 'date',
      'text': 'Today · ${DateFormat('MMM d').format(DateTime.now())}',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }
  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  Future<void> _initChat() async {
    try {
      final name =
          ref.read(currentUserFirstNameProvider) ?? 'there'.tr(context);
      final metrics = ref.read(bodyMetricsProvider).value;
      final nutrition = ref.read(nutritionTodayProvider);
      final routine = ref.read(todaysRoutineProvider);
      final recovery = ref.read(
        recoveryScoreProvider(routine?.category ?? 'General'),
      );

      String contextStr = 'User Name: $name\n';
      contextStr += 'Recovery Score: $recovery%\n';
      if (metrics != null) {
        contextStr +=
            'Weight: ${metrics.weight}kg, Height: ${metrics.height}cm, Goal: ${metrics.goal}\n';
      }
      contextStr +=
          'Calories consumed today: ${nutrition['cKcal']} / Target: ${nutrition['tKcal']}\n';
      if (routine != null) {
        contextStr +=
            'Today\'s Workout: ${routine.category} - ${routine.routineName} (${routine.exercises.length} exercises)\n';
      } else {
        contextStr += 'Today\'s Workout: Rest day / No workout scheduled.\n';
      }

      final aiService = ref.read(aiCoachServiceProvider);
      _chatSession = aiService.startChatSession(contextStr);

      setState(() {
        _isInitializing = false;
        _messages.add({
          'type': 'bot',
          'text':
              'Good morning $name! 💪\n\nYour **Recovery Score is $recovery%** today. I\'m NEXUS AI, ready to help you crush your goals.\n\nWhat can I help you with?',
          'time': DateFormat('h:mm a').format(DateTime.now()),
          'chips': ['📋 Today\'s workout', '🍗 Nutrition', '📊 Progress'],
        });
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _chatSession == null || _isTyping) return;

    final userMsg = text.trim();
    setState(() {
      _messages.add({
        'type': 'user',
        'text': userMsg,
        'time': DateFormat('h:mm a').format(DateTime.now()),
      });
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _chatSession!.sendMessage(Content.text(userMsg));
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'type': 'bot',
            'text': response.text ?? 'sorry_could_not_process'.tr(context),
            'time': DateFormat('h:mm a').format(DateTime.now()),
          });
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Gemini Chat Error: $e');
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'type': 'bot',
            'text': 'server_busy_try_again'.tr(context),
            'time': DateFormat('h:mm a').format(DateTime.now()),
          });
        });
        _scrollToBottom();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: _buildAppBar(),
      body: _isInitializing
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
            )
          : _error.isNotEmpty
          ? Center(
              child: Text(
                _error,
                style: TextStyle(color: Colors.red, fontSize: 13.sp),
                textAlign: TextAlign.center,
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 2.h,
                    ),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[index];
                      if (msg['type'] == 'date') {
                        return _buildDateDivider(msg['text']);
                      }
                      if (msg['type'] == 'bot') return _buildBotMessage(msg);
                      if (msg['type'] == 'user') return _buildUserMessage(msg);
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                _buildQuickActionsBar(),
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
                  color: Color(0xFF1C1C1E),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.show_chart_rounded,
                  color: Colors.white,
                  size: 19.sp,
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
                  'nexus_ai_coach'.tr(context),
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 0.2.h),
                Text(
                  '● Online — always here for you',
                  style: TextStyle(
                    fontSize: 14.5.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF34C759),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF3A3A3C)),
          onPressed: () {},
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(color: const Color(0xFFE5E5EA), height: 0.5),
      ),
    );
  }

  Widget _buildDateDivider(String text) {
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

  Widget _buildBotMessage(Map<String, dynamic> msg) {
    final chips = msg['chips'] as List<String>?;

    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 15.sp),
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                    ),
                    border: Border.all(
                      color: const Color(0xFFE5E5EA),
                      width: 0.5,
                    ),
                  ),
                  child: _parseBoldText(msg['text']),
                ),
                SizedBox(height: 0.5.h),
                Padding(
                  padding: EdgeInsetsDirectional.only(start: 2.w),
                  child: Text(
                    msg['time'],
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFFC7C7CC),
                    ),
                  ),
                ),
                if (chips != null && chips.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 1.h),
                    child: Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: chips
                          .map(
                            (c) => _buildChip(c, isPrimary: c.startsWith('+')),
                          )
                          .toList(),
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

  Widget _parseBoldText(String text) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.sp,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: parts[i],
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 15.sp,
              color: const Color(0xFF1C1C1E),
              height: 1.5,
            ),
          ),
        );
      }
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildUserMessage(Map<String, dynamic> msg) {
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
                    msg['text'],
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
                    msg['time'],
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 2.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 15.sp),
          ),
          SizedBox(width: 2.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(),
                SizedBox(width: 1.w),
                _buildDot(),
                SizedBox(width: 1.w),
                _buildDot(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 1.5.w,
      height: 1.5.w,
      decoration: const BoxDecoration(
        color: Color(0xFFC7C7CC),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildChip(String label, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: () => _sendMessage(label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFF1C1C1E)
                : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    final actions = [
      {'icon': '✏️', 'label': 'Customize workout'},
      {'icon': '📊', 'label': 'Progress'},
      {'icon': '🩹', 'label': 'Injury concern'},
      {'icon': '🍽️', 'label': 'Meal plan'},
      {'icon': '🎥', 'label': 'Form check'},
    ];

    return Container(
      padding: EdgeInsets.only(top: 1.5.h, bottom: 0.5.h),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Row(
          children: actions
              .map(
                (a) => Padding(
                  padding: EdgeInsetsDirectional.only(end: 2.w),
                  child: GestureDetector(
                    onTap: () => _sendMessage(a['label']!),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 3.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE5E5EA),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(a['icon']!, style: TextStyle(fontSize: 15.sp)),
                          SizedBox(width: 1.5.w),
                          Text(
                            a['label']!,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3A3A3C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 4.h),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'ask_your_ai_coach'.tr(context),
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
                  SizedBox(width: 2.w),
                  GestureDetector(
                    onTap: () {}, // show bottom sheet context attach
                    child: Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5E5EA),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add,
                        color: const Color(0xFF8E8E93),
                        size: 17.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 2.w),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              width: 12.w,
              height: 12.w,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
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
