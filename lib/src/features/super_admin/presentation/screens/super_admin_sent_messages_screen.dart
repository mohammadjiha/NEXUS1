import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../data/super_admin_service.dart';

class SuperAdminSentMessagesScreen extends ConsumerStatefulWidget {
  const SuperAdminSentMessagesScreen({super.key});

  @override
  ConsumerState<SuperAdminSentMessagesScreen> createState() =>
      _SuperAdminSentMessagesScreenState();
}

class _SuperAdminSentMessagesScreenState
    extends ConsumerState<SuperAdminSentMessagesScreen> {
  String _typeFilter = 'all';
  String _gymFilter = 'all';
  String _search = '';

  static const _types = ['all', 'info', 'warning', 'alert', 'update'];

  @override
  Widget build(BuildContext context) {
    final sentAsync = ref.watch(superAdminSentMessagesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(context),
            _buildFilters(sentAsync),
            Expanded(child: _buildTable(sentAsync)),
          ],
        ),
      ),
    );
  }

  // ── Topbar ────────────────────────────────────────────────────────────────

  Widget _buildTopbar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 9.w,
              height: 9.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 12.sp),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الرسائل المرسلة',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'كل الرسائل التي أرسلها Super Admin للأندية',
                  style: TextStyle(
                      fontSize: 9.sp, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => ref.invalidate(superAdminSentMessagesProvider),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.15),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded,
                      color: const Color(0xFFFF3B30), size: 12.sp),
                  SizedBox(width: 1.w),
                  Text(
                    'تحديث',
                    style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF3B30)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  Widget _buildFilters(AsyncValue<List<Map<String, dynamic>>> sentAsync) {
    // Collect unique gyms from loaded data
    final gyms = <String>{'all'};
    if (sentAsync is AsyncData<List<Map<String, dynamic>>>) {
      for (final m in sentAsync.value) {
        final g = m['gymName'] as String? ?? '';
        if (g.isNotEmpty) gyms.add(g);
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 1.h),
      child: Row(
        children: [
          // Type filter
          _buildDropdown(
            value: _typeFilter,
            items: _types,
            label: (v) => v == 'all' ? 'كل الأنواع' : v,
            onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
          ),
          SizedBox(width: 2.w),
          // Gym filter
          _buildDropdown(
            value: _gymFilter,
            items: gyms.toList(),
            label: (v) => v == 'all' ? 'كل الأندية' : v,
            onChanged: (v) => setState(() => _gymFilter = v ?? 'all'),
          ),
          SizedBox(width: 2.w),
          // Search
          Expanded(
            child: Container(
              height: 5.h,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(2.w),
                border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                style:
                    TextStyle(color: Colors.white, fontSize: 10.sp),
                onChanged: (v) => setState(() => _search = v.trim()),
                decoration: InputDecoration(
                  hintText: 'ابحث بالعنوان...',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10.sp),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 3.w, vertical: 0),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Colors.white38, size: 12.sp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String Function(String) label,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: 5.h,
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(2.w),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: const Color(0xFF1C1C1E),
          style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white54, size: 12.sp),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(label(e)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> all) {
    return all.where((m) {
      if (_typeFilter != 'all' && m['type'] != _typeFilter) return false;
      if (_gymFilter != 'all' && m['gymName'] != _gymFilter) return false;
      if (_search.isNotEmpty) {
        final title = (m['title'] as String? ?? '').toLowerCase();
        if (!title.contains(_search.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildTable(AsyncValue<List<Map<String, dynamic>>> sentAsync) {
    return sentAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF3B30))),
      error: (e, _) => Center(
        child: Text(
          'خطأ: $e',
          style: TextStyle(color: const Color(0xFFFF3B30), fontSize: 11.sp),
        ),
      ),
      data: (all) {
        final rows = _applyFilters(all);

        return Column(
          children: [
            // Header row
            Container(
              color: Colors.white.withOpacity(0.04),
              padding: EdgeInsets.symmetric(
                  horizontal: 4.w, vertical: 1.h),
              child: Row(
                children: [
                  _headerCell('العنوان', flex: 3),
                  _headerCell('النادي', flex: 2),
                  _headerCell('النوع', flex: 1),
                  _headerCell('النص', flex: 3),
                  _headerCell('قُرئت؟', flex: 1),
                  _headerCell('التاريخ', flex: 2),
                ],
              ),
            ),
            // Data rows
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد رسائل',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 11.sp),
                      ),
                    )
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _buildRow(rows[i], i),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.4),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> m, int index) {
    final ts = m['sentAt'] as Timestamp?;
    final dateStr = ts != null
        ? DateFormat('MMM d\nHH:mm').format(ts.toDate())
        : '—';
    final isRead = m['read'] as bool? ?? false;
    final type = m['type'] as String? ?? '';
    final typeColor = _typeColor(type);

    return Container(
      decoration: BoxDecoration(
        color: index.isEven
            ? Colors.transparent
            : Colors.white.withOpacity(0.02),
        border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      padding:
          EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      child: Row(
        children: [
          // Title
          Expanded(
            flex: 3,
            child: Text(
              m['title'] as String? ?? '—',
              style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Gym
          Expanded(
            flex: 2,
            child: Text(
              m['gymName'] as String? ?? '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9.sp, color: Colors.white.withOpacity(0.6)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Type
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 1.5.w, vertical: 0.3.h),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(1.w),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                      fontSize: 7.5.sp,
                      fontWeight: FontWeight.w700,
                      color: typeColor),
                ),
              ),
            ),
          ),
          // Body
          Expanded(
            flex: 3,
            child: Text(
              m['body'] as String? ?? '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 9.sp,
                  color: Colors.white.withOpacity(0.45)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Read
          Expanded(
            flex: 1,
            child: Center(
              child: Icon(
                isRead
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isRead
                    ? const Color(0xFF34C759)
                    : Colors.white24,
                size: 12.sp,
              ),
            ),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              dateStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 8.sp,
                  color: Colors.white.withOpacity(0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'warning':
        return const Color(0xFFFF9500);
      case 'alert':
        return const Color(0xFFFF3B30);
      case 'update':
        return const Color(0xFF5BA8FF);
      case 'info':
      default:
        return const Color(0xFF34C759);
    }
  }
}
