import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../gym/models/exercise_model.dart';
import '../../providers/my_plan_provider.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16.sp,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        title: Text(
          'favorites'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildFavoritesTab(context, ref),
    );
  }

  Widget _buildFavoritesTab(BuildContext context, WidgetRef ref) {
    final savedExercises = ref.watch(myPlanProvider);

    if (savedExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 40.sp,
              color: const Color(0xFFD1D1D6),
            ),
            SizedBox(height: 2.h),
            Text(
              'no_favorites_yet'.tr(context),
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'favorites_empty_desc'.tr(context),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: const Color(0xFF8E8E93),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Group exercises by Muscle Group
    final grouped = <String, List<ExerciseModel>>{};
    for (var ex in savedExercises) {
      grouped.putIfAbsent(ex.targetMuscleGroup, () => []).add(ex);
    }

    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final muscleGroup = grouped.keys.elementAt(index);
        final exercises = grouped[muscleGroup]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 2.h, top: index == 0 ? 0 : 3.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A64B0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Icon(
                      Icons.accessibility_new_rounded,
                      color: const Color(0xFF0A64B0),
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    muscleGroup,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 2.5.w,
                      vertical: 0.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(4.w),
                    ),
                    child: Text(
                      '${exercises.length}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3A3A3C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...exercises.map((ex) => _buildExerciseTile(context, ref, ex)),
          ],
        );
      },
    );
  }

  Widget _buildExerciseTile(
    BuildContext context,
    WidgetRef ref,
    ExerciseModel exercise,
  ) {
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
          border: Border.all(color: const Color(0xFFEBEBF0), width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
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
                border: Border.all(color: const Color(0xFFF0F0F5)),
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                color: const Color(0xFF1C1C1E),
                size: 20.sp,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    exercise.equipmentRequired,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                ref.read(myPlanProvider.notifier).toggleFavorite(exercise);
              },
              icon: Icon(
                Icons.favorite_rounded,
                color: const Color(0xFFFF3B30),
                size: 18.sp,
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFFF5F5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
