import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../domain/models/diet_template_model.dart';
import '../../providers/diet_templates_provider.dart';
import '../widgets/nutrition_settings_sheet.dart';
import 'daily_meal_plan_screen.dart';
import 'template_applying_screen.dart';

class TemplatesScreen extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool autoLoad;
  const TemplatesScreen({super.key, required this.navigatorKey, this.autoLoad = false});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  DietTemplateModel? _selectedTemplate;
  
  String _selectedBodyType = 'All';
  String _selectedGoal = 'All';

  final ScrollController _scrollController = ScrollController();
  int _displayCount = 10;

  final List<String> _bodyTypes = ['All', 'Ectomorph', 'Mesomorph', 'Endomorph'];
  final List<String> _goals = ['All', 'Cutting', 'Bulking', 'Maintenance', 'Fat Loss'];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        setState(() {
          _displayCount += 10;
        });
      }
    });

    if (widget.autoLoad) {
      _checkAutoLoad();
    }
  }

  Future<void> _checkAutoLoad() async {
    final prefs = await SharedPreferences.getInstance();
    final savedJson = prefs.getString('nutrition_active_template_json');
    if (savedJson != null) {
      try {
        final template = DietTemplateModel.fromJson(jsonDecode(savedJson) as Map<String, dynamic>);
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DailyMealPlanScreen(template: template)),
            );
          });
        }
      } catch (e) {
        // ignore
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () => widget.navigatorKey.currentState!.pop(),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16.sp, color: const Color(0xFF1C1C1E)),
        ),
        title: Text(
          'ready_templates'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () {
              NutritionSettingsSheet.show(context, widget.navigatorKey.currentState!);
            },
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 3.w),
              child: Icon(Icons.settings_rounded, size: 20.sp, color: const Color(0xFF1C1C1E)),
            ),
          ),
          GestureDetector(
            onTap: () => _showFilterBottomSheet(context),
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 4.w),
              child: Icon(Icons.tune_rounded, size: 20.sp, color: const Color(0xFF1C1C1E)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ref.watch(dietTemplatesProvider).when(
              data: (plans) {
                if (plans.isEmpty) {
              return Center(child: Text('no_plans_found_goal'.tr(context)));
            }
            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
                        child: Text(
                          'choose_plan_template'.tr(context),
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF8E8E93),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 1.h),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  sliver: Builder(
                    builder: (context) {
                      final filteredPlans = plans.where((plan) {
                        bool matchBody = _selectedBodyType == 'All' ||
                            plan.bodyType.toLowerCase() ==
                                _selectedBodyType.toLowerCase();
                        bool matchGoal = _selectedGoal == 'All' ||
                            plan.goal.toLowerCase().contains(
                                _selectedGoal.toLowerCase());
                        return matchBody && matchGoal;
                      }).toList();

                      final itemsToShow = filteredPlans
                          .take(_displayCount)
                          .toList();

                      return SliverList.builder(
                        itemCount: itemsToShow.length,
                        itemBuilder: (context, index) {
                          final plan = itemsToShow[index];
                          return _buildTemplateCard(plan, context);
                        },
                      );
                    }  ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
            PositionedDirectional(
              start: 0, end: 0, bottom: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 8.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFFF5F5F7),
                      const Color(0xFFF5F5F7).withValues(alpha: 0.0),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedTemplate != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TemplateApplyingScreen(
                              template: _selectedTemplate!,
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B3FBF),
                      minimumSize: Size(double.infinity, 6.5.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.5.w)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 16.sp),
                        SizedBox(width: 2.w),
                        Flexible(
                          child: Text(
                            'apply_template'.tr(context),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(DietTemplateModel plan, BuildContext context) {
    final isSelected = _selectedTemplate?.title == plan.title;
    final icon = _getIconForGoal(plan.goal);
    final name = plan.title;
    final kcal = '${plan.totalCalories} kcal';
    final desc = "${plan.numberOfMeals}${'meals_per_day_target'.tr(context)}${_localizeGoal(plan.goal, context)}.";
    final p = '${plan.macros.protein}g';
    final c = '${plan.macros.carbs}g';
    final f = '${plan.macros.fat}g';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTemplate = plan;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsetsDirectional.only(start: 4.w, end: 4.w, bottom: 1.5.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(
            color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '$icon $name',
                    style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E), letterSpacing: -0.2),
                  ),
                ),
                SizedBox(width: 2.w),
                Row(
                  children: [
                    Text(kcal, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
                    SizedBox(width: 2.w),
                    Container(
                      width: 5.5.w, height: 5.5.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? const Color(0xFF1C1C1E) : Colors.transparent,
                        border: Border.all(color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFFD1D1D6), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: isSelected ? Icon(Icons.circle, color: Colors.white, size: 2.w) : null,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 1.h),
            Text(
              desc,
              style: TextStyle(fontSize: 15.sp, color: const Color(0xFF6E6E73), height: 1.4),
            ),
            SizedBox(height: 1.5.h),
            Row(
              children: [
                _buildMacroPill('P: $p', const Color(0xFF0A64B0), const Color(0xFFE8F5FF)),
                SizedBox(width: 1.5.w),
                _buildMacroPill('C: $c', const Color(0xFF7A4D0A), const Color(0xFFFFF8E8)),
                SizedBox(width: 1.5.w),
                _buildMacroPill('F: $f', const Color(0xFFA0220A), const Color(0xFFFFF5F5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroPill(String text, Color color, Color bg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2.5.w),
      ),
      child: Text(text, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: color)),
    );
  }

  String _getIconForGoal(String goal) {
    if (goal.toLowerCase().contains('cut') || goal.toLowerCase().contains('fat')) return '🔥';
    if (goal.toLowerCase().contains('bulk') || goal.toLowerCase().contains('muscle')) return '🏗️';
    if (goal.toLowerCase().contains('maintain')) return '⚖️';
    return '🍽️';
  }

  String _localizeBodyType(String type, BuildContext context) {
    switch (type) {
      case 'All': return 'tab_all'.tr(context);
      case 'Ectomorph': return 'ectomorph'.tr(context);
      case 'Mesomorph': return 'mesomorph'.tr(context);
      case 'Endomorph': return 'endomorph'.tr(context);
      default: return type;
    }
  }

  String _localizeGoal(String goal, BuildContext context) {
    switch (goal) {
      case 'All': return 'tab_all'.tr(context);
      case 'Cutting': return 'cutting'.tr(context);
      case 'Bulking': return 'bulking'.tr(context);
      case 'Maintenance': return 'maintenance_goal'.tr(context);
      case 'Fat Loss': return 'fat_loss'.tr(context);
      default: return goal;
    }
  }

  void _showFilterBottomSheet(BuildContext context) {
    String tempBodyType = _selectedBodyType;
    String tempGoal = _selectedGoal;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 8.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 12.w, height: 0.6.h,
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
                          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E)),
                        ),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              tempBodyType = 'All';
                              tempGoal = 'All';
                            });
                          },
                          child: Text(
                            'reset'.tr(context),
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF007AFF)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'body_type'.tr(context),
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E)),
                    ),
                    SizedBox(height: 1.5.h),
                    Wrap(
                      spacing: 2.w, runSpacing: 1.5.h,
                      children: _bodyTypes.map((type) {
                        final isSelected = tempBodyType == type;
                        return GestureDetector(
                          onTap: () => setModalState(() => tempBodyType = type),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.2.h),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(5.w),
                            ),
                            child: Text(
                              _localizeBodyType(type, context),
                              style: TextStyle(
                                fontSize: 13.sp, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'goal_label'.tr(context),
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E)),
                    ),
                    SizedBox(height: 1.5.h),
                    Wrap(
                      spacing: 2.w, runSpacing: 1.5.h,
                      children: _goals.map((goal) {
                        final isSelected = tempGoal == goal;
                        return GestureDetector(
                          onTap: () => setModalState(() => tempGoal = goal),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.2.h),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(5.w),
                            ),
                            child: Text(
                              _localizeGoal(goal, context),
                              style: TextStyle(
                                fontSize: 13.sp, fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 4.h),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedBodyType = tempBodyType;
                          _selectedGoal = tempGoal;
                          _displayCount = 10;
                        });
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 1.8.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(3.5.w),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'apply_filters'.tr(context),
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
