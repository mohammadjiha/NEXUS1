import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';

class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlateCalculatorSheet(),
    );
  }

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  double targetWeight = 100.0;
  double barWeight = 20.0;

  @override
  Widget build(BuildContext context) {
    // Basic calculation
    double plateWeight = (targetWeight - barWeight) / 2;
    if (plateWeight < 0) plateWeight = 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      padding: EdgeInsetsDirectional.only(
        start: 5.w,
        end: 5.w,
        top: 2.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 4.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12.w,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          SizedBox(height: 3.h),
          Column(
            children: [
              Text(
                'plate_calculator'.tr(context).tr(context),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                'target_weight_includes_bar'.tr(context).tr(context),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'target_weight_kg'.tr(context).tr(context),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => targetWeight -= 2.5),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    targetWeight.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => targetWeight += 2.5),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'bar_weight_kg'.tr(context).tr(context),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DropdownButton<double>(
                value: barWeight,
                items: [20.0, 15.0, 10.0]
                    .map(
                      (w) => DropdownMenuItem(
                        value: w,
                        child: Text(
                          '$w ${'kg'.tr(context)}',
                          style: TextStyle(fontSize: 16.sp),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => barWeight = val ?? 20.0),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(4.w),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'load_per_side'.tr(context).tr(context),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF8E8E93),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  '${plateWeight.toStringAsFixed(1)} ${'kg'.tr(context)}',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.w),
                ),
              ),
              child: Text(
                'done'.tr(context).tr(context),
                style: TextStyle(
                  fontSize: 16.sp,
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
