import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../gamification/services/trophy_service.dart';
import '../../models/routine_model.dart';
import '../../providers/active_session_timer_provider.dart';
import '../../providers/exercise_history_provider.dart';
import '../../providers/workout_history_provider.dart';
import '../widgets/exercise_video_sheet.dart';
import '../widgets/plate_calculator_sheet.dart';

class ActiveSessionScreen extends ConsumerStatefulWidget {
  final RoutineModel routine;
  final bool isViewOnly;
  final String? scheduledDay;
  const ActiveSessionScreen({
    super.key,
    required this.routine,
    this.isViewOnly = false,
    this.scheduledDay,
  });

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with WidgetsBindingObserver {
  int _currentExerciseIndex = 0;
  bool _isPaused = false;
  bool _sessionFinished = false;
  // Map exercise index to a list of sets. Each set is a Map of data.
  late Map<int, List<Map<String, dynamic>>> _exerciseSets;

  bool _isResting = false;
  int _restSeconds = 90;
  Timer? _restTimer;
  // Per-exercise rest duration in seconds. Defaults to 90 s.
  late Map<int, int> _restDurations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.isViewOnly) {
      Future.microtask(
        () => ref.read(activeSessionTimerProvider.notifier).start(),
      );
    }

    // Load previous weights once the history provider resolves — safe in initState
    Future.microtask(() {
      ref.listenManual(exerciseHistoryProvider, (_, historyAsync) {
        historyAsync.whenData((history) {
          for (int i = 0; i < widget.routine.exercises.length; i++) {
            final ex = widget.routine.exercises[i];
            final prevWeight = history[ex.name]?.weight ?? 0.0;
            final prevStr = prevWeight == 0.0
                ? '-'
                : prevWeight.toString().replaceAll(RegExp(r'\.0$'), '');
            for (var set in _exerciseSets[i]!) {
              if (set['prevLoaded'] != true) {
                set['prevLoaded'] = true;
                set['prev'] = prevStr;
                if ((set['kgCtrl'] as TextEditingController).text == '0') {
                  (set['kgCtrl'] as TextEditingController).text =
                      prevStr == '-' ? '0' : prevStr;
                }
              }
            }
          }
          if (mounted) setState(() {});
        });
      }, fireImmediately: true);
    });

    // Initialize per-exercise rest durations to 90 s
    _restDurations = {
      for (int i = 0; i < widget.routine.exercises.length; i++) i: 90,
    };

