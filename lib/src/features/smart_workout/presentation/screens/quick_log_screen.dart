import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../models/routine_model.dart';
import '../../providers/routines_provider.dart';

class QuickLogScreen extends ConsumerStatefulWidget {
  final String? restrictedCategory;
  const QuickLogScreen({super.key, this.restrictedCategory});

  @override
  ConsumerState<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends ConsumerState<QuickLogScreen> {
  late final List<String> _selectedMuscles;

  @override
  void initState() {
    super.initState();
    if (widget.restrictedCategory != null) {
      _selectedMuscles = [widget.restrictedCategory!];
    } else {
      _selectedMuscles = ['Chest'];
    }
  }

  RoutineModel? _selectedRoutine;

  final List<Map<String, dynamic>> _muscles = [
    {
      'name': 'Chest',
      'count': 24,
      'icon': Icons.fitness_center_rounded,
      'color': const Color(0xFF0A64B0),
      'bg': const Color(0xFFE8F5FF),
    },
    {
      'name': 'Back',
      'count': 31,
      'icon': Icons.panorama_wide_angle_rounded,
      'color': const Color(0xFF0A64B0),
      'bg': const Color(0xFFEBF5FF),
    },
    {
      'name': 'Shoulders',
      'count': 18,
      'icon': Icons.sports_gymnastics_rounded,
      'color': const Color(0xFF1A7A30),
      'bg': const Color(0xFFE8FFF0),
    },
    {
      'name': 'Biceps',
      'count': 14,
      'icon': Icons.sports_martial_arts_rounded,
      'color': const Color(0xFFC05A0A),
      'bg': const Color(0xFFFFF0E8),
    },
    {
      'name': 'Triceps',
      'count': 16,
      'icon': Icons.sports_handball_rounded,
      'color': const Color(0xFF7A4D0A),
      'bg': const Color(0xFFFFF8E8),
    },
    {
      'name': 'Legs',
      'count': 28,
      'icon': Icons.directions_run_rounded,
      'color': const Color(0xFF7A4D0A),
      'bg': const Color(0xFFFFF8E8),
    },
    {
      'name': 'Traps',
      'count': 10,
      'icon': Icons.accessibility_new_rounded,
      'color': const Color(0xFF5B3FBF),
      'bg': const Color(0xFFF0EEFF),
    },
    {
      'name': 'Cardio',
      'count': 15,
      'icon': Icons.directions_bike_rounded,
      'color': const Color(0xFFE53935),
      'bg': const Color(0xFFFFEBEE),
    },
    {
      'name': 'Full Body Fat Loss',
      'count': 20,
      'icon': Icons.local_fire_department_rounded,
      'color': const Color(0xFFFF9800),
      'bg': const Color(0xFFFFF3E0),
    },
    {
      'name': 'Abs',
      'count': 22,
      'icon': Icons.grid_view_rounded,
      'color': const Color(0xFF5B3FBF),
      'bg': const Color(0xFFF0EEFF),
    },
    {
      'name': 'Glutes',
      'count': 18,
      'icon': Icons.accessibility_new_rounded,
      'color': const Color(0xFFC05A0A),
      'bg': const Color(0xFFFFF0E8),
    },
  ];

  void _toggleMuscle(String name, BuildContext context) {
    if (widget.restrictedCategory != null &&
        name != widget.restrictedCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${'restricted_training_message_prefix'.tr(context)} ${widget.restrictedCategory} ${'restricted_training_message_suffix'.tr(context)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    setState(() {
      if (widget.restrictedCategory != null) {
        return; // Cannot toggle off if restricted
      }
      if (_selectedMuscles.contains(name)) {
        _selectedMuscles.remove(name);
      } else {
        _selectedMuscles.add(name);
      }
      _selectedRoutine = null; // Reset selection on category change
    });
  }

  void _selectRoutine(RoutineModel routine) {
    setState(() {
      if (_selectedRoutine == routine) {
        _selectedRoutine = null;
      } else {
        _selectedRoutine = routine;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(msRoutinesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                _buildBreadcrumb(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 15.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.4.w,
                            vertical: 1.h,
                          ),
                          child: Text(
                            'what_are_you_training_today'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8E8E93),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _buildMuscleGrid(context),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.4.w,
                            vertical: 2.h,
                          ),
                          child: Text(
                            'recommended_routines'.tr(context),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8E8E93),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _buildRoutinesList(routinesAsync, context),
                        SizedBox(height: 3.h),
                        _buildSaveTemplate(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // CTA Abs
          PositionedDirectional(
            bottom: 0,
            start: 0,
            end: 0,
            child: Container(
              padding: EdgeInsetsDirectional.only(
                start: 4.4.w,
                end: 4.4.w,
                top: 2.h,
                bottom: 4.h,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
                ),
              ),
              child: ElevatedButton(
                onPressed: _selectedRoutine == null
                    ? null
                    : () {
                        context.push(
                          '/active-session',
                          extra: _selectedRoutine,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedRoutine == null
                      ? const Color(0xFFE5E5EA)
                      : const Color(0xFF1C1C1E),
                  padding: EdgeInsets.symmetric(vertical: 1.8.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.5.w),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18.sp,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'start_session'.tr(context),
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
            'quick_log'.tr(context),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.3,
            ),
          ),
          GestureDetector(
            onTap: () {},
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
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 1.h),
      child: Row(
        children: [
          Text(
            'home'.tr(context),
            style: TextStyle(fontSize: 15.sp, color: const Color(0xFF8E8E93)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.5.w),
            child: Text(
              '›',
              style: TextStyle(fontSize: 15.sp, color: const Color(0xFFD1D1D6)),
            ),
          ),
          Text(
            'free_session'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleGrid(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.4.w),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 2.w,
        crossAxisSpacing: 2.w,
        childAspectRatio: 2.5,
      ),
      itemCount: _muscles.length,
      itemBuilder: (context, index) {
        final m = _muscles[index];
        bool isSel = _selectedMuscles.contains(m['name']);

        bool isRestrictedOut =
            widget.restrictedCategory != null &&
            m['name'] as String != widget.restrictedCategory;

        return GestureDetector(
          onTap: () => _toggleMuscle(m['name'] as String, context),
          child: Opacity(
            opacity: isRestrictedOut ? 0.35 : 1.0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFFFAFAFA) : Colors.white,
                borderRadius: BorderRadius.circular(3.5.w),
                border: Border.all(
                  color: isSel
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFE5E5EA),
                  width: isSel ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 9.w,
                    height: 9.w,
                    decoration: BoxDecoration(
                      color: m['bg'] as Color?,
                      borderRadius: BorderRadius.circular(2.5.w),
                    ),
                    child: Icon(
                      m['icon'] as IconData?,
                      color: (m['color'] as Color).withValues(alpha: 0.5),
                      size: 16.sp,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            m['name'] as String,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                        ),
                        Text(
                          '${m['count']} ${'routines_label'.tr(context)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 4.5.w,
                    height: 4.5.w,
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0xFF1C1C1E)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFD1D1D6),
                        width: 1.5,
                      ),
                    ),
                    child: isSel
                        ? Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12.sp,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoutinesList(AsyncValue<List<RoutineModel>> routinesAsync, BuildContext context) {
    return routinesAsync.when(
      data: (routines) {
        final filtered = routines
            .where((r) => _selectedMuscles.contains(r.category))
            .toList();

        if (filtered.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.4.w, vertical: 4.h),
            child: Center(
              child: Text(
                _selectedMuscles.isEmpty
                    ? 'select_muscle_first'.tr(context)
                    : 'no_routines_found'.tr(context),
                style: TextStyle(
                  fontSize: 13.sp,
                  color: const Color(0xFF8E8E93),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.4.w),
          child: Column(
            children: filtered.map((routine) {
              bool isSelected = _selectedRoutine == routine;
              return GestureDetector(
                onTap: () => _selectRoutine(routine),
                child: Container(
                  margin: EdgeInsets.only(bottom: 1.5.h),
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF4F9FF) : Colors.white,
                    borderRadius: BorderRadius.circular(3.5.w),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF007AFF)
                          : const Color(0xFFE5E5EA),
                      width: isSelected ? 2.0 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF007AFF)
                              : const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                        child: Icon(
                          Icons.fitness_center_rounded,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF8E8E93),
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.routineName,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1C1C1E),
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              '${routine.exercises.length} ${'exercises_label'.tr(context)} · ${routine.category}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 6.w,
                          height: 6.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFF007AFF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12.sp,
                          ),
                        )
                      else
                        Icon(
                          Icons.circle_outlined,
                          color: const Color(0xFFD1D1D6),
                          size: 18.sp,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => Center(
        child: Padding(
          padding: EdgeInsets.all(4.h),
          child: const CircularProgressIndicator(color: Color(0xFF1C1C1E)),
        ),
      ),
      error: (err, stack) => Center(
        child: Text(
          'error_loading_routines'.tr(context),
          style: TextStyle(color: Colors.red, fontSize: 13.sp),
        ),
      ),
    );
  }

  Future<void> _saveTemplate(BuildContext context) async {
    if (_selectedRoutine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_routine_first'.tr(context))),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: _selectedRoutine!.routineName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.w)),
        title: Text(
          'save_as_template'.tr(context),
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'give_template_name'.tr(context),
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF6E6E73)),
            ),
            SizedBox(height: 1.5.h),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'template_name'.tr(context),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 3.w,
                  vertical: 1.2.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.5.w),
                  borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2.5.w),
                  borderSide: const BorderSide(color: Color(0xFF007AFF)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'cancel'.tr(context),
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'save_capital'.tr(context),
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('not_signed_in'.tr(context))));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('templates')
          .add({
            'name': nameCtrl.text.trim().isEmpty
                ? _selectedRoutine!.routineName
                : nameCtrl.text.trim(),
            'routineId': _selectedRoutine!.id,
            'routineName': _selectedRoutine!.routineName,
            'category': _selectedRoutine!.category,
            'muscles': _selectedMuscles,
            'createdAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('template_saved'.tr(context))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'failed_to_save'.tr(context)} $e')),
        );
      }
    }
  }

  Widget _buildSaveTemplate(BuildContext context) {
    final hasRoutine = _selectedRoutine != null;
    return GestureDetector(
      onTap: () => _saveTemplate(context),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.4.w),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: hasRoutine ? const Color(0xFFF4F9FF) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(
            color: hasRoutine
                ? const Color(0xFF007AFF).withValues(alpha: 0.3)
                : const Color(0xFFE5E5EA),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 9.w,
              height: 9.w,
              decoration: BoxDecoration(
                color: hasRoutine
                    ? const Color(0xFF007AFF)
                    : const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Icon(
                Icons.bookmark_add_rounded,
                color: Colors.white,
                size: 16.sp,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'save_as_template'.tr(context),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: hasRoutine
                          ? const Color(0xFF007AFF)
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    hasRoutine
                        ? '${'save_template_for_next_time_prefix'.tr(context)} "${_selectedRoutine!.routineName}" ${'save_template_for_next_time_suffix'.tr(context)}'
                        : 'select_routine_first'.tr(context),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: hasRoutine
                          ? const Color(0xFF007AFF).withValues(alpha: 0.6)
                          : const Color(0xFFC7C7CC),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: hasRoutine
                  ? const Color(0xFF007AFF)
                  : const Color(0xFFD1D1D6),
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}
