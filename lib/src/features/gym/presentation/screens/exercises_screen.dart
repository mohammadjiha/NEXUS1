import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../controllers/exercises_screen_provider.dart';
import '../../data/exercises_repository.dart';

class ExercisesScreen extends ConsumerWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredExercisesAsync = ref.watch(filteredExercisesProvider);
    final allGroupsAsync = ref.watch(allExercisesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        title: Text(
          'exercises'.tr(context),
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1C1C1E),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Search Bar & Filter
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.4.w),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3.w),
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                      ),
                      child: TextField(
                        onChanged: (value) =>
                            ref.read(searchQueryProvider.notifier).state =
                                value,
                        decoration: InputDecoration(
                          hintText: 'search_exercises'.tr(context),
                          hintStyle: TextStyle(
                            color: const Color(0xFF8E8E93),
                            fontSize: 14.sp,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF8E8E93),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 1.5.h),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  GestureDetector(
                    onTap: () => _showFilterBottomSheet(context, ref),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 1.4.h,
                        horizontal: 3.5.w,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(3.w),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 22.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2.h),

            // Categories
            allGroupsAsync.when(
              data: (groups) {
                final categories = ['All', ...groups.map((g) => g.muscleGroup)];
                return SizedBox(
                  height: 4.5.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 4.4.w),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = selectedCategory == category;
                      final categoryLabel = category == 'All'
                          ? 'all'.tr(context)
                          : groups
                                .firstWhere((g) => g.muscleGroup == category)
                                .localizedMuscleGroup(locale);
                      return GestureDetector(
                        onTap: () =>
                            ref.read(selectedCategoryProvider.notifier).state =
                                category,
                        child: Container(
                          margin: EdgeInsetsDirectional.only(end: 2.w),
                          padding: EdgeInsets.symmetric(horizontal: 5.w),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1C1C1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4.w),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFE5E5EA),
                            ),
                          ),
                          child: Text(
                            categoryLabel,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF3A3A3C),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox(),
              error: (err, stack) => const SizedBox(),
            ),
            SizedBox(height: 2.h),

            // Exercises List
            Expanded(
              child: filteredExercisesAsync.when(
                data: (exercises) {
                  if (exercises.isEmpty) {
                    return Center(
                      child: Text(
                        'no_exercises_found'.tr(context),
                        style: TextStyle(
                          color: const Color(0xFF8E8E93),
                          fontSize: 14.sp,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsetsDirectional.only(
                      start: 4.4.w,
                      end: 4.4.w,
                      bottom: 12.h,
                    ),
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      final name = exercise.localizedName(locale);
                      final targetMuscle = exercise.localizedTargetMuscleGroup(
                        locale,
                      );
                      final equipment = exercise.localizedEquipmentRequired(
                        locale,
                      );
                      return GestureDetector(
                        onTap: () {
                          context.push('/exercise_details', extra: exercise);
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 1.5.h),
                          padding: EdgeInsets.all(3.5.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4.w),
                            border: Border.all(
                              color: const Color(0xFFE5E5EA),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 14.w,
                                height: 14.w,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F9FB),
                                  borderRadius: BorderRadius.circular(3.w),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.fitness_center_rounded,
                                  size: 22.sp,
                                  color: const Color(0xFF1C1C1E),
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1C1C1E),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 0.5.h),
                                    Text(
                                      '$targetMuscle • $equipment',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF8E8E93),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFC7C7CC),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    Center(child: Text('${'error'.tr(context)}: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      builder: (context) => _FilterBottomSheet(),
    );
  }
}

class _FilterBottomSheet extends ConsumerWidget {
  String _filterOptionLabel(BuildContext context, String value) {
    switch (value.toLowerCase()) {
      case 'all':
        return 'all'.tr(context);
      case 'dumbbell':
        return 'dumbbell'.tr(context);
      case 'barbell':
        return 'barbell'.tr(context);
      case 'cable':
        return 'cable'.tr(context);
      case 'machine':
        return 'machine'.tr(context);
      case 'bodyweight':
        return 'bodyweight'.tr(context);
      case 'beginner':
        return 'beginner'.tr(context);
      case 'intermediate':
        return 'intermediate'.tr(context);
      case 'advanced':
        return 'advanced'.tr(context);
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(filtersProvider);

    return Container(
      padding: EdgeInsetsDirectional.only(
        start: 5.w,
        end: 5.w,
        bottom: MediaQuery.of(context).padding.bottom + 3.h,
        top: 2.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 12.w,
              height: 0.6.h,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(1.w),
              ),
            ),
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'filters'.tr(context),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(filtersProvider.notifier).state = ExerciseFilters();
                  context.pop();
                },
                child: Text(
                  'reset'.tr(context),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Text(
            'equipment'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3A3A3C),
            ),
          ),
          SizedBox(height: 1.5.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.5.h,
            children:
                [
                  'All',
                  'Dumbbell',
                  'Barbell',
                  'Cable',
                  'Machine',
                  'Bodyweight',
                ].map((eq) {
                  final isSelected =
                      filters.equipment.toLowerCase() == eq.toLowerCase();
                  return GestureDetector(
                    onTap: () {
                      ref.read(filtersProvider.notifier).state = filters
                          .copyWith(equipment: eq);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFFF0F0F5),
                        borderRadius: BorderRadius.circular(4.w),
                      ),
                      child: Text(
                        _filterOptionLabel(context, eq),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF8E8E93),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          SizedBox(height: 3.h),
          Text(
            'experience_level'.tr(context),
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3A3A3C),
            ),
          ),
          SizedBox(height: 1.5.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.5.h,
            children: ['All', 'Beginner', 'Intermediate', 'Advanced'].map((
              lvl,
            ) {
              final isSelected =
                  filters.level.toLowerCase() == lvl.toLowerCase();
              return GestureDetector(
                onTap: () {
                  ref.read(filtersProvider.notifier).state = filters.copyWith(
                    level: lvl,
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1C1C1E)
                        : const Color(0xFFF0F0F5),
                    borderRadius: BorderRadius.circular(4.w),
                  ),
                  child: Text(
                    _filterOptionLabel(context, lvl),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 4.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.w),
                ),
              ),
              child: Text(
                'apply_filters'.tr(context),
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
