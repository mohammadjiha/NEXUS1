import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/diet_template_model.dart';

final dietTemplatesProvider = FutureProvider<List<DietTemplateModel>>((ref) async {
  try {
    final String content = await rootBundle.loadString('assets/90_detailed_diet_plans.json');
    if (content.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(content);
    
    final allTemplates = jsonList
        .map((json) => DietTemplateModel.fromJson(json as Map<String, dynamic>))
        .toList();

    return allTemplates;
  } catch (e) {
    debugPrint('Error fetching local diet templates: $e');
    return [];
  }
});
