import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';

class NutritionHistoryScreen extends StatefulWidget {
  const NutritionHistoryScreen({super.key});

  @override
  State<NutritionHistoryScreen> createState() => _NutritionHistoryScreenState();
}

class _NutritionHistoryScreenState extends State<NutritionHistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyStr = prefs.getString('nutrition_history');
    if (historyStr != null) {
      setState(() {
        _history = jsonDecode(historyStr);
        // Sort descending by date (newest first)
        _history.sort((a, b) => b['date'].compareTo(a['date']));
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
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
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16.sp,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        title: Text(
          'history_log'.tr(context),
          style: TextStyle(
            color: const Color(0xFF1C1C1E),
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Text(
                    'no_history_logged_yet'.tr(context),
                    style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(4.w),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final record = _history[index];
                    return _buildHistoryCard(record, context);
                  },
                ),
    );
  }

  Widget _buildHistoryCard(dynamic record, BuildContext context) {
    final date = record['date'];
    final consumedKcal = record['consumedKcal'];
    final targetKcal = record['targetKcal'];
    final protein = record['protein'];
    final carbs = record['carbs'];
    final fat = record['fat'];

    final progress = targetKcal == 0 ? 0.0 : consumedKcal / targetKcal;
    
    return Container(
      margin: EdgeInsets.only(bottom: 3.h),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📅 $date',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1C1E),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: progress >= 0.7 ? const Color(0xFFE8F8EE) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Text(
                  "${(progress * 100).toInt()}% ${'achieved'.tr(context)}",
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: progress >= 0.7 ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('calories_title'.tr(context), style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93))),
                  SizedBox(height: 0.5.h),
                  Text('$consumedKcal / $targetKcal', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
                ],
              ),
              Column(
                children: [
                  Text('protein_title'.tr(context), style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93))),
                  SizedBox(height: 0.5.h),
                  Text('${protein}g', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: const Color(0xFF007AFF))),
                ],
              ),
              Column(
                children: [
                  Text('carbs_title'.tr(context), style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93))),
                  SizedBox(height: 0.5.h),
                  Text('${carbs}g', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: const Color(0xFFFF9500))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('fat_title'.tr(context), style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93))),
                  SizedBox(height: 0.5.h),
                  Text('${fat}g', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: const Color(0xFFFF3B30))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
