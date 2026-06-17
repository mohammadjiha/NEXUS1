import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../models/routine_model.dart';
import '../../providers/routines_provider.dart';
import '../../providers/split_setup_provider.dart';

class SplitSetupWizardScreen extends ConsumerStatefulWidget {
  const SplitSetupWizardScreen({super.key});

  @override
  ConsumerState<SplitSetupWizardScreen> createState() =>
      _SplitSetupWizardScreenState();
}

class _SplitSetupWizardScreenState
    extends ConsumerState<SplitSetupWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool get _isAr => Localizations.localeOf(context).languageCode == 'ar';

  TextDirection get _textDirection =>
      _isAr ? TextDirection.rtl : TextDirection.ltr;

  String _stepTag(int step) =>
      _isAr ? 'الإعداد · الخطوة $step من 4' : 'SETUP · STEP $step OF 4';

  String _dayName(String value) {
    const ar = {
      'MON': 'الاثنين',
      'TUE': 'الثلاثاء',
      'WED': 'الأربعاء',
      'THU': 'الخميس',
      'FRI': 'الجمعة',
      'SAT': 'السبت',
      'SUN': 'الأحد',
    };
    const en = {
      'MON': 'MON',
      'TUE': 'TUE',
      'WED': 'WED',
      'THU': 'THU',
      'FRI': 'FRI',
      'SAT': 'SAT',
      'SUN': 'SUN',
    };
    return (_isAr ? ar : en)[value.toUpperCase()] ?? value;
  }

  String _dayShort(String value) {
    const ar = {
      'MON': 'اث',
      'TUE': 'ثل',
      'WED': 'أر',
      'THU': 'خم',
      'FRI': 'جم',
      'SAT': 'سب',
      'SUN': 'أح',
    };
    return _isAr ? (ar[value.toUpperCase()] ?? value) : value.substring(0, 3);
  }

  String _categoryLabel(String value) {
    if (!_isAr) return value;
    const map = {
      'Chest': 'صدر',
      'Back': 'ظهر',
      'Legs': 'أرجل',
      'Shoulders': 'أكتاف',
      'Biceps': 'بايسبس',
      'Triceps': 'ترايسبس',
      'Core': 'بطن',
      'Arms': 'ذراعين',
      'Recovery': 'استشفاء',
    };
    var result = value;
    for (final entry in map.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  String _workoutTitle(String value) {
    if (!_isAr) return value;
    const exact = {
      'Upper Body': 'الجزء العلوي',
      'Lower Body': 'الجزء السفلي',
      'Leg Day': 'يوم الأرجل',
      'Push Day': 'يوم الدفع',
      'Pull Day': 'يوم السحب',
      'Full Body': 'تمرين كامل الجسم',
      'Rest Day': 'راحة',
    };
    return exact[value] ?? _categoryLabel(value);
  }

  String _splitTitle(String id, String fallback) {
    if (!_isAr) return fallback;
    const map = {
      'ai_decide': 'دع الذكاء يختار',
      'fb': 'كامل الجسم',
      'ul': 'علوي / سفلي',
      'ppl': 'دفع / سحب / أرجل',
      'bro_split': 'تقسيم عضلة لكل يوم',
      'ppl_ul': 'دفع/سحب/أرجل + علوي/سفلي',
      'advanced': 'تقسيم متقدم',
      'custom': 'ابنِ خطتي بنفسي',
    };
    return map[id] ?? fallback;
  }

  String _splitDesc(String id, String fallback) {
    if (!_isAr) return fallback;
    const map = {
      'ai_decide':
          'غير متأكد من التقسيم المناسب؟ دع الذكاء الاصطناعي يبني لك الخطة الأفضل.',
      'fb': 'درّب كل العضلات في كل حصة. مناسب للمبتدئين والجداول المزدحمة.',
      'ul':
          'يومان للجزء العلوي ويومان للجزء السفلي. تكرار ممتاز لبناء العضلات.',
      'ppl':
          'دفع للصدر والأكتاف، سحب للظهر والبايسبس، وأرجل للفخذين والمؤخرة.',
      'bro_split':
          'كل يوم يركز على عضلة رئيسية واحدة مثل الصدر أو الظهر أو الأرجل.',
      'ppl_ul':
          'تقسيم عالي التكرار يجمع بين دفع/سحب/أرجل ويومين علوي/سفلي.',
      'advanced':
          'بدون أيام راحة. مناسب للمتقدمين جدًا ومع متابعة استشفاء دقيقة.',
      'custom': 'اختر بنفسك العضلات التي تتمرنها في كل يوم.',
    };
    return map[id] ?? fallback;
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      ref.read(splitSetupStatusProvider.notifier).completeSetup();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // FIX: Skip now shows a confirmation dialog instead of skipping immediately
  void _handleSkip(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        title: Text(
          'skip_setup_question'.tr(context),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        content: Text(
          'skip_setup_desc'.tr(context),
          style: TextStyle(
            fontSize: 14.sp,
            color: const Color(0xFF6E6E73),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'go_back'.tr(context),
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF8E8E93),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(splitSetupStatusProvider.notifier).completeSetup();
            },
            child: Text(
              'skip'.tr(context),
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFFFF3B30),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildStep1(context),
                  _buildStep2(),
                  _buildStep3(context),
                  _buildStep4(context),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomCTA(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _currentPage > 0 ? _prevPage : null,
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              // FIX: withOpacity → withValues
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 12.sp,
                color: _currentPage > 0
                    ? const Color(0xFF1C1C1E)
                    : const Color(0xFF1C1C1E).withValues(alpha: 0.3),
              ),
            ),
          ),
          Row(
            children: List.generate(4, (index) {
              return Container(
                width: 1.5.w,
                height: 1.5.w,
                margin: EdgeInsets.symmetric(horizontal: 0.8.w),
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? const Color(0xFF1C1C1E)
                      : (index < _currentPage
                            ? const Color(0xFF34C759)
                            : const Color(0xFFE5E5EA)),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
          // FIX: Skip now shows confirmation dialog
          GestureDetector(
            onTap: () => _handleSkip(context),
            child: Text(
              'Skip →',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8E8E93),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    double progress = (_currentPage + 1) * 0.25;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.5.h),
      height: 0.4.h,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(1.w),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 300),
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(1.w),
          ),
        ),
      ),
    );
  }

  Widget _buildStepHeader(String tag, String title, String sub) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.8.w, 0.5.h, 4.8.w, 2.h),
      child: Directionality(
        textDirection: _textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tag,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF007AFF),
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 0.6.h),
            Text(
              title,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            SizedBox(height: 0.8.h),
            Text(
              sub,
              textAlign: TextAlign.start,
              style: TextStyle(
                fontSize: 15.sp,
                color: const Color(0xFF6E6E73),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 1 ─────────────────────────────────────────────────────────────────

  Widget _buildStep1(BuildContext context) {
    final setupData =
        ref.watch(splitSetupDataProvider).value ?? SplitSetupData();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'SETUP · STEP 1 OF 4',
            _isAr
                ? 'كم يوم تتمرن في الأسبوع؟'
                : 'How many days do you train per week?',
            _isAr
                ? 'هذا يساعدنا نبني لك التقسيم الأنسب.'
                : 'This helps us build your perfect split.',
          ),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 4.8.w),
            mainAxisSpacing: 2.w,
            crossAxisSpacing: 2.w,
            childAspectRatio: 0.8,
            children: [2, 3, 4, 5, 6, 7].map((days) {
              final isSel = setupData.daysPerWeek == days;
              return GestureDetector(
                onTap: () => ref
                    .read(splitSetupDataProvider.notifier)
                    .setDaysPerWeek(days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(3.5.w),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$days',
                        style: TextStyle(
                          fontSize: 32.sp,
                          fontWeight: FontWeight.w800,
                          // FIX: withOpacity → withValues
                          color: isSel ? Colors.white : const Color(0xFF3A3A3C),
                        ),
                      ),
                      Text(
                        'days'.tr(context).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          // FIX: withOpacity → withValues
                          color: isSel
                              ? Colors.white.withValues(alpha: 0.5)
                              : const Color(0xFF8E8E93),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 3.h),
          _buildAIInsight(
            'For fat loss + muscle gain, ',
            '4 days',
            ' is optimal. Enough volume with proper recovery time.',
          ),
        ],
      ),
    );
  }

  // ─── STEP 2 ─────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _getSplitsForDays(int days) {
    List<Map<String, dynamic>> options = [];
    options.add({
      'id': 'ai_decide',
      'icon': Icons.auto_awesome,
      'title': 'Let AI Decide',
      'desc':
          'Not sure what split to use? Let the AI build the perfect routine for you.',
      'bg': const Color(0xFFE8F5FF),
      'ai': true,
    });

    if (days == 2) {
      options.addAll([
        {
          'id': 'fb',
          'icon': Icons.loop_rounded,
          'title': 'Full Body 2x',
          'desc':
              'Hit every muscle group each session. Great for beginners and busy schedules.',
          'bg': const Color(0xFFFFF8E8),
          'ai': false,
        },
        {
          'id': 'ul',
          'icon': Icons.swap_vert_rounded,
          'title': 'Upper / Lower',
          'desc':
              'Day 1: chest, back, shoulders, arms. Day 2: quads, hamstrings, glutes, calves.',
          'bg': const Color(0xFFE8FFF0),
          'ai': false,
        },
      ]);
    } else if (days == 3) {
      options.addAll([
        {
          'id': 'ppl',
          'icon': Icons.fitness_center_rounded,
          'title': 'Push / Pull / Legs',
          'desc':
              'Push = chest & shoulders. Pull = back & biceps. Legs = quads, hamstrings, glutes. Best split for 3 days.',
          'bg': const Color(0xFFE8F5FF),
          'ai': false,
        },
        {
          'id': 'fb',
          'icon': Icons.loop_rounded,
          'title': 'Full Body 3x',
          'desc':
              'Train every muscle 3× per week at lower volume per session. Ideal for beginners.',
          'bg': const Color(0xFFFFF8E8),
          'ai': false,
        },
      ]);
    } else if (days == 4) {
      options.addAll([
        {
          'id': 'ul',
          'icon': Icons.swap_vert_rounded,
          'title': 'Upper / Lower 2x',
          'desc':
              'Upper body twice and lower body twice per week. Optimal frequency for muscle growth.',
          'bg': const Color(0xFFE8FFF0),
          'ai': false,
        },
        {
          'id': 'bro_split',
          'icon': Icons.sports_gymnastics,
          'title': 'Bro Split',
          'desc':
              'One muscle group per day — e.g. Monday chest, Tuesday back, Wednesday shoulders, Thursday legs.',
          'bg': const Color(0xFFF9E8FF),
          'ai': false,
        },
      ]);
    } else if (days == 5) {
      options.addAll([
        {
          'id': 'bro_split',
          'icon': Icons.sports_gymnastics,
          'title': 'Bro Split',
          'desc':
              'Classic bodybuilding split. Each session targets one muscle group with high volume.',
          'bg': const Color(0xFFF9E8FF),
          'ai': false,
        },
        {
          'id': 'ppl_ul',
          'icon': Icons.fitness_center_rounded,
          'title': 'PPL + Upper/Lower',
          'desc':
              'Push/Pull/Legs plus two upper-lower days. High frequency for advanced lifters.',
          'bg': const Color(0xFFE8F5FF),
          'ai': false,
        },
      ]);
    } else if (days == 6) {
      options.addAll([
        {
          'id': 'ppl',
          'icon': Icons.fitness_center_rounded,
          'title': 'PPL 2x',
          'desc':
              'Full Push/Pull/Legs cycle twice per week. Maximum volume for experienced lifters only.',
          'bg': const Color(0xFFE8F5FF),
          'ai': false,
        },
      ]);
    } else {
      options.addAll([
        {
          'id': 'advanced',
          'icon': Icons.emoji_events_rounded,
          'title': 'Advanced Split',
          'desc':
              'No rest days. Designed for competitive athletes with a coach-guided recovery plan.',
          'bg': const Color(0xFFFFEEEE),
          'ai': false,
        },
      ]);
    }
    return options;
  }

  Widget _buildStep2() {
    final setupData =
        ref.watch(splitSetupDataProvider).value ?? SplitSetupData();
    final splits = _getSplitsForDays(setupData.daysPerWeek);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'SETUP · STEP 2 OF 4',
            _isAr ? 'اختر تقسيمك' : 'Choose your split',
            _isAr
                ? 'اختر قالبًا جاهزًا أو ابنِ خطتك بنفسك. يمكنك تغييره لاحقًا.'
                : 'Pick a template or build your own. You can change this anytime.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.8.w),
            child: Column(
              children: [
                ...splits.map(
                  (s) => _buildSplitCard(
                    s['id'] as String,
                    s['icon'] as IconData,
                    s['title'] as String,
                    s['desc'] as String,
                    s['bg'] as Color,
                    s['ai'] as bool,
                  ),
                ),
                _buildSplitCard(
                  'custom',
                  Icons.tune_rounded,
                  'Build My Own',
                  'Choose exactly which muscles you train each day. Full custom control.',
                  const Color(0xFFF0EEFF),
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitCard(
    String id,
    IconData icon,
    String title,
    String desc,
    Color iconBg,
    bool aiPick,
  ) {
    final setupData =
        ref.watch(splitSetupDataProvider).value ?? SplitSetupData();
    final isSel = setupData.splitType == id;

    return GestureDetector(
      onTap: () => ref.read(splitSetupDataProvider.notifier).setSplitType(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(bottom: 1.5.h),
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(
            color: isSel ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FIX: Icon widget instead of emoji Text
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Icon(icon, size: 18.sp, color: const Color(0xFF3A3A3C)),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1E),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (aiPick)
                        Container(
                          margin: EdgeInsetsDirectional.only(start: 2.w),
                          padding: EdgeInsets.symmetric(
                            horizontal: 2.w,
                            vertical: 0.3.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5FF),
                            borderRadius: BorderRadius.circular(2.w),
                          ),
                          child: Text(
                            'ai_pick'.tr(context),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF007AFF),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF6E6E73),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 5.w,
              height: 5.w,
              margin: EdgeInsets.only(top: 0.5.h),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF1C1C1E) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSel
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFD1D1D6),
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 3 ─────────────────────────────────────────────────────────────────

  Color _getCategoryBgColor(String category) {
    if (category.contains('Chest')) return const Color(0xFFE8F5FF);
    if (category.contains('Back')) return const Color(0xFFEBF5FF);
    if (category.contains('Legs')) return const Color(0xFFFFF8E8);
    if (category.contains('Shoulders')) return const Color(0xFFE8FFF0);
    if (category.contains('Biceps')) return const Color(0xFFFFF0E8);
    if (category.contains('Triceps')) return const Color(0xFFFFF8E8);
    return const Color(0xFFF5F5F7);
  }

  Color _getCategoryTextColor(String category) {
    if (category.contains('Chest')) return const Color(0xFF0A64B0);
    if (category.contains('Back')) return const Color(0xFF0A64B0);
    if (category.contains('Legs')) return const Color(0xFF7A4D0A);
    if (category.contains('Shoulders')) return const Color(0xFF1A7A30);
    if (category.contains('Biceps')) return const Color(0xFFC05A0A);
    if (category.contains('Triceps')) return const Color(0xFF7A4D0A);
    return const Color(0xFF3A3A3C);
  }

  Widget _buildStep3(BuildContext context) {
    final setupData =
        ref.watch(splitSetupDataProvider).value ?? SplitSetupData();
    final generatedPlan = ref.watch(generatedPlanProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'SETUP · STEP 3 OF 4',
            _isAr ? 'ما هي أيام تمرينك؟' : 'Which days do you train?',
            // FIX: clarified hint — days of the week, not specific dates
            _isAr
                ? 'اختر أيام التمرين الأسبوعية. ستتكرر الخطة كل أسبوع.'
                : 'Select your weekly training days. Your plan repeats every week.',
          ),
          _buildWeekStrip(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.5.h),
            child: Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9FB),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7.w,
                    height: 7.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 14.sp,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        // FIX: removed hardcoded fontFamily: 'Inter'
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF3A3A3C),
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${setupData.trainingDays.length} training days selected. ',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(
                            text:
                                'AI has generated the ideal split based on your choices.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.8.w, vertical: 1.h),
            child: Text(
              'assigned_muscles'.tr(context),
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF8E8E93),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...generatedPlan.where((d) => !d.isRest).map((day) {
            return _buildAssignedDayRow(
              day.dayName,
              day.title,
              day.categories
                  .map(
                    (c) => {
                      'name': c,
                      'bg': _getCategoryBgColor(c),
                      'c': _getCategoryTextColor(c),
                    },
                  )
                  .toList(),
              day.assignedRoutineName,
              day.assignedRoutineId,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final setupData =
        ref.watch(splitSetupDataProvider).value ?? SplitSetupData();

    // Calculate Monday of the current week
    final now = DateTime.now();
    final offsetFromSaturday = (now.weekday + 1) % 7;
    final startOfWeek = now.subtract(Duration(days: offsetFromSaturday));

    final daysInfo = List.generate(7, (i) {
      final date = startOfWeek.add(Duration(days: i));
      final dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      final idx = date.weekday - 1;
      return {
        'id': dayNames[idx],
        'initial': dayNames[idx].substring(0, 2),
        'date': date.day.toString(),
      };
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 4.8.w),
      child: Row(
        children: daysInfo.map((info) {
          final dayId = info['id']!;
          final isOn = setupData.trainingDays.contains(dayId);
          return GestureDetector(
            onTap: () => ref
                .read(splitSetupDataProvider.notifier)
                .toggleTrainingDay(dayId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsetsDirectional.only(end: 1.5.w),
              width: 12.w,
              padding: EdgeInsets.symmetric(vertical: 1.4.h),
              decoration: BoxDecoration(
                color: isOn ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(3.5.w),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    info['initial']!,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: isOn
                          ? Colors.white.withValues(alpha: 0.55)
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                  SizedBox(height: 0.2.h),
                  Text(
                    info['date']!,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isOn ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.6.h),
                  Container(
                    width: 1.8.w,
                    height: 1.8.w,
                    decoration: BoxDecoration(
                      color: isOn
                          ? const Color(0xFF34C759)
                          : const Color(0xFFD1D1D6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAssignedDayRow(
    String dayLabel,
    String title,
    List<Map<String, dynamic>> tags,
    String? routineName,
    String? routineId,
  ) {
    return GestureDetector(
      onTap: () {
        if (routineId != null) _showRoutineDetails(routineId, context);
      },
      child: Container(
        margin: EdgeInsetsDirectional.only(bottom: 1.h, start: 4.8.w, end: 4.8.w),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FB),
          borderRadius: BorderRadius.circular(3.5.w),
        ),
        child: Row(
          children: [
            Container(
              width: 10.w,
              height: 10.w,
              decoration: BoxDecoration(
                color: _getCategoryBgColor(
                  tags.isNotEmpty ? (tags.first['name'] as String) : '',
                ),
                borderRadius: BorderRadius.circular(2.5.w),
              ),
              alignment: Alignment.center,
              child: Text(
                dayLabel.substring(0, 3),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                  color: _getCategoryTextColor(
                    tags.isNotEmpty ? (tags.first['name'] as String) : '',
                  ),
                ),
              ),
            ),
            SizedBox(width: 3.5.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  if (routineName != null) ...[
                    SizedBox(height: 0.3.h),
                    Text(
                      _isAr ? 'المعين: $routineName' : 'Assigned: $routineName',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF007AFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  SizedBox(height: 0.8.h),
                  Wrap(
                    spacing: 1.5.w,
                    runSpacing: 1.5.w,
                    children: tags
                        .map(
                          (t) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 2.5.w,
                              vertical: 0.4.h,
                            ),
                            decoration: BoxDecoration(
                              color: t['bg'] as Color,
                              borderRadius: BorderRadius.circular(2.w),
                            ),
                            child: Text(
                              t['name'] as String,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: t['c'] as Color,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFFC7C7CC),
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 4 ─────────────────────────────────────────────────────────────────

  Widget _buildStep4(BuildContext context) {
    final generatedPlan = ref.watch(generatedPlanProvider);
    // FIX: calculate total time from actual routines instead of hardcoded "~45 min"
    final routines = ref.watch(msRoutinesProvider).value ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            'SETUP · STEP 4 OF 4',
            _isAr ? 'خطتك جاهزة!' : 'Your plan is ready!',
            _isAr
                ? 'المدرب الذكي بنى جدولك. هذا شكل أسبوعك التدريبي.'
                : 'AI Coach has built your schedule. Here\'s what every week looks like.',
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4.8.w),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(4.5.w),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FIX: withOpacity → withValues
                Text(
                  'your_weekly_split'.tr(context),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 0.7,
                  ),
                ),
                SizedBox(height: 1.5.h),
                ...generatedPlan.map((workoutDay) {
                  if (!workoutDay.isRest) {
                    // FIX: calculate estimated time from actual routine sets
                    String estTime = '~45 min';
                    if (workoutDay.assignedRoutineId != null) {
                      try {
                        final routine = routines.firstWhere(
                          (r) => r.id == workoutDay.assignedRoutineId,
                        );
                        final totalSets = routine.exercises.fold<int>(
                          0,
                          (sum, ex) => sum + ex.sets,
                        );
                        final minutes = totalSets * 3;
                        estTime = '~$minutes min';
                      } catch (_) {}
                    }
                    return _buildWeekBreakdownRow(
                      workoutDay.dayName,
                      workoutDay.title,
                      workoutDay.categories.join(' · '),
                      estTime,
                      true,
                      _getCategoryBgColor(
                        workoutDay.categories.firstOrNull ?? '',
                      ),
                      _getCategoryTextColor(
                        workoutDay.categories.firstOrNull ?? '',
                      ),
                    );
                  } else {
                    return _buildWeekBreakdownRow(
                      workoutDay.dayName,
                      _isAr ? 'راحة' : 'Rest Day',
                      _isAr ? 'استشفاء' : 'Recovery',
                      '',
                      false,
                      // FIX: withOpacity → withValues
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.3),
                    );
                  }
                }),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          _buildAIInsight(
            'Your split is optimized for ',
            'fat loss',
            '. I\'ll auto-adjust weights weekly based on your performance and recovery score. You can edit any day anytime.',
          ),
        ],
      ),
    );
  }

  Widget _buildWeekBreakdownRow(
    String day,
    String title,
    String sub,
    String time,
    bool isWork,
    Color bg,
    Color textCol,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Row(
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(2.w),
            ),
            alignment: Alignment.center,
            child: Text(
              day.substring(0, 3),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: textCol,
              ),
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
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    // FIX: withOpacity → withValues
                    color: isWork
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 13.sp,
                      // FIX: withOpacity → withValues
                      color: isWork
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          if (time.isNotEmpty)
            Text(
              time,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                // FIX: withOpacity → withValues
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }

  // ─── AI Insight card ────────────────────────────────────────────────────────

  Widget _buildAIInsight(String p1, String p2, String p3) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.8.w),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: const Color(0xFFB5D4F4), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 14.sp),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: RichText(
              text: TextSpan(
                // FIX: removed hardcoded fontFamily: 'Inter'
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF0C447C),
                  height: 1.55,
                ),
                children: [
                  const TextSpan(
                    text: 'AI Coach: ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: p1),
                  TextSpan(
                    text: p2,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: p3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom CTA ─────────────────────────────────────────────────────────────

  Widget _buildBottomCTA() {
    String btnText = _isAr ? 'متابعة' : 'Continue';
    if (_currentPage == 0) btnText = 'Continue → Choose Split';
    if (_currentPage == 1) btnText = 'Continue → Pick Days';
    if (_currentPage == 2) btnText = 'Continue → AI Confirmation';
    if (_currentPage == 3) btnText = "Let's Go — Open Dashboard";

    final setupData =
        ref.watch(splitSetupDataProvider).value ?? SplitSetupData();
    bool canContinue = true;

    if (_currentPage == 1) {
      final validSplits = _getSplitsForDays(
        setupData.daysPerWeek,
      ).map((s) => s['id'] as String).toList();
      validSplits.add('custom');
      if (!validSplits.contains(setupData.splitType)) {
        canContinue = false;
      }
    } else if (_currentPage == 2) {
      if (setupData.trainingDays.length != setupData.daysPerWeek) {
        canContinue = false;
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(4.8.w, 2.h, 4.8.w, 13.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.white, Colors.white.withValues(alpha: 0.0)],
          stops: const [0.7, 1.0],
        ),
      ),
      child: ElevatedButton(
        onPressed: canContinue ? _nextPage : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: !canContinue
              ? const Color(0xFFE5E5EA)
              : (_currentPage == 3
                    ? const Color(0xFF34C759)
                    : const Color(0xFF1C1C1E)),
          padding: EdgeInsets.symmetric(vertical: 2.8.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4.w),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentPage == 3)
              Padding(
                padding: EdgeInsetsDirectional.only(end: 2.w),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 16.sp,
                ),
              ),
            Text(
              btnText,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: !canContinue ? const Color(0xFF8E8E93) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Routine details sheet ──────────────────────────────────────────────────

  void _showRoutineDetails(String routineId, BuildContext context) {
    final routines = ref.read(msRoutinesProvider).value ?? [];
    // FIX: show SnackBar instead of silently swallowing the error
    final matches = routines.where((r) => r.id == routineId).toList();
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('routine_details_not_available'.tr(context))),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _buildRoutineDetailsSheet(matches.first),
    );
  }

  Widget _buildRoutineDetailsSheet(RoutineModel routine) {
    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FIX: withOpacity → withValues
                      Text(
                        routine.category,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.5),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 0.5.h),
                      Text(
                        routine.routineName,
                        style: TextStyle(
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(2.w),
                    // FIX: withOpacity → withValues
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(5.w),
              itemCount: routine.exercises.length,
              itemBuilder: (ctx, idx) {
                final ex = routine.exercises[idx];
                return Padding(
                  padding: EdgeInsets.only(bottom: 2.h),
                  child: Row(
                    children: [
                      Container(
                        width: 11.w,
                        height: 11.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                      SizedBox(width: 3.5.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1C1C1E),
                              ),
                            ),
                            SizedBox(height: 0.3.h),
                            Text(
                              '${ex.sets} Sets × ${ex.reps}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
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
  }
}
