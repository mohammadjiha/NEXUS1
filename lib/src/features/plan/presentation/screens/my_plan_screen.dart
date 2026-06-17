import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import '../../../gym/models/exercise_model.dart';
import '../../providers/my_plan_provider.dart';

class MyPlanScreen extends ConsumerWidget {
  const MyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            "My Plan",
            style: TextStyle(
              color: const Color(0xFF1C1C1E),
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F5),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(2.5.w),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF8E8E93),
                labelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                unselectedLabelStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: "Favorites"),
                  Tab(text: "Coach"),
                  Tab(text: "AI Plan"),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _buildFavoritesTab(ref),
            _buildComingSoonTab(Icons.sports_rounded, "Coach Plan Coming Soon", "Your personal trainer will assign your workouts here."),
            _buildComingSoonTab(Icons.auto_awesome_rounded, "AI Plan Coming Soon", "Nexus AI will generate a personalized plan for you based on your goals."),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesTab(WidgetRef ref) {
    final savedExercises = ref.watch(myPlanProvider);

    if (savedExercises.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_rounded, size: 40.sp, color: const Color(0xFFD1D1D6)),
            SizedBox(height: 2.h),
            Text(
              "No Favorites Yet",
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E)),
            ),
            SizedBox(height: 1.h),
            Text(
              "Start exploring exercises and add them\\nto your plan.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93), height: 1.5),
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
                      color: const Color(0xFF0A64B0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Icon(Icons.accessibility_new_rounded, color: const Color(0xFF0A64B0), size: 20.sp),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    muscleGroup,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.3),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(4.w),
                    ),
                    child: Text(
                      "${exercises.length}",
                      style: TextStyle(fontSize: 14
                          .sp, fontWeight: FontWeight.w700, color: const Color(0xFF3A3A3C)),
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

  Widget _buildExerciseTile(BuildContext context, WidgetRef ref, ExerciseModel exercise) {
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
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
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
              child: Icon(Icons.fitness_center_rounded, color: const Color(0xFF1C1C1E), size: 20.sp),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    exercise.equipmentRequired,
                    style: TextStyle(fontSize: 16.sp, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                ref.read(myPlanProvider.notifier).toggleFavorite(exercise);
              },
              icon: Icon(Icons.favorite_rounded, color: const Color(0xFFFF3B30), size: 18.sp),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFFF5F5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComingSoonTab(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(5.w),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF8CFB17).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Icon(icon, size: 35.sp, color: const Color(0xFF8CFB17)),
            ),
            SizedBox(height: 3.h),
            Text(
              title,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.5),
            ),
            SizedBox(height: 1.5.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
