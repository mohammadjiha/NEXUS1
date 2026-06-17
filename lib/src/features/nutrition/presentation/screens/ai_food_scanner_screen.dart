import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../domain/models/food_model.dart';
import '../../providers/ai_food_provider.dart';

class AIFoodScannerScreen extends ConsumerStatefulWidget {
  const AIFoodScannerScreen({super.key});

  @override
  ConsumerState<AIFoodScannerScreen> createState() => _AIFoodScannerScreenState();
}

class _AIFoodScannerScreenState extends ConsumerState<AIFoodScannerScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        
        final bytes = await pickedFile.readAsBytes();
        ref.read(aiFoodScanStateProvider.notifier).scanImage(bytes);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'error_picking_image'.tr(context)} $e')));
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(5.w))),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 2.h),
            Text('scan_food_title'.tr(context), style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
            SizedBox(height: 2.h),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1C1C1E)),
              title: Text('take_photo'.tr(context), style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF1C1C1E)),
              title: Text('choose_from_gallery'.tr(context), style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            SizedBox(height: 3.h),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showImageSourceActionSheet(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiFoodScanStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back_ios_new_rounded, size: 16.sp, color: const Color(0xFF1C1C1E)),
        ),
        title: Text(
          'ai_food_scanner_title'.tr(context),
          style: TextStyle(color: const Color(0xFF1C1C1E), fontSize: 16.sp, fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_imageFile == null) ...[
                SizedBox(height: 10.h),
                Center(
                  child: GestureDetector(
                    onTap: () => _showImageSourceActionSheet(context),
                    child: Container(
                      width: 50.w,
                      height: 50.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.w),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_rounded, size: 30.sp, color: const Color(0xFF8E8E93)),
                          SizedBox(height: 2.h),
                          Text('tap_to_scan'.tr(context), style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: 90.w,
                  height: 30.h,
                  margin: EdgeInsets.all(5.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.w),
                    image: DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                  ),
                ),
                aiState.when(
                  data: (data) {
                    if (data == null) {
                      return Center(
                        child: ElevatedButton(
                          onPressed: () => _showImageSourceActionSheet(context),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1C1E)),
                          child: Text('try_again'.tr(context), style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    }
                    if (data.containsKey('error')) {
                      return Padding(
                        padding: EdgeInsets.all(5.w),
                        child: Text(data['error'], style: TextStyle(fontSize: 16.sp, color: const Color(0xFFFF3B30))),
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['food_name'] ?? 'unknown_food'.tr(context), style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E))),
                          SizedBox(height: 1.h),
                          Text("${'estimated_portion'.tr(context)} ${data['estimated_weight_g'] ?? 0}g", style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: const Color(0xFF8E8E93))),
                          SizedBox(height: 3.h),
                          _buildNutritionalTable('total_estimated_values'.tr(context), data['total_estimated'], context),
                          SizedBox(height: 3.h),
                          _buildNutritionalTable('values_per_100g'.tr(context), data['per_100g'], context),
                          SizedBox(height: 4.h),
                          SizedBox(
                            width: double.infinity,
                            height: 6.5.h,
                            child: ElevatedButton(
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                final mealsStr = prefs.getString('custom_meals') ?? '[]';
                                final mealsList = jsonDecode(mealsStr) as List<dynamic>;
                                
                                final foodData = {
                                  'name': data['food_name'] ?? 'scanned_food'.tr(context),
                                  'calories': (data['per_100g']?['calories'] ?? 0).toDouble(),
                                  'protein': (data['per_100g']?['protein_g'] ?? 0).toDouble(),
                                  'carbs': (data['per_100g']?['carbs_g'] ?? 0).toDouble(),
                                  'fat': (data['per_100g']?['fat_g'] ?? 0).toDouble(),
                                  'emoji': '📸',
                                  'tags': ['custom', 'ai_scanned'],
                                  'servingSize': '100g',
                                  'gymScore': 7.5,
                                };
                                mealsList.add(foodData);
                                await prefs.setString('custom_meals', jsonEncode(mealsList));

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('saved_to_custom_meals'.tr(context))));
                                  
                                  final foodModel = FoodModel(
                                    id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
                                    name: foodData['name'] as String,
                                    calories: foodData['calories'] as double,
                                    protein: foodData['protein'] as double,
                                    carbs: foodData['carbs'] as double,
                                    fat: foodData['fat'] as double,
                                    fiber: 0.0,
                                    emoji: foodData['emoji'] as String,
                                    tags: List<String>.from(foodData['tags'] as List),
                                    servingSize: foodData['servingSize'] as String,
                                    gymScore: foodData['gymScore'] as double,
                                  );
                                  
                                  Navigator.pop(context, foodModel);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1C1C1E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
                              ),
                              child: Text('add_to_meal'.tr(context), style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          ),
                          SizedBox(height: 5.h),
                        ],
                      ),
                    );
                  },
                  loading: () => Column(
                    children: [
                      SizedBox(height: 5.h),
                      const CircularProgressIndicator(color: Color(0xFF1C1C1E)),
                      SizedBox(height: 3.h),
                      Text('ai_analyzing_food'.tr(context), style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: const Color(0xFF1C1C1E))),
                    ],
                  ),
                  error: (e, _) => Padding(
                    padding: EdgeInsets.all(5.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 10.w, color: const Color(0xFFFF3B30)),
                        SizedBox(height: 1.5.h),
                        Text(
                          '${'error_colon'.tr(context)} $e',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: const Color(0xFFFF3B30), fontSize: 13.sp),
                        ),
                        SizedBox(height: 2.h),
                        ElevatedButton.icon(
                          onPressed: _imageFile == null
                              ? null
                              : () async {
                                  final bytes = await _imageFile!.readAsBytes();
                                  ref.read(aiFoodScanStateProvider.notifier).scanImage(bytes);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C1C1E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text('retry'.tr(context), style: TextStyle(fontSize: 13.sp)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionalTable(String title, Map<String, dynamic>? macros, BuildContext context) {
    if (macros == null) return const SizedBox();
    return Container(
      padding: EdgeInsets.all(4.w),
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1C1C1E),
            ),
          ),
          SizedBox(height: 1.h),
          ...macros.entries.map((e) {
            final key = e.key.toString().replaceAll('_', ' ');
            final val = e.value;
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 0.4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    key,
                    style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93)),
                  ),
                  Text(
                    val.toString(),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
