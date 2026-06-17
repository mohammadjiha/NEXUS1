import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:uuid/uuid.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../domain/models/supplement_model.dart';
import '../../providers/supplements_provider.dart';
import '../../data/supplements_repository.dart';

class SupplementsTrackerScreen extends ConsumerStatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const SupplementsTrackerScreen({super.key, required this.navigatorKey});

  @override
  ConsumerState<SupplementsTrackerScreen> createState() => _SupplementsTrackerScreenState();
}

class _SupplementsTrackerScreenState extends ConsumerState<SupplementsTrackerScreen> {
  late String _todayDateStr;

  @override
  void initState() {
    super.initState();
    _todayDateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supplementsRepositoryProvider).setupDefaultSupplementsIfNeeded();
    });
  }

  void _showAddEditSheet({SupplementItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(5.w))),
      builder: (ctx) => _AddSupplementSheet(
        initialItem: item,
        onSave: (newItem) async {
          await ref.read(supplementsRepositoryProvider).saveSupplement(newItem);
        },
        onDelete: item == null ? null : () async {
          await ref.read(supplementsRepositoryProvider).deleteSupplement(item.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(supplementsRoutineProvider);
    final historyAsync = ref.watch(supplementDailyLogProvider(_todayDateStr));

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
          'supplements'.tr(context),
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
            onTap: () => _showAddEditSheet(),
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: 4.w),
              child: Icon(Icons.add_rounded, color: const Color(0xFF1C1C1E), size: 20.sp),
            ),
          ),
        ],
      ),
      body: routineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (routine) {
          if (routine.isEmpty) {
            return Center(
              child: Text(
                'no_supplements_added'.tr(context),
                style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 14.sp),
              ),
            );
          }

          final log = historyAsync.asData?.value;
          final takenIds = log?.takenIds ?? [];

          final grouped = <SupplementTiming, List<SupplementItem>>{};
          for (var item in routine) {
            grouped.putIfAbsent(item.timing, () => []).add(item);
          }

          final takenNames = routine.where((s) => takenIds.contains(s.id)).map((s) => s.name).toList();
          final summaryText = takenNames.isEmpty 
              ? 'no_supplements_taken_today'.tr(context) 
              : '${'today_you_took'.tr(context)}: ${takenNames.join(', ')}';

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5FF),
                      borderRadius: BorderRadius.circular(3.w),
                      border: Border.all(color: const Color(0xFFB9E0FF)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: const Color(0xFF007AFF), size: 18.sp),
                        SizedBox(width: 3.w),
                        Expanded(
                          child: Text(
                            summaryText,
                            style: TextStyle(
                              color: const Color(0xFF007AFF),
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  ...SupplementTiming.values.map((timing) {
                    final items = grouped[timing];
                    if (items == null || items.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(timing.translationKey.tr(context)),
                        _buildSuppList(items.map((item) {
                          return _buildSuppRow(item, takenIds.contains(item.id));
                        }).toList()),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 1.h),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF8E8E93),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSuppList(List<Widget> children) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSuppRow(SupplementItem item, bool isDone) {
    return GestureDetector(
      onTap: () {
        ref.read(supplementsRepositoryProvider).toggleSupplement(_todayDateStr, item.id, !isDone);
      },
      onLongPress: () => _showAddEditSheet(item: item),
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.all(3.5.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3.5.w),
          border: Border.all(color: isDone ? const Color(0xFF34C759) : const Color(0xFFE5E5EA), width: isDone ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 11.w, height: 11.w,
              decoration: BoxDecoration(color: Color(item.iconBgColor), borderRadius: BorderRadius.circular(2.w)),
              alignment: Alignment.center,
              child: Text(item.emoji, style: TextStyle(fontSize: 22.sp)),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: const Color(0xFF1C1C1E))),
                  SizedBox(height: 0.2.h),
                  Text(item.details, style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93))),
                ],
              ),
            ),
            SizedBox(width: 3.w),
            Container(
              width: 8.w, height: 8.w,
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF34C759) : const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(2.5.w),
                border: isDone ? null : Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
              ),
              alignment: Alignment.center,
              child: isDone ? Icon(Icons.check_rounded, color: Colors.white, size: 16.sp) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSupplementSheet extends StatefulWidget {
  final SupplementItem? initialItem;
  final Function(SupplementItem) onSave;
  final Function()? onDelete;

  const _AddSupplementSheet({this.initialItem, required this.onSave, this.onDelete});

  @override
  State<_AddSupplementSheet> createState() => _AddSupplementSheetState();
}

