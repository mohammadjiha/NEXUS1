import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_preferences_provider.dart';
import '../../domain/models/diet_template_model.dart';
import '../../domain/models/food_model.dart';
import 'ai_coach_plan_screen.dart';
import 'build_my_own_screen.dart';
import 'coach_plan_screen.dart';
import 'daily_meal_plan_screen.dart';
import 'food_detail_screen.dart';
import 'food_search_screen.dart';
import 'meal_timing_screen.dart';
import 'nutrition_source_selection_screen.dart';
import 'supplements_tracker_screen.dart';
import 'templates_screen.dart';

class NutritionFlowCoordinator extends ConsumerStatefulWidget {
  const NutritionFlowCoordinator({super.key});

  @override
  ConsumerState<NutritionFlowCoordinator> createState() =>
      _NutritionFlowCoordinatorState();
}

class _NutritionFlowCoordinatorState extends ConsumerState<NutritionFlowCoordinator> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  String? _initialRoute;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    // We can't read ref synchronously if we want to ensure it's fully loaded, but sharedPreferencesProvider is synchronous after app launch.
    final prefs = ref.read(sharedPreferencesProvider);
    final hasActiveTemplate = prefs.getString('nutrition_active_template_json') != null;
    if (hasActiveTemplate) {
      _initialRoute = '/daily_meal_plan';
    } else {
      _initialRoute = prefs.getString('nutrition_last_flow_path');
    }
    _isInit = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) return const SizedBox();
    
    return Navigator(
      key: _navigatorKey,
      initialRoute: _initialRoute ?? '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = NutritionSourceSelectionScreen(navigatorKey: _navigatorKey);
            break;
          case '/daily_meal_plan':
            final prefs = ref.read(sharedPreferencesProvider);
            final jsonStr = prefs.getString('nutrition_active_template_json');
            if (jsonStr != null) {
              try {
                final template = DietTemplateModel.fromJson(jsonDecode(jsonStr));
                page = DailyMealPlanScreen(template: template);
              } catch (e) {
                page = NutritionSourceSelectionScreen(navigatorKey: _navigatorKey);
              }
            } else {
              page = NutritionSourceSelectionScreen(navigatorKey: _navigatorKey);
            }
            break;
          case '/ai_coach':
            page = AiCoachPlanScreen(navigatorKey: _navigatorKey);
            break;
          case '/coach_plan':
            page = CoachPlanScreen(navigatorKey: _navigatorKey);
            break;
          case '/templates':
            final forceManual = settings.arguments as bool? ?? false;
            final isFromMemory = !forceManual && settings.name == _initialRoute;
            page = TemplatesScreen(navigatorKey: _navigatorKey, autoLoad: isFromMemory);
            break;
          case '/build_own':
            // Pass a flag to indicate if we are starting directly from memory
            final args = settings.arguments;
            int initialStep = 1;
            bool forceManual = false;
            if (args is bool) {
              forceManual = args;
            } else if (args is Map) {
              initialStep = args['initialStep'] ?? 1;
              forceManual = args['forceManual'] ?? false;
            }
            final isFromMemory = !forceManual && settings.name == _initialRoute;
            page = BuildMyOwnScreen(navigatorKey: _navigatorKey, autoLoad: isFromMemory, initialStep: initialStep);
            break;
          case '/food_search':
            page = FoodSearchScreen(navigatorKey: _navigatorKey);
            break;
          case '/food_detail':
            final food = settings.arguments as FoodModel?;
            page = food == null
                ? FoodSearchScreen(navigatorKey: _navigatorKey)
                : FoodDetailScreen(navigatorKey: _navigatorKey, food: food);
            break;
          case '/meal_timing':
            page = MealTimingScreen(navigatorKey: _navigatorKey);
            break;
          case '/supplements':
            page = SupplementsTrackerScreen(navigatorKey: _navigatorKey);
            break;
          default:
            page = NutritionSourceSelectionScreen(navigatorKey: _navigatorKey);
        }
        return MaterialPageRoute<dynamic>(
          builder: (context) => page,
          settings: settings,
        );
      },
    );
  }
}
