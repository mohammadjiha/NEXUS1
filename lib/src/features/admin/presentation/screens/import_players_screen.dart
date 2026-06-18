import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/admin_repository.dart';

// ─── Data model for one parsed row ────────────────────────────────────────────

class _PlayerRow {
  String firstName;
  String lastName;
  String email;
  String phone;
  String subscriptionPlan;
  DateTime? subscriptionStart;
  DateTime? subscriptionEnd;
  double totalAmount;
  double amountPaid;

  _PlayerRow({
    required this.firstName,
    required this.lastName,
    this.email = '',
    this.phone = '',
    this.subscriptionPlan = 'standard',
    this.subscriptionStart,
    this.subscriptionEnd,
    this.totalAmount = 0,
    this.amountPaid = 0,
  });
}

// ─── Result after import ──────────────────────────────────────────────────────

class _ImportResult {
  final String name;
  final String email;
  final String password;
  final bool success;
  final String? error;

  const _ImportResult({
    required this.name,
    required this.email,
    required this.password,
    required this.success,
    this.error,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ImportPlayersScreen extends ConsumerStatefulWidget {
  /// If provided (Super Admin path), players are imported into this gym.
  /// If null, falls back to the current admin's own gymId.
  final String? overrideGymId;

  const ImportPlayersScreen({super.key, this.overrideGymId});

  @override
  ConsumerState<ImportPlayersScreen> createState() =>
      _ImportPlayersScreenState();
}

class _ImportPlayersScreenState extends ConsumerState<ImportPlayersScreen> {
  List<_PlayerRow> _preview = [];
  bool _isParsing   = false;
  bool _isImporting = false;
  int  _importedCount = 0;
  String? _fileName;

  // ── File picking & parsing ─────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _isParsing = true;
      _fileName  = file.name;
      _preview   = [];
    });

    try {
      _preview = _parseCsv(String.fromCharCodes(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في قراءة الملف: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  List<_PlayerRow> _parseCsv(String content) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return [];

    List<String> splitRow(String line) =>
        line.split(',').map((c) => c.trim().replaceAll('"', '')).toList();

    final headers = splitRow(lines.first).map((h) => h.toLowerCase()).toList();

    int col(List<String> names) {
      for (final n in names) {
        final i = headers.indexWhere((h) => h.contains(n));
        if (i >= 0) return i;
      }
      return -1;
    }

    final iFirst = col(['first', 'fname']);
    final iLast  = col(['last', 'lname']);
    final iName  = col(['name', 'player', 'الاسم']);
    final iEmail = col(['email', 'ايميل']);
    final iPhone = col(['phone', 'جوال', 'mobile']);
    final iPlan  = col(['plan', 'خطة']);
    final iStart = col(['start', 'بداية']);
    final iEnd   = col(['end', 'نهاية', 'انتهاء']);
    final iTotal = col(['total', 'إجمالي']);
    final iPaid  = col(['paid', 'مدفوع']);

    String c(List<String> row, int idx) =>
        (idx >= 0 && idx < row.length) ? row[idx] : '';

    final result = <_PlayerRow>[];
    for (final line in lines.skip(1)) {
      final row = splitRow(line);
      String first = '', last = '';
      if (iFirst >= 0) {
        first = c(row, iFirst);
        last  = c(row, iLast);
      } else if (iName >= 0) {
        final parts = c(row, iName).split(' ');
        first = parts.first;
        last  = parts.length > 1 ? parts.skip(1).join(' ') : '';
      }
      if (first.isEmpty) continue;

      result.add(_PlayerRow(
        firstName:         first,
        lastName:          last,
        email:             c(row, iEmail),
        phone:             c(row, iPhone),
        subscriptionPlan:  c(row, iPlan).isEmpty ? 'standard' : c(row, iPlan),
        subscriptionStart: _parseDate(c(row, iStart)),
        subscriptionEnd:   _parseDate(c(row, iEnd)),
        totalAmount:       double.tryParse(c(row, iTotal)) ?? 0,
        amountPaid:        double.tryParse(c(row, iPaid))  ?? 0,
      ));
    }
    return result;
  }

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    for (final fmt in [
      'dd/MM/yyyy', 'yyyy-MM-dd', 'MM/dd/yyyy', 'd/M/yyyy',
    ]) {
      try {
        return DateFormat(fmt).parse(s);
      } catch (_) {}
    }
    return null;
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _startImport() async {
    final user = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) return;
    final gymId = widget.overrideGymId ?? user.gymId ?? '';
    final adminUid = user.uid;

    setState(() {
      _isImporting   = true;
      _importedCount = 0;
    });

    final results = <_ImportResult>[];
    final repo = ref.read(adminRepositoryProvider);

    for (final row in _preview) {
      try {
        final res = await repo.importPlayer(
          gymId:             gymId,
          addedByUid:        adminUid,
          firstName:         row.firstName,
          lastName:          row.lastName,
          email:             row.email.isEmpty ? null : row.email,
          phone:             row.phone.isEmpty ? null : row.phone,
          subscriptionPlan:  row.subscriptionPlan,
          subscriptionStart: row.subscriptionStart,
          subscriptionEnd:   row.subscriptionEnd,
          totalAmount:       row.totalAmount,
          amountPaid:        row.amountPaid,
        );
        results.add(_ImportResult(
          name:     '${row.firstName} ${row.lastName}'.trim(),
          email:    res['email']!,
          password: res['password']!,
          success:  true,
        ));
      } catch (e) {
        results.add(_ImportResult(
          name:     '${row.firstName} ${row.lastName}'.trim(),
          email:    row.email,
          password: '',
          success:  false,
          error:    e.toString(),
        ));
      }
      if (mounted) setState(() => _importedCount++);
    }

    if (mounted) {
      setState(() => _isImporting = false);
      _showResults(results);
    }
  }

  // ── Results dialog ────────────────────────────────────────────────────────

  void _showResults(List<_ImportResult> results) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultsSheet(results: results),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(),
            Expanded(
              child: _isParsing
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFF3B30)))
                  : _preview.isEmpty
                      ? _buildEmpty()
                      : _buildPreview(),
            ),
            if (_preview.isNotEmpty) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopbar() {
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
                Text('استيراد لاعبين',
                    style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                if (_fileName != null)
                  Text(_fileName!,
                      style: TextStyle(
                          fontSize: 9.sp,
                          color: Colors.white.withOpacity(0.4))),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isImporting ? null : _pickFile,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.15),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Row(
                children: [
                  Icon(Icons.upload_file_rounded,
                      color: const Color(0xFFFF3B30), size: 12.sp),
                  SizedBox(width: 1.5.w),
                  Text('رفع ملف',
                      style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF3B30))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📂', style: TextStyle(fontSize: 48.sp)),
          SizedBox(height: 2.h),
          Text('ارفع ملف CSV',
              style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Text(
              'لو عندك Excel، صدّره كـ CSV أولاً\nالأعمدة المدعومة:\nname / first+last / email / phone / plan / start / end / total / paid',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.sp, color: Colors.white38),
            ),
          ),
          SizedBox(height: 3.h),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Text('اختر ملف',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        // Count strip
        Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: const Color(0xFF34C759).withOpacity(0.1),
            borderRadius: BorderRadius.circular(2.w),
            border: Border.all(
                color: const Color(0xFF34C759).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: const Color(0xFF34C759), size: 12.sp),
              SizedBox(width: 2.w),
              Text(
                'تم قراءة ${_preview.length} لاعب من الملف',
                style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF34C759)),
              ),
            ],
          ),
        ),
        // Header row
        Container(
          color: Colors.white.withOpacity(0.05),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
          child: Row(
            children: [
              _hCell('الاسم', flex: 3),
              _hCell('الجوال', flex: 2),
              _hCell('الخطة', flex: 2),
              _hCell('البداية', flex: 2),
              _hCell('النهاية', flex: 2),
              _hCell('الإجمالي', flex: 2),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _preview.length,
            itemBuilder: (_, i) {
              final r = _preview[i];
              final startStr = r.subscriptionStart != null
                  ? DateFormat('dd/MM/yy').format(r.subscriptionStart!)
                  : '—';
              final endStr = r.subscriptionEnd != null
                  ? DateFormat('dd/MM/yy').format(r.subscriptionEnd!)
                  : '—';
              return Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: i.isEven
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.02),
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withOpacity(0.04))),
                ),
                child: Row(
                  children: [
                    _dCell('${r.firstName} ${r.lastName}'.trim(),
                        flex: 3, bold: true),
                    _dCell(r.phone.isEmpty ? '—' : r.phone, flex: 2),
                    _dCell(r.subscriptionPlan, flex: 2),
                    _dCell(startStr, flex: 2),
                    _dCell(endStr, flex: 2),
                    _dCell(r.totalAmount == 0
                        ? '—'
                        : '${r.totalAmount.toStringAsFixed(0)} JD', flex: 2),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _hCell(String t, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(t,
            style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white38)),
      );

  Widget _dCell(String t, {int flex = 1, bool bold = false}) => Expanded(
        flex: flex,
        child: Text(t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 9.sp,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w400,
                color: bold ? Colors.white : Colors.white60)),
      );

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: _isImporting
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'جاري الاستيراد... $_importedCount / ${_preview.length}',
                  style: TextStyle(
                      fontSize: 11.sp, color: Colors.white54),
                ),
                SizedBox(height: 1.h),
                LinearProgressIndicator(
                  value: _preview.isEmpty
                      ? 0
                      : _importedCount / _preview.length,
                  color: const Color(0xFFFF3B30),
                  backgroundColor: Colors.white12,
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              height: 6.h,
              child: ElevatedButton(
                onPressed: _startImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w)),
                ),
                child: Text(
                  'استيراد ${_preview.length} لاعب',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ),
    );
  }
}

