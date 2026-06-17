import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/providers/locale_provider.dart';
import '../../data/food_repository.dart';
import '../../domain/models/food_model.dart';
import 'ai_food_scanner_screen.dart';

class FoodSearchScreen extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const FoodSearchScreen({super.key, required this.navigatorKey});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

enum SortOption { none, caloriesLowToHigh, caloriesHighToLow }

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<FoodModel> _searchResults = [];
  SortOption _sortOption = SortOption.none;

  List<FoodModel> get _sortedResults {
    if (_sortOption == SortOption.none) return _searchResults;
    final list = List<FoodModel>.from(_searchResults);
    if (_sortOption == SortOption.caloriesLowToHigh) {
      list.sort((a, b) => a.calories.compareTo(b.calories));
    } else {
      list.sort((a, b) => b.calories.compareTo(a.calories));
    }
    return list;
  }

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  FoodPage? _lastPage;
  String? _errorMessage;
  int _searchRun = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    Future.microtask(_loadTopPicks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 450) {
      _loadMore();
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _loadTopPicks();
      return;
    }

    _searchFoods(query);
  }

  Future<void> _loadTopPicks() async {
    final run = ++_searchRun;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _lastPage = null;
      _errorMessage = null;
    });
    try {
      final page = await ref.read(foodRepositoryProvider).topPicks();
      if (!mounted || run != _searchRun) return;
      setState(() {
        _searchResults = page.foods;
        _lastPage = page;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || run != _searchRun) return;
      setState(() {
        _errorMessage = 'error_load_foods_firebase'.tr(context);
        _isLoading = false;
      });
    }
  }

  Future<void> _searchFoods(String query) async {
    final run = ++_searchRun;
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _hasMore = true;
      _lastPage = null;
      _errorMessage = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted || run != _searchRun) return;

    try {
      final page = await ref
          .read(foodRepositoryProvider)
          .search(query);
      if (!mounted || run != _searchRun) return;
      setState(() {
        _searchResults = page.foods;
        _lastPage = page;
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || run != _searchRun) return;
      setState(() {
        _errorMessage = 'error_search_failed_firebase'.tr(context);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final lastDocument = _lastPage?.lastDocument;
    if (lastDocument == null) return;

    final run = _searchRun;
    setState(() => _isLoadingMore = true);
    try {
      final query = _searchController.text.trim();
      final page = query.isEmpty
          ? await ref
                .read(foodRepositoryProvider)
                .topPicks(startAfter: lastDocument)
          : await ref
                .read(foodRepositoryProvider)
                .search(query, startAfter: lastDocument);
      if (!mounted || run != _searchRun) return;
      setState(() {
        _searchResults = [..._searchResults, ...page.foods];
        _lastPage = page;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || run != _searchRun) return;
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
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
          onTap: () => widget.navigatorKey.currentState!.pop(),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16.sp,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        title: Text(
          'food_search'.tr(context),
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
            onTap: () => _showSortBottomSheet(context),
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 4.w),
              child: Icon(
                Icons.tune_rounded,
                color: const Color(0xFF1C1C1E),
                size: 20.sp,
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIFoodScannerScreen()),
              );
              if (result != null && mounted) {
                // We assume result is a FoodModel or similar that can be passed to food_detail
                widget.navigatorKey.currentState!.pushNamed(
                  '/food_detail',
                  arguments: result,
                );
              }
            },
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 4.w),
              child: Icon(
                Icons.center_focus_strong_rounded,
                color: const Color(0xFF1C1C1E),
                size: 20.sp,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBox(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(6.w),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    )
                  : _sortedResults.isEmpty
                  ? Center(
                      child: Text(
                        'no_foods_found_try_another'.tr(context),
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(bottom: 10.h),
                      itemCount:
                          _sortedResults.length + 1 + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.5.h),
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'high_gym_score_top_picks'.tr(context)
                                  : 'search_results'.tr(context),
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF8E8E93),
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        }

                        if (_isLoadingMore &&
                            index == _sortedResults.length + 1) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final food = _sortedResults[index - 1];
                        return _buildFoodCard(food, context);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: const Color(0xFF8E8E93),
            size: 22.sp,
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Directionality(
              // Auto-flip text direction as user types Arabic/English
              textDirection:
                  FoodRepository.isArabicQuery(_searchController.text)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: const Color(0xFF1C1C1E),
                ),
                decoration: InputDecoration(
                  hintText: 'search_food_brand_scan'.tr(context),
                  hintStyle: TextStyle(
                    color: const Color(0xFFC7C7CC),
                    fontSize: 16.sp,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(FoodModel food, BuildContext context) {
    final locale = ref.read(localeProvider).languageCode;
    final displayName = food.localizedName(locale);

    Color scoreColor;
    Color scoreBg;
    String scoreSuffix;

    if (food.gymScore >= 9.0) {
      scoreColor = const Color(0xFF1A7A30);
      scoreBg = const Color(0xFFE8FFF0);
      scoreSuffix = ' 🏆';
    } else if (food.gymScore >= 7.0) {
      scoreColor = const Color(0xFF007AFF);
      scoreBg = const Color(0xFFE8F5FF);
      scoreSuffix = ' ✓';
    } else {
      scoreColor = const Color(0xFFC0392B);
      scoreBg = const Color(0xFFFFF0F0);
      scoreSuffix = ' ❌';
    }

    // Determine primary tag if available, or just use serving size and protein
    String subtitle =
        "${food.servingSize}${'gym_score_separator'.tr(context)}${food.gymScore}";
    if (food.protein > 10) {
      subtitle =
          "${food.servingSize}${'high_protein_gym_score'.tr(context)}${food.gymScore}";
    } else if (food.tags.contains('cheat')) {
      subtitle =
          "${food.servingSize}${'not_recommended_gym_score'.tr(context)}${food.gymScore}";
    } else if (food.carbs > 20) {
      subtitle =
          "${food.servingSize}${'high_carbs_gym_score'.tr(context)}${food.gymScore}";
    }

    return GestureDetector(
      onTap: () => widget.navigatorKey.currentState!.pushNamed(
        '/food_detail',
        arguments: food,
      ),
      child: Container(
        margin: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.h),
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        ),
        child: Row(
          children: [
            Text(food.emoji, style: TextStyle(fontSize: 29.sp)),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 0.2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${food.calories.toInt()} kcal',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 3.w,
                    vertical: 0.8.h,
                  ),
                  decoration: BoxDecoration(
                    color: scoreBg,
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Text(
                    '${food.gymScore}$scoreSuffix',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 3.w),
            GestureDetector(
              onTap: () => _showAdded(food, context),
              child: Container(
                width: 8.5.w,
                height: 8.5.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(2.2.w),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add, color: Colors.white, size: 17.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdded(FoodModel food, BuildContext context) {
    final locale = ref.read(localeProvider).languageCode;
    final displayName = food.localizedName(locale);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$displayName${'added'.tr(context)}')),
    );
  }

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6.w)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 12.w,
                    height: 0.6.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(1.w),
                    ),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  'sort_by'.tr(context),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
                SizedBox(height: 3.h),
                _buildSortOption('sort_default'.tr(context), SortOption.none),
                _buildSortOption(
                  'sort_calories_low_high'.tr(context),
                  SortOption.caloriesLowToHigh,
                ),
                _buildSortOption(
                  'sort_calories_high_low'.tr(context),
                  SortOption.caloriesHighToLow,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String title, SortOption option) {
    final isSelected = _sortOption == option;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFF8E8E93),
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_rounded,
              color: const Color(0xFF1C1C1E),
              size: 20.sp,
            )
          : null,
      onTap: () {
        setState(() => _sortOption = option);
        Navigator.pop(context);
      },
    );
  }
}