class _AddSupplementSheetState extends State<_AddSupplementSheet> {
  final _nameCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  SupplementTiming _timing = SupplementTiming.morning;

  final List<String> _presetEmojis = ['ðŸ’Š', 'ðŸŒ…', 'ðŸŸ', 'âš¡', 'â˜•', 'ðŸ¥›', 'ðŸŒ™', 'ðŸ’¤', 'ðŸ', 'ðŸ¥‘', 'ðŸ’ª', 'ðŸ”¥'];

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _nameCtrl.text = widget.initialItem!.name;
      _detailsCtrl.text = widget.initialItem!.details;
      _emojiCtrl.text = widget.initialItem!.emoji;
      _timing = widget.initialItem!.timing;
    } else {
      _emojiCtrl.text = 'ðŸ’Š';
    }
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) return;
    
    final item = SupplementItem(
      id: widget.initialItem?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      details: _detailsCtrl.text.trim(),
      timing: _timing,
      emoji: _emojiCtrl.text.trim().isEmpty ? 'ðŸ’Š' : _emojiCtrl.text.trim(),
      iconBgColor: widget.initialItem?.iconBgColor ?? 0xFFE8F5FF,
    );
    
    widget.onSave(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 5.w, right: 5.w, top: 3.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialItem == null ? 'add_supplement'.tr(context) : 'edit_supplement'.tr(context),
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: const Color(0xFF1C1C1E)),
                ),
                if (widget.onDelete != null)
                  GestureDetector(
                    onTap: () {
                      widget.onDelete!();
                      Navigator.pop(context);
                    },
                    child: Icon(Icons.delete_outline_rounded, color: const Color(0xFFE53935), size: 20.sp),
                  ),
              ],
            ),
            SizedBox(height: 3.h),

            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'supplement_name'.tr(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(2.w)),
              ),
            ),
            SizedBox(height: 2.h),

            TextField(
              controller: _detailsCtrl,
              decoration: InputDecoration(
                labelText: 'dosage_details'.tr(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(2.w)),
              ),
            ),
            SizedBox(height: 2.h),

            DropdownButtonFormField<SupplementTiming>(
              initialValue: _timing,
              decoration: InputDecoration(
                labelText: 'timing'.tr(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(2.w)),
              ),
              items: SupplementTiming.values.map((t) => DropdownMenuItem(
                value: t,
                child: Text(t.translationKey.tr(context)),
              )).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _timing = val);
              },
            ),
            SizedBox(height: 3.h),

            Text('select_or_type_emoji'.tr(context), style: TextStyle(fontSize: 12.sp, color: const Color(0xFF8E8E93))),
            SizedBox(height: 1.h),
            
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: _presetEmojis.map((e) {
                return GestureDetector(
                  onTap: () => setState(() => _emojiCtrl.text = e),
                  child: Container(
                    padding: EdgeInsets.all(2.w),
                    decoration: BoxDecoration(
                      color: _emojiCtrl.text == e ? const Color(0xFFE8F5FF) : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(2.w),
                      border: Border.all(color: _emojiCtrl.text == e ? const Color(0xFF007AFF) : Colors.transparent),
                    ),
                    child: Text(e, style: TextStyle(fontSize: 20.sp)),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 2.h),

            TextField(
              controller: _emojiCtrl,
              decoration: InputDecoration(
                labelText: 'custom_emoji'.tr(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(2.w)),
              ),
              onChanged: (val) => setState(() {}),
            ),
            SizedBox(height: 4.h),

            SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2.w)),
                ),
                child: Text('save'.tr(context), style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 3.h),
          ],
        ),
      ),
    );
  }
}