// ─── Results Bottom Sheet ──────────────────────────────────────────────────────

class _ResultsSheet extends StatelessWidget {
  final List<_ImportResult> results;
  const _ResultsSheet({required this.results});

  @override
  Widget build(BuildContext context) {
    final success = results.where((r) => r.success).toList();
    final failed  = results.where((r) => !r.success).toList();

    // Build copy-all text
    String buildCopyText() {
      final buf = StringBuffer('الاسم | الإيميل | الباسورد\n');
      for (final r in success) {
        buf.writeln('${r.name} | ${r.email} | ${r.password}');
      }
      return buf.toString();
    }

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 1.h, bottom: 1.5.h),
              width: 12.w,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('نتائج الاستيراد',
                          style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      Text(
                          '${success.length} ناجح  •  ${failed.length} فاشل',
                          style: TextStyle(
                              fontSize: 10.sp, color: Colors.white38)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: buildCopyText()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('تم النسخ ✅')));
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA8FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.copy_rounded,
                            color: const Color(0xFF5BA8FF),
                            size: 11.sp),
                        SizedBox(width: 1.5.w),
                        Text('نسخ الكل',
                            style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF5BA8FF))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          // Table header
          Container(
            color: Colors.white.withOpacity(0.04),
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.8.h),
            child: Row(
              children: [
                _th('الاسم', flex: 3),
                _th('الإيميل', flex: 4),
                _th('الباسورد', flex: 3),
                _th('', flex: 1),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 3.h),
              itemCount: results.length,
              itemBuilder: (ctx, i) {
                final r = results[i];
                return Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: r.success
                        ? (i.isEven
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.02))
                        : Colors.red.withOpacity(0.06),
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.white.withOpacity(0.05))),
                  ),
                  child: r.success
                      ? Row(
                          children: [
                            _td(r.name, flex: 3, bold: true),
                            _td(r.email, flex: 4),
                            _td(r.password, flex: 3,
                                color: const Color(0xFF34C759)),
                            Expanded(
                              flex: 1,
                              child: GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                      text:
                                          '${r.email} | ${r.password}'));
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text('تم النسخ')));
                                },
                                child: Icon(Icons.copy_rounded,
                                    color: Colors.white24,
                                    size: 11.sp),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            _td(r.name, flex: 3, bold: true),
                            Expanded(
                              flex: 8,
                              child: Text(
                                '❌ ${r.error ?? 'خطأ'}',
                                style: TextStyle(
                                    fontSize: 8.sp,
                                    color: const Color(0xFFFF3B30)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _th(String t, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(t,
            style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white30)),
      );

  static Widget _td(String t,
          {int flex = 1, bool bold = false, Color? color}) =>
      Expanded(
        flex: flex,
        child: Text(t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 9.sp,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: color ?? (bold ? Colors.white : Colors.white54))),
      );
}
