import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../services/exercise_feedback_service.dart';

class ExerciseFeedbackSheet extends ConsumerStatefulWidget {
  final String originalExercise;
  final String alternativeExercise;

  const ExerciseFeedbackSheet({
    super.key,
    required this.originalExercise,
    required this.alternativeExercise,
  });

  @override
  ConsumerState<ExerciseFeedbackSheet> createState() =>
      _ExerciseFeedbackSheetState();
}

class _ExerciseFeedbackSheetState extends ConsumerState<ExerciseFeedbackSheet> {
  String? _selectedReason;
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Too difficult for my level',
    'Equipment unavailable',
    'Pain or discomfort',
    "Don't like this exercise",
    'Just want variety',
  ];

  String _reasonLabel(BuildContext context, String reason) {
    switch (reason) {
      case 'Too difficult for my level':
        return 'reason_too_difficult'.tr(context);
      case 'Equipment unavailable':
        return 'reason_equipment_unavailable'.tr(context);
      case 'Pain or discomfort':
        return 'reason_pain_discomfort'.tr(context);
      case "Don't like this exercise":
        return 'reason_dislike_exercise'.tr(context);
      case 'Just want variety':
        return 'reason_want_variety'.tr(context);
      default:
        return reason;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    await ref
        .read(exerciseFeedbackServiceProvider)
        .submitFeedback(
          originalExercise: widget.originalExercise,
          alternativeExercise: widget.alternativeExercise,
          reason: _selectedReason!,
          additionalNotes: _notesController.text,
        );

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.pop(context, true); // Returns true indicating success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.only(
        start: 4.w,
        end: 4.w,
        top: 3.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 4.h,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'change_exercise'.tr(context),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(1.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 14.sp),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'You are swapping ${widget.originalExercise} for ${widget.alternativeExercise}. Please let us know why to help us improve your future AI recommendations.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: 3.h),

          ..._reasons.map(
            (reason) => GestureDetector(
              onTap: () => setState(() => _selectedReason = reason),
              child: Container(
                margin: EdgeInsets.only(bottom: 1.5.h),
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _selectedReason == reason
                      ? const Color(0xFF5E5CE6).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: _selectedReason == reason
                        ? const Color(0xFF5E5CE6)
                        : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedReason == reason
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: _selectedReason == reason
                          ? const Color(0xFF5E5CE6)
                          : Colors.white.withValues(alpha: 0.3),
                      size: 16.sp,
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Text(
                        _reasonLabel(context, reason),
                        style: TextStyle(color: Colors.white, fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 3.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting || _selectedReason == null
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E5CE6),
                disabledBackgroundColor: const Color(
                  0xFF5E5CE6,
                ).withValues(alpha: 0.3),
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.w),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 14.sp,
                      height: 14.sp,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'confirm_swap_feedback'.tr(context),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
