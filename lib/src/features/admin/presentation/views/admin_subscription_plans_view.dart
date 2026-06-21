import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../data/admin_repository.dart';

class AdminSubscriptionPlansView extends ConsumerStatefulWidget {
  final String gymId;
  const AdminSubscriptionPlansView({super.key, required this.gymId});

  @override
  ConsumerState<AdminSubscriptionPlansView> createState() =>
      _AdminSubscriptionPlansViewState();
}

class _AdminSubscriptionPlansViewState
    extends ConsumerState<AdminSubscriptionPlansView> {
  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  void _showAddPlanSheet({Map<String, dynamic>? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanFormSheet(
        gymId: widget.gymId,
        adminRepo: _repo,
        existing: existing,
      ),
    );
  }

  Future<void> _deletePlan(String planId, String planName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text('Delete Plan',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700)),
        content: Text('Delete "$planName"? This won\'t affect existing subscriptions.',
            style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFFF3B30)))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.deleteSubscriptionPlan(
          gymId: widget.gymId, planId: planId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Plan deleted'),
              backgroundColor: Color(0xFF1C1C1E)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFF1C1C1E)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync =
        ref.watch(subscriptionPlansProvider(widget.gymId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Subscription Plans',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () => _showAddPlanSheet(),
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded,
                  color: Color(0xFFFF3B30), size: 20),
            ),
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF3B30))),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white54))),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_membership_rounded,
                      color: Colors.white24, size: 32.sp),
                  SizedBox(height: 2.h),
                  Text('No plans yet',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 13.sp)),
                  SizedBox(height: 1.h),
                  Text('Tap + to add your first subscription plan',
                      style: TextStyle(
                          color: Colors.white24, fontSize: 10.sp)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(4.w),
            itemCount: plans.length,
            itemBuilder: (_, i) {
              final plan = plans[i];
              final name = plan['name'] as String? ?? 'Unnamed';
              final days = plan['durationDays'] as int? ?? 30;
              final price = (plan['price'] as num?)?.toDouble() ?? 0.0;
              final planId = plan['id'] as String? ?? '';
              // Smart label: "3 أشهر · 90 يوم"
              final durationLabel =
                  '${_PlanFormSheetState._dayLabel(days)} · $days يوم';

              return Container(
                margin: EdgeInsets.only(bottom: 2.h),
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4.w),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4.w),
                      ),
                      child: const Icon(Icons.card_membership_rounded,
                          color: Color(0xFFFF3B30), size: 30),
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700)),
                          SizedBox(height: 0.4.h),
                          Row(
                            children: [
                              _chip(Icons.calendar_today_rounded,
                                  durationLabel, const Color(0xFF5BA8FF)),
                              SizedBox(width: 2.w),
                              _chip(Icons.attach_money_rounded,
                                  '${price.toStringAsFixed(0)} JD',
                                  const Color(0xFF34C759)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              _showAddPlanSheet(existing: plan),
                          icon: const Icon(Icons.edit_rounded,
                              color: Colors.white38, size: 26),
                        ),
                        IconButton(
                          onPressed: () => _deletePlan(planId, name),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFFF3B30), size: 26),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPlanSheet(),
        backgroundColor: const Color(0xFFFF3B30),
        label: Text('Add Plan',
            style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14.sp),
        SizedBox(width: 1.5.w),
        Text(label,
            style: TextStyle(color: color, fontSize: 13.sp)),
      ],
    );
  }
}

// ─── Plan Form Sheet ──────────────────────────────────────────────────────────

class _PlanFormSheet extends StatefulWidget {
  final String gymId;
  final AdminRepository adminRepo;
  final Map<String, dynamic>? existing;

  const _PlanFormSheet(
      {required this.gymId,
      required this.adminRepo,
      this.existing});

  @override
  State<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends State<_PlanFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  int _days = 30;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!['name'] as String? ?? '';
      _priceCtrl.text =
          '${(widget.existing!['price'] as num?)?.toStringAsFixed(0) ?? '0'}';
      _days = widget.existing!['durationDays'] as int? ?? 30;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Plan name is required'),
            backgroundColor: Color(0xFF1C1C1E)),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      if (widget.existing != null) {
        await widget.adminRepo.updateSubscriptionPlan(
          gymId: widget.gymId,
          planId: widget.existing!['id'] as String,
          name: name,
          durationDays: _days,
          price: price,
        );
      } else {
        await widget.adminRepo.addSubscriptionPlan(
          gymId: widget.gymId,
          name: name,
          durationDays: _days,
          price: price,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFF1C1C1E)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Quick-pick durations ─────────────────────────────────────────────────
  static const _quickDays = [7, 14, 30, 60, 90, 120, 365];

  /// Human-readable Arabic label for a day count.
  static String _dayLabel(int d) {
    switch (d) {
      case 7:   return '7 أيام';
      case 14:  return 'أسبوعين';
      case 30:  return 'شهر';
      case 60:  return 'شهرين';
      case 90:  return '3 أشهر';
      case 120: return '4 أشهر';
      case 365: return 'سنة';
      default:
        if (d % 30 == 0) return '${d ~/ 30} أشهر';
        return '$d يوم';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 12.w,
                height: 4,
                margin: EdgeInsets.only(bottom: 2.h),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text(isEdit ? 'Edit Plan' : 'New Plan',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 2.5.h),
            _label('اسم الخطة'),
            SizedBox(height: 1.h),
            _field(_nameCtrl, 'مثال: خطة شهرية', TextInputType.text),
            SizedBox(height: 2.h),
            _label('السعر (JD)'),
            SizedBox(height: 1.h),
            _field(_priceCtrl, '0.00', TextInputType.number),
            SizedBox(height: 2.h),
            _label('المدة'),
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: _quickDays.map((d) {
                final selected = _days == d;
                final label = _dayLabel(d);
                // Show day count as sub-text when the label doesn't include it
                final showDays = d != 7 && d != 14;
                return GestureDetector(
                  onTap: () => setState(() => _days = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(
                        horizontal: 4.5.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFF3B30)
                          : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? const Color(0xFFFF3B30)
                              : Colors.white24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500),
                        ),
                        if (showDays)
                          Text(
                            '$d يوم',
                            style: TextStyle(
                                color: selected
                                    ? Colors.white70
                                    : Colors.white38,
                                fontSize: 12.sp),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              height: 7.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w)),
                ),
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(isEdit ? 'حفظ التغييرات' : 'إنشاء الخطة',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: Colors.white60,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600));

  Widget _field(
      TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: TextStyle(color: Colors.white, fontSize: 16.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3.w),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      ),
    );
  }
}
