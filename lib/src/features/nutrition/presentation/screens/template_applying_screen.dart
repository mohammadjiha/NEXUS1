import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../domain/models/diet_template_model.dart';
import 'template_overview_screen.dart';

class TemplateApplyingScreen extends StatefulWidget {
  final DietTemplateModel template;

  const TemplateApplyingScreen({super.key, required this.template});

  @override
  State<TemplateApplyingScreen> createState() => _TemplateApplyingScreenState();
}

class _TemplateApplyingScreenState extends State<TemplateApplyingScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isFinished = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<String> _getSteps(BuildContext context) {
    return [
      'reading_body_data'.tr(context),
      'calculating_calorie_targets'.tr(context),
      'building_meal_plan'.tr(context),
      'scheduling_meal_timings'.tr(context),
    ];
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startAnimation(BuildContext context) async {
    final stepsLength = _getSteps(context).length;
    for (int i = 0; i < stepsLength; i++) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      setState(() {
        _currentStep++;
      });
    }
    
    // Finish
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _isFinished = true;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 0 && !_isFinished) {
      _startAnimation(context);
    }
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Column(
                  children: [
                    SizedBox(height: 8.h),
                    // Fire Spinner
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 16.w,
                        height: 16.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        alignment: Alignment.center,
                        child: Text('🔥', style: TextStyle(fontSize: 28.sp)),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "${'applying'.tr(context)}${widget.template.title}",
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1C1C1E),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'adjusting_targets_body_data'.tr(context),
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF8E8E93),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6.h),
                    
                    // Steps List
                    ...List.generate(_getSteps(context).length, (index) {
                      final isDone = _currentStep > index;
                      final isCurrent = _currentStep == index;
                      final isWaiting = _currentStep < index;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 2.h),
                        child: Row(
                          children: [
                            Container(
                              width: 8.w,
                              height: 8.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? const Color(0xFF34C759)
                                    : const Color(0xFFE5E5EA),
                              ),
                              alignment: Alignment.center,
                              child: isDone
                                  ? Icon(Icons.check, color: Colors.white, size: 5.w)
                                  : isCurrent
                                      ? SizedBox(
                                          width: 4.w,
                                          height: 4.w,
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        )
                                      : null,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              _getSteps(context)[index],
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: isDone
                                    ? const Color(0xFF34C759)
                                    : isCurrent
                                        ? const Color(0xFF3A3A3C)
                                        : const Color(0xFFC7C7CC),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            
            // Bottom Action
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 10.h),
              child: AnimatedOpacity(
                opacity: _isFinished ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_isFinished,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TemplateOverviewScreen(template: widget.template),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      minimumSize: Size(double.infinity, 7.5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4.w),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20.sp),
                        SizedBox(width: 3.w),
                        Text(
                          'plan_ready_overview'.tr(context),
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
            ),
          ],
        ),
      ),
    );
  }
}