    // Initialize sets
    _exerciseSets = {};
    for (int i = 0; i < widget.routine.exercises.length; i++) {
      final ex = widget.routine.exercises[i];
      _exerciseSets[i] = List.generate(
        ex.sets,
        (index) => {
          'repsCtrl': TextEditingController(
            text: ex.reps.contains('-') ? ex.reps.split('-')[1] : ex.reps,
          ),
          'kgCtrl': TextEditingController(text: '0'),
          'rpeCtrl': TextEditingController(text: '8'),
          'done': false,
          'prevLoaded': false,
          'prev': '-',
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(activeSessionTimerProvider.notifier).stop();
    _restTimer?.cancel();
    _exerciseSets.forEach((_, sets) {
      for (var s in sets) {
        (s['repsCtrl'] as TextEditingController).dispose();
        (s['kgCtrl'] as TextEditingController).dispose();
        (s['rpeCtrl'] as TextEditingController).dispose();
      }
    });
    super.dispose();
  }

  void _nextExercise() {
    if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
      setState(() => _currentExerciseIndex++);
    }
  }

  void _prevExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() => _currentExerciseIndex--);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(activeSessionTimerProvider.notifier).pause();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(activeSessionTimerProvider.notifier).resume();
    }
  }

  void _startRestTimer() {
    final duration = _restDurations[_currentExerciseIndex] ?? 90;
    setState(() {
      _isResting = true;
      _restSeconds = duration;
    });
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds > 0) {
        setState(() => _restSeconds--);
      } else {
        _closeRestTimer();
      }
    });
  }

  void _showRestDurationPicker(BuildContext context) {
    final duration = _restDurations[_currentExerciseIndex] ?? 90;
    final options = [30, 60, 90, 120, 180, 240, 300];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(5.w, 3.h, 5.w, 1.h),
              child: Text(
                'rest_duration_for_exercise'.tr(context),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ),
            ...options.map((secs) {
              final selected = secs == duration;
              final label = secs < 60
                  ? '$secs ${'sec'.tr(context)}'
                  : '${secs ~/ 60} ${'min'.tr(context)}${secs % 60 != 0 ? ' ${secs % 60}s' : ''}';
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected
                        ? const Color(0xFF007AFF)
                        : const Color(0xFF1C1C1E),
                  ),
                ),
                trailing: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: const Color(0xFF007AFF),
                        size: 18.sp,
                      )
                    : null,
                onTap: () {
                  setState(() {
                    _restDurations[_currentExerciseIndex] = secs;
                    if (_isResting) _restSeconds = secs;
                  });
                  Navigator.pop(ctx);
                },
              );
            }),
            SizedBox(height: 1.h),
          ],
        ),
      ),
    );
  }

  void _closeRestTimer() {
    _restTimer?.cancel();
    setState(() => _isResting = false);
  }

  void _addRestTime() {
    setState(() => _restSeconds += 15);
  }

  int get _completedSets {
    int count = 0;
    _exerciseSets.forEach((_, sets) {
      for (var s in sets) {
        if ([''] == true) count++;
      }
    });
    return count;
  }

  int get _totalSets {
    int count = 0;
    _exerciseSets.forEach((_, sets) {
      count += sets.length;
    });
    return count;
  }

  void _logNextSet() {
    final currentSets = _exerciseSets[_currentExerciseIndex]!;
    int setIndex = currentSets.indexWhere((s) => ['done'] != true);

    if (setIndex != -1) {
      // Mark set done
      setState(() {
        currentSets[setIndex]['done'] = true;
      });
      _startRestTimer();
    } else {
      // If all done in this exercise, go to next
      if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
        _nextExercise();
      } else {
        _confirmFinish(context);
      }
    }
  }

  void _confirmFinish(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        title: Text(
          'finish_workout_q'.tr(context),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        content: Text(
          '${'progress_will_be_saved_1'.tr(context)}$_completedSets${'progress_will_be_saved_2'.tr(context)}$_totalSets${'progress_will_be_saved_3'.tr(context)}',
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
              'keep_going'.tr(context),
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
              _finishSession(context);
            },
            child: Text(
              'finish'.tr(context),
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF1C1C1E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _finishSession(BuildContext context) {
    if (_sessionFinished) return;
    _sessionFinished = true;
    final now = DateTime.now();

    // Build exercises log
    final List<Map<String, dynamic>> exercisesLog = [];
    for (int i = 0; i < widget.routine.exercises.length; i++) {
      final ex = widget.routine.exercises[i];
      final sets = _exerciseSets[i]!;
      final logSets = [];
      for (int s = 0; s < sets.length; s++) {
        if (sets[s]['done'] == true) {
          logSets.add({
            'setIndex': s + 1,
            'kg': (sets[s]['kgCtrl'] as TextEditingController).text,
            'reps': (sets[s]['repsCtrl'] as TextEditingController).text,
          });
        }
      }
      if (logSets.isNotEmpty) {
        exercisesLog.add({'name': ex.name, 'sets': logSets});
      }
    }

    final session = CompletedSession(
      date: DateFormat('MMM d').format(now),
      dayName: DateFormat('EEE d').format(now).toUpperCase(),
      routineName: widget.routine.routineName,
      durationMinutes: ref.read(activeSessionTimerProvider) ~/ 60,
      completedSets: _completedSets,
      totalSets: _totalSets,
      category: widget.routine.category,
      timestampIso: now.toIso8601String(),
      exercisesLog: exercisesLog.isNotEmpty ? exercisesLog : null,
    );
    ref.read(workoutHistoryProvider.notifier).addSession(session);

    // Save all max weights from completed sets
    final exerciseHistory = ref.read(exerciseHistoryProvider.notifier);
    for (int i = 0; i < widget.routine.exercises.length; i++) {
      final ex = widget.routine.exercises[i];
      double maxWeight = 0.0;
      for (var set in _exerciseSets[i]!) {
        if ([''] == true) {
          final kg =
              double.tryParse((set['kgCtrl'] as TextEditingController).text) ??
              0.0;
          if (kg > maxWeight) maxWeight = kg;
        }
      }
      if (maxWeight > 0.0) {
        exerciseHistory.updateWeight(ex.name, maxWeight);
      }
    }

    final user = ref.read(currentUserModelProvider).asData?.value;
    if (user != null) {
      ref
          .read(trophyServiceProvider)
          .awardTrophiesOnce(
            context: context,
            uid: user.uid,
            awardId: 'workout_${widget.routine.id}_${session.timestampIso}',
            amount: 15,
            reason: 'crushed_workout_session'.tr(context),
          );
    }

    _showWorkoutCompletedOverlay(context);
  }

  void _showWorkoutCompletedOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(4.w),
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(6.w),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      context.go('/dashboard');
                    },
                    child: Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 14.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 1.h),
              Container(
                width: 20.w,
                height: 20.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40.sp,
                ),
              ),
              SizedBox(height: 3.h),
              Text(
                'workout_completed'.tr(context),
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                '${'sets_finished_great_job_1'.tr(context)}$_completedSets${'sets_finished_great_job_2'.tr(context)}$_totalSets${'sets_finished_great_job_3'.tr(context)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // exerciseHistoryProvider is now watched via listenManual in initState —
    // mutations happen outside build() to avoid side-effects during rendering.
    final currentEx = widget.routine.exercises[_currentExerciseIndex];
    final currentSets = _exerciseSets[_currentExerciseIndex]!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Opacity(
              opacity: widget.isViewOnly ? 0.6 : 1.0,
              child: Column(
                children: [
                  _buildTopBar(context),
                  if (widget.isViewOnly)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: 1.5.h,
                        horizontal: 4.4.w,
                      ),
                      color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: const Color(0xFFB07D10),
                            size: 16.sp,
                          ),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              '${'scheduled_for'.tr(context)}${widget.scheduledDay ?? 'future_text'.tr(context)}${'view_only_mode'.tr(context)}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7A4D0A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: widget.isViewOnly ? 5.h : 20.h,
                      ),
                      child: Column(
                        children: [
                          _buildSessionHeader(context),
                          _buildExerciseSection(currentEx, currentSets),
                          if (!widget.isViewOnly) _buildPlateCalc(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Finish Bar
          if (!widget.isViewOnly)
            PositionedDirectional(bottom: 0, start: 0, end: 0, child: _buildFinishBar(context)),

          // Rest Overlay
          if (_isResting) _buildRestOverlay(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 12.sp,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ),
          Text(
            widget.routine.category,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final currentExName =
                      widget.routine.exercises[_currentExerciseIndex].name;
                  ExerciseVideoSheet.show(context, currentExName);
                },
                child: Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14.sp,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('more_options'.tr(context))),
                  );
                },
                child: Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 14.sp,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeader(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(4.5.w),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'ai_coach_day'.tr(context)}${widget.routine.category.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.4),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      widget.routine.routineName,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2.5.w),
                ),
                child: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        return Text(
                          ref.watch(formattedTimeProvider),
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        );
                      },
                    ),
                    Text(
                      'elapsed_time'.tr(context),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          // Segments
          Row(
            children: List.generate(widget.routine.exercises.length, (index) {
              Color color = Colors.white.withValues(alpha: 0.12);
              if (index < _currentExerciseIndex) {
                color = const Color(0xFF34C759);
              }
              if (index == _currentExerciseIndex) {
                color = const Color(0xFF007AFF);
              }
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSection(
    RoutineExercise ex,
    List<Map<String, dynamic>> sets,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'exercise_of_1'.tr(context)}${_currentExerciseIndex + 1}${'exercise_of_2'.tr(context)}${widget.routine.exercises.length}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E8E93),
                        letterSpacing: 0.4,
                      ),
                    ),
                    SizedBox(height: 0.3.h),
                    Text(
                      ex.name,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _prevExercise,
                    child: Container(
                      width: 7.5.w,
                      height: 7.5.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 16.sp,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  SizedBox(width: 1.5.w),
                  GestureDetector(
                    onTap: _nextExercise,
                    child: Container(
                      width: 7.5.w,
                      height: 7.5.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 16.sp,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 1.5.h),

          // Sets Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E5EA)),
              borderRadius: BorderRadius.circular(3.5.w),
            ),
            child: Column(
              children: [
                // Thead
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F9FB),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(3.5.w),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 7.w,
                        child: Text(
                          'set'.tr(context).toUpperCase(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 14.w,
                        child: Center(
                          child: Text(
                            'prev'.tr(context).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'reps_upper'.tr(context).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'kg_upper'.tr(context).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'rpe_upper'.tr(context).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
                  ),
                ),
                // Rows
                ...sets.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var set = entry.value;
                  bool isDone = ['done'] == true;
                  return Dismissible(
                    key: ValueKey(
                      '${ex.name}_set_${idx}_${DateTime.now().millisecondsSinceEpoch}',
                    ),
                    direction: isDone || widget.isViewOnly || sets.length <= 1
                        ? DismissDirection.none
                        : DismissDirection.endToStart,
                    onDismissed: (_) {
                      setState(() {
                        sets.removeAt(idx);
                      });
                    },
                    background: Container(
                      color: const Color(0xFFFF3B30),
                      alignment: AlignmentDirectional.centerEnd,
                      padding: EdgeInsetsDirectional.only(end: 4.w),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                    ),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 2.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFFFDFFFE)
                            : Colors.transparent,
                        border: const Border(
                          top: BorderSide(color: Color(0xFFF0F0F5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 7.w,
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 14.w,
                            child: Column(
                              children: [
                                Text(
                                  set['prev'] == '-' ? '-' : set['prev']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: set['prev'] == '-'
                                        ? const Color(0xFFD1D1D6)
                                        : const Color(0xFFC7C7CC),
                                  ),
                                ),
                                Text(
                                  set['prev'] == '-' ? 'first' : 'kg',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: const Color(0xFFD1D1D6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 1.w),
                              child: Container(
                                height: 4.5.h,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFFE8FFF0)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(2.w),
                                  border: Border.all(
                                    color: isDone
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFE5E5EA),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: TextField(
                                  controller: set['repsCtrl'] as TextEditingController?,
                                  enabled: !isDone && !widget.isViewOnly,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDone
                                        ? const Color(0xFF1A7A30)
                                        : Colors.black,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.only(bottom: 8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 1.w),
                              child: Container(
                                height: 4.5.h,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFFE8FFF0)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(2.w),
                                  border: Border.all(
                                    color: isDone
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFE5E5EA),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: TextField(
                                  controller: set['kgCtrl'] as TextEditingController?,
                                  enabled: !isDone && !widget.isViewOnly,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDone
                                        ? const Color(0xFF1A7A30)
                                        : Colors.black,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.only(bottom: 8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 1.w),
                              child: Container(
                                height: 4.5.h,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFFE8FFF0)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(2.w),
                                  border: Border.all(
                                    color: isDone
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFE5E5EA),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: TextField(
                                  controller: set['rpeCtrl'] as TextEditingController?,
                                  enabled: !isDone && !widget.isViewOnly,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDone
                                        ? const Color(0xFF1A7A30)
                                        : Colors.black,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.only(bottom: 8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 1.w),
                          if (!widget.isViewOnly)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  set['done'] = ['done'] != true;
                                });
                                if ([''] == true) {
                                  _startRestTimer();
                                }
                              },
                              child: Container(
                                width: 7.5.w,
                                height: 7.5.w,
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? const Color(0xFF34C759)
                                      : const Color(0xFFF5F5F7),
                                  borderRadius: BorderRadius.circular(2.w),
                                  border: Border.all(
                                    color: isDone
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFE5E5EA),
                                  ),
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: isDone
                                      ? Colors.white
                                      : const Color(0xFFC7C7CC),
                                  size: 14.sp,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Add Set
          if (!widget.isViewOnly)
            GestureDetector(
              onTap: () {
                setState(() {
                  sets.add({
                    'repsCtrl': TextEditingController(
                      text:
                          (sets.last['repsCtrl'] as TextEditingController).text,
                    ),
                    'kgCtrl': TextEditingController(
                      text: (sets.last['kgCtrl'] as TextEditingController).text,
                    ),
                    'rpeCtrl': TextEditingController(
                      text:
                          (sets.last['rpeCtrl'] as TextEditingController).text,
                    ),
                    'done': false,
                    'prev': sets.last['prev'],
                    'prevLoaded': true,
                  });
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      color: const Color(0xFF007AFF),
                      size: 14.sp,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      'add_set'.tr(context),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF007AFF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlateCalc(BuildContext context) {
    return GestureDetector(
      onTap: () => PlateCalculatorSheet.show(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 1.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          border: Border.all(color: const Color(0xFFF5D78E)),
          borderRadius: BorderRadius.circular(3.w),
        ),
        child: Row(
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                color: Colors.white,
                size: 14.sp,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'plate_calculator'.tr(context),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7A4D0A),
                    ),
                  ),
                  Text(
                    'plate_calculator_desc'.tr(context),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFFB07D10),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: const Color(0xFFB07D10),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishBar(BuildContext context) {
    int total = _totalSets;
    int completed = _completedSets;
    double progress = total == 0 ? 0 : completed / total;

    return Container(
      padding: EdgeInsetsDirectional.only(
        start: 4.4.w,
        end: 4.4.w,
        top: 1.h,
        bottom: 3.h,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5EA))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Text(
                '$completed / $total ${'sets'.tr(context)}',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() => _isPaused = !_isPaused);
                  if (_isPaused) {
                    ref.read(activeSessionTimerProvider.notifier).pause();
                  } else {
                    ref.read(activeSessionTimerProvider.notifier).resume();
                  }
                },
                child: Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                    borderRadius: BorderRadius.circular(3.5.w),
                  ),
                  child: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: const Color(0xFF1C1C1E),
                    size: 16.sp,
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: GestureDetector(
                  onTap: _logNextSet,
                  child: Container(
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759),
                      borderRadius: BorderRadius.circular(3.5.w),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'log_set_done'.tr(context),
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              GestureDetector(
                onTap: () => _confirmFinish(context),
                child: Container(
                  height: 12.w,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                    borderRadius: BorderRadius.circular(3.5.w),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'finish'.tr(context),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3A3A3C),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.97),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: EdgeInsetsDirectional.only(top: 8.h, end: 6.w),
                child: GestureDetector(
                  onTap: _closeRestTimer,
                  child: Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 14.sp,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'rest_time'.tr(context),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.4),
                    letterSpacing: 0.7,
                  ),
                ),
                SizedBox(width: 2.w),
                GestureDetector(
                  onTap: () => _showRestDurationPicker(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.w,
                      vertical: 0.4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Text(
                      'edit_text'.tr(context),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: 45.w,
              height: 45.w,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value:
                        _restSeconds /
                        (_restDurations[_currentExerciseIndex] ?? 90)
                            .toDouble(),
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: const Color(0xFF34C759),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$_restSeconds',
                        style: TextStyle(
                          fontSize: 40.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      Text(
                        'seconds'.tr(context),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'great_set_rest_up'.tr(context),
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 1.h),
            _buildNextSetInfo(context),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRestBtn(
                  'skip_rest'.tr(context),
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white,
                  _closeRestTimer,
                ),
                SizedBox(width: 2.w),
                _buildRestBtn(
                  'add_15s'.tr(context),
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white,
                  _addRestTime,
                ),
                SizedBox(width: 2.w),
                _buildRestBtn(
                  'next_set_arrow'.tr(context),
                  const Color(0xFF34C759),
                  Colors.white,
                  _closeRestTimer,
                ),
              ],
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSetInfo(BuildContext context) {
    // Find next set
    final currentSets = _exerciseSets[_currentExerciseIndex]!;
    int setIndex = currentSets.indexWhere((s) => ['done'] != true);

    if (setIndex != -1) {
      final nextSet = currentSets[setIndex];
      final reps = (nextSet['repsCtrl'] as TextEditingController).text;
      final kg = (nextSet['kgCtrl'] as TextEditingController).text;
      return Text(
        '${'next_set_colon'.tr(context)}${setIndex + 1} · $reps ${'reps_upper'.tr(context).toLowerCase()} · $kg ${'kg_upper'.tr(context).toLowerCase()}',
        style: TextStyle(
          fontSize: 14.sp,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      );
    } else {
      if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
        return Text(
          '${'next_colon'.tr(context)}${widget.routine.exercises[_currentExerciseIndex + 1].name}',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        );
      } else {
        return Text(
          'workout_complete_exclamation'.tr(context),
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        );
      }
    }
  }

  Widget _buildRestBtn(
    String text,
    Color bg,
    Color textCol,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 1.2.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3.w),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: textCol,
          ),
        ),
      ),
    );
  }
}
