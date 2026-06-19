import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/admin_repository.dart';

// ─── Upsert row ───────────────────────────────────────────────────────────────
// One row covers both "create new" and "update existing".
// Identifier: email OR phone (at least one required).
// Name fields are only needed when the player doesn't exist yet.

class _UpsertRow {
  // Identifiers
  String email;
  String phone;
  // Name (for new players)
  String firstName;
  String lastName;
  // Subscription / payment
  String? subscriptionPlan;
  String? paymentMethod;
  DateTime? subscriptionStart;
  DateTime? subscriptionEnd;
  double? totalAmount;
  double? amountPaid;
  double? discount;
  // Physical
  double? weight;
  double? height;
  double? muscleMass;
  double? fatPercentage;

  _UpsertRow({
    this.email        = '',
    this.phone        = '',
    this.firstName    = '',
    this.lastName     = '',
    this.subscriptionPlan,
    this.paymentMethod,
    this.subscriptionStart,
    this.subscriptionEnd,
    this.totalAmount,
    this.amountPaid,
    this.discount,
    this.weight,
    this.height,
    this.muscleMass,
    this.fatPercentage,
  });

  bool get hasIdentifier => email.trim().isNotEmpty || phone.trim().isNotEmpty;
  String get displayId   => email.isNotEmpty ? email : phone;
}

// ─── Result ───────────────────────────────────────────────────────────────────

class _RowResult {
  final String name;
  final String detail;      // email/password when created; email when updated
  final bool success;
  final bool wasCreated;    // true = new player, false = updated existing
  final String? error;

  const _RowResult({
    required this.name,
    required this.detail,
    required this.success,
    this.wasCreated = false,
    this.error,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ImportPlayersScreen extends ConsumerStatefulWidget {
  final String? overrideGymId;
  const ImportPlayersScreen({super.key, this.overrideGymId});

  @override
  ConsumerState<ImportPlayersScreen> createState() => _ImportPlayersScreenState();
}

class _ImportPlayersScreenState extends ConsumerState<ImportPlayersScreen> {
  List<_UpsertRow> _rows      = [];
  bool             _isParsing  = false;
  bool             _isRunning  = false;
  int              _doneCount  = 0;
  String?          _fileName;

  // ── File picking ────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file  = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() { _isParsing = true; _fileName = file.name; _rows = []; });
    try {
      final ext = file.extension?.toLowerCase() ?? '';
      if (ext == 'csv') {
        final content = String.fromCharCodes(bytes);
        _rows = _parseCsv(content);
      } else if (ext == 'xlsx' || ext == 'xls') {
        _rows = _parseExcel(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في قراءة الملف: $e')));
      }
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  // ── Excel parser ─────────────────────────────────────────────────────────

  List<_UpsertRow> _parseExcel(Uint8List bytes) {
    final excel = xl.Excel.decodeBytes(bytes);
    // Use first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;
    final allRows = sheet.rows;
    if (allRows.length < 2) return [];

    // Build headers from first row
    final headers = allRows.first
        .map((c) => (c?.value?.toString() ?? '').trim().toLowerCase())
        .toList();

    String _cell(List<xl.Data?> row, int idx) {
      if (idx < 0 || idx >= row.length) return '';
      return row[idx]?.value?.toString().trim() ?? '';
    }

    final iEmail   = _col(headers, ['email', 'ايميل', 'البريد']);
    final iPhone   = _col(headers, ['phone', 'جوال', 'mobile', 'الجوال']);
    final iFirst   = _col(headers, ['first', 'fname', 'الاسم_الأول', 'الاسم الاول']);
    final iLast    = _col(headers, ['last',  'lname', 'الاسم_الاخير', 'الاسم الاخير']);
    final iName    = _col(headers, ['name', 'player', 'الاسم']);
    final iPlan    = _col(headers, ['plan', 'خطة', 'الخطة']);
    final iStart   = _col(headers, ['start', 'بداية', 'البداية']);
    final iEnd     = _col(headers, ['end', 'نهاية', 'انتهاء', 'النهاية']);
    final iTotal   = _col(headers, ['total', 'إجمالي', 'المبلغ']);
    final iPaid    = _col(headers, ['paid', 'مدفوع', 'المدفوع']);
    final iDisc    = _col(headers, ['disc', 'خصم', 'discount', 'الخصم']);
    final iPayment = _col(headers, ['payment', 'طريقة', 'الطريقة']);
    final iWeight  = _col(headers, ['weight', 'وزن', 'الوزن']);
    final iHeight  = _col(headers, ['height', 'طول', 'الطول']);
    final iMuscle  = _col(headers, ['muscle', 'عضلي', 'كتلة']);
    final iFat     = _col(headers, ['fat', 'دهون']);

    final result = <_UpsertRow>[];
    for (final row in allRows.skip(1)) {
      final email = _cell(row, iEmail);
      final phone = _cell(row, iPhone);
      if (email.isEmpty && phone.isEmpty) continue;

      String first = '', last = '';
      if (iFirst >= 0) {
        first = _cell(row, iFirst);
        last  = _cell(row, iLast);
      } else if (iName >= 0) {
        final parts = _cell(row, iName).split(' ');
        first = parts.first;
        last  = parts.length > 1 ? parts.skip(1).join(' ') : '';
      }

      result.add(_UpsertRow(
        email:             email,
        phone:             phone,
        firstName:         first,
        lastName:          last,
        subscriptionPlan:  _cell(row, iPlan).isEmpty    ? null : _cell(row, iPlan),
        subscriptionStart: _parseDate(_cell(row, iStart)),
        subscriptionEnd:   _parseDate(_cell(row, iEnd)),
        totalAmount:       double.tryParse(_cell(row, iTotal)),
        amountPaid:        double.tryParse(_cell(row, iPaid)),
        discount:          double.tryParse(_cell(row, iDisc)),
        paymentMethod:     _cell(row, iPayment).isEmpty ? null : _cell(row, iPayment),
        weight:            double.tryParse(_cell(row, iWeight)),
        height:            double.tryParse(_cell(row, iHeight)),
        muscleMass:        double.tryParse(_cell(row, iMuscle)),
        fatPercentage:     double.tryParse(_cell(row, iFat)),
      ));
    }
    return result;
  }

  // ── CSV parser ───────────────────────────────────────────────────────────

  List<String> _splitRow(String line) =>
      line.split(',').map((c) => c.trim().replaceAll('"', '')).toList();

  int _col(List<String> headers, List<String> names) {
    for (final n in names) {
      final i = headers.indexWhere((h) => h.contains(n));
      if (i >= 0) return i;
    }
    return -1;
  }

  String _cell(List<String> row, int idx) =>
      (idx >= 0 && idx < row.length) ? row[idx] : '';

  DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    for (final fmt in ['dd/MM/yyyy', 'yyyy-MM-dd', 'MM/dd/yyyy', 'd/M/yyyy']) {
      try { return DateFormat(fmt).parse(s); } catch (_) {}
    }
    return null;
  }

  List<_UpsertRow> _parseCsv(String content) {
    final lines   = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return [];
    final headers = _splitRow(lines.first).map((h) => h.toLowerCase()).toList();

    final iEmail   = _col(headers, ['email', 'ايميل', 'البريد']);
    final iPhone   = _col(headers, ['phone', 'جوال', 'mobile', 'الجوال']);
    final iFirst   = _col(headers, ['first', 'fname', 'الاسم_الأول', 'الاسم الاول']);
    final iLast    = _col(headers, ['last',  'lname', 'الاسم_الاخير', 'الاسم الاخير']);
    final iName    = _col(headers, ['name', 'player', 'الاسم']);
    final iPlan    = _col(headers, ['plan', 'خطة', 'الخطة']);
    final iStart   = _col(headers, ['start', 'بداية', 'البداية']);
    final iEnd     = _col(headers, ['end', 'نهاية', 'انتهاء', 'النهاية']);
    final iTotal   = _col(headers, ['total', 'إجمالي', 'المبلغ']);
    final iPaid    = _col(headers, ['paid', 'مدفوع', 'المدفوع']);
    final iDisc    = _col(headers, ['disc', 'خصم', 'discount', 'الخصم']);
    final iPayment = _col(headers, ['payment', 'طريقة', 'الطريقة']);
    final iWeight  = _col(headers, ['weight', 'وزن', 'الوزن']);
    final iHeight  = _col(headers, ['height', 'طول', 'الطول']);
    final iMuscle  = _col(headers, ['muscle', 'عضلي', 'كتلة']);
    final iFat     = _col(headers, ['fat', 'دهون']);

    final result = <_UpsertRow>[];
    for (final line in lines.skip(1)) {
      final row   = _splitRow(line);
      final email = _cell(row, iEmail);
      final phone = _cell(row, iPhone);
      if (email.isEmpty && phone.isEmpty) continue;

      String first = '', last = '';
      if (iFirst >= 0) {
        first = _cell(row, iFirst);
        last  = _cell(row, iLast);
      } else if (iName >= 0) {
        final parts = _cell(row, iName).split(' ');
        first = parts.first;
        last  = parts.length > 1 ? parts.skip(1).join(' ') : '';
      }

      result.add(_UpsertRow(
        email:            email,
        phone:            phone,
        firstName:        first,
        lastName:         last,
        subscriptionPlan: _cell(row, iPlan).isEmpty    ? null : _cell(row, iPlan),
        subscriptionStart: _parseDate(_cell(row, iStart)),
        subscriptionEnd:   _parseDate(_cell(row, iEnd)),
        totalAmount:       double.tryParse(_cell(row, iTotal)),
        amountPaid:        double.tryParse(_cell(row, iPaid)),
        discount:          double.tryParse(_cell(row, iDisc)),
        paymentMethod:     _cell(row, iPayment).isEmpty ? null : _cell(row, iPayment),
        weight:            double.tryParse(_cell(row, iWeight)),
        height:            double.tryParse(_cell(row, iHeight)),
        muscleMass:        double.tryParse(_cell(row, iMuscle)),
        fatPercentage:     double.tryParse(_cell(row, iFat)),
      ));
    }
    return result;
  }

  // ── Run upsert ────────────────────────────────────────────────────────────

  Future<void> _run() async {
    final user  = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) return;
    final gymId = widget.overrideGymId ?? user.gymId ?? '';
    setState(() { _isRunning = true; _doneCount = 0; });

    final repo    = ref.read(adminRepositoryProvider);
    final results = <_RowResult>[];

    for (final row in _rows) {
      try {
        final res = await repo.upsertPlayerFromCsv(
          gymId:             gymId,
          addedByUid:        user.uid,
          email:             row.email.isEmpty    ? null : row.email,
          phone:             row.phone.isEmpty    ? null : row.phone,
          firstName:         row.firstName.isEmpty ? null : row.firstName,
          lastName:          row.lastName.isEmpty  ? null : row.lastName,
          subscriptionPlan:  row.subscriptionPlan,
          subscriptionStart: row.subscriptionStart,
          subscriptionEnd:   row.subscriptionEnd,
          totalAmount:       row.totalAmount,
          amountPaid:        row.amountPaid,
          discount:          row.discount,
          paymentMethod:     row.paymentMethod,
          weight:            row.weight,
          height:            row.height,
          muscleMass:        row.muscleMass,
          fatPercentage:     row.fatPercentage,
        );
        results.add(_RowResult(
          name:       res.name,
          detail:     row.displayId,
          success:    true,
          wasCreated: res.wasCreated,
        ));
      } catch (e) {
        results.add(_RowResult(
          name:    row.displayId,
          detail:  '',
          success: false,
          error:   e.toString(),
        ));
      }
      if (mounted) setState(() => _doneCount++);
    }

    if (mounted) {
      setState(() => _isRunning = false);
      _showResults(results);
    }
  }

  void _showResults(List<_RowResult> results) {
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
            _buildFormatHint(),
            Expanded(
              child: _isParsing
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3B30)))
                  : _rows.isEmpty
                      ? _buildEmpty()
                      : _buildPreview(),
            ),
            if (_rows.isNotEmpty) _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopbar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0.5.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 9.w, height: 9.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 12.sp),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('استيراد / تحديث لاعبين',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                if (_fileName != null)
                  Text(_fileName!, style: TextStyle(fontSize: 9.sp, color: Colors.white38)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isRunning ? null : _pickFile,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.15),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Row(
                children: [
                  Icon(Icons.upload_file_rounded, color: const Color(0xFFFF3B30), size: 12.sp),
                  SizedBox(width: 1.5.w),
                  Text('رفع ملف', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: const Color(0xFFFF3B30))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatHint() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(2.w),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.info_outline_rounded, color: Colors.white30, size: 10.sp),
              SizedBox(width: 2.w),
              Text('الأعمدة المتاحة (CSV / Excel)', style: TextStyle(fontSize: 9.5.sp, fontWeight: FontWeight.w700, color: Colors.white38)),
            ]),
            SizedBox(height: 0.5.h),
            Text(
              'مطلوب: email أو phone\n'
              'اختياري: first/last/name · plan · start · end · total · paid · discount · payment\n'
              'جسدي: weight · height · muscle · fat',
              style: TextStyle(fontSize: 8.5.sp, color: Colors.white24, height: 1.4),
            ),
            SizedBox(height: 0.5.h),
            Row(
              children: [
                _badge('موجود → تحديث', const Color(0xFF5BA8FF)),
                SizedBox(width: 2.w),
                _badge('غير موجود → إضافة', const Color(0xFF34C759)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(1.5.w),
      border: Border.all(color: c.withOpacity(0.3)),
    ),
    child: Text(t, style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w700, color: c)),
  );

  Widget _fileTypeBadge(String ext, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(1.5.w),
      border: Border.all(color: c.withOpacity(0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.description_outlined, size: 9.sp, color: c),
        SizedBox(width: 1.w),
        Text(ext, style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w800, color: c)),
      ],
    ),
  );

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📂', style: TextStyle(fontSize: 48.sp)),
          SizedBox(height: 2.h),
          Text('ارفع ملف CSV أو Excel',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white)),
          SizedBox(height: 0.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _fileTypeBadge('CSV', const Color(0xFF5BA8FF)),
              SizedBox(width: 2.w),
              _fileTypeBadge('XLSX', const Color(0xFF34C759)),
              SizedBox(width: 2.w),
              _fileTypeBadge('XLS', const Color(0xFFFF9500)),
            ],
          ),
          SizedBox(height: 1.h),
          Text('لاعبين موجودين → تحديث  |  جدد → إضافة تلقائي',
            style: TextStyle(fontSize: 10.sp, color: Colors.white38)),
          SizedBox(height: 3.h),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Text('اختر ملف',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        // count strip
        Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          decoration: BoxDecoration(
            color: const Color(0xFF34C759).withOpacity(0.1),
            borderRadius: BorderRadius.circular(2.w),
            border: Border.all(color: const Color(0xFF34C759).withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, color: const Color(0xFF34C759), size: 12.sp),
            SizedBox(width: 2.w),
            Text('تم قراءة ${_rows.length} سجل من الملف',
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: const Color(0xFF34C759))),
          ]),
        ),
        // header
        Container(
          color: Colors.white.withOpacity(0.05),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
          child: Row(children: [
            _hCell('الاسم / الإيميل', flex: 4),
            _hCell('الخطة', flex: 2),
            _hCell('البداية', flex: 2),
            _hCell('النهاية', flex: 2),
            _hCell('المبلغ', flex: 2),
          ]),
        ),
        // rows
        Expanded(
          child: ListView.builder(
            itemCount: _rows.length,
            itemBuilder: (_, i) {
              final r = _rows[i];
              final id = r.firstName.isNotEmpty
                  ? '${r.firstName} ${r.lastName}'.trim()
                  : r.displayId;
              return _tableRow(i, [
                id,
                r.subscriptionPlan ?? '—',
                r.subscriptionStart != null ? DateFormat('dd/MM/yy').format(r.subscriptionStart!) : '—',
                r.subscriptionEnd   != null ? DateFormat('dd/MM/yy').format(r.subscriptionEnd!)   : '—',
                r.totalAmount != null ? '${r.totalAmount!.toStringAsFixed(0)}' : '—',
              ], flexes: [4, 2, 2, 2, 2]);
            },
          ),
        ),
      ],
    );
  }

  Widget _tableRow(int i, List<String> cells, {required List<int> flexes}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: i.isEven ? Colors.transparent : Colors.white.withOpacity(0.02),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: List.generate(cells.length, (j) =>
          Expanded(
            flex: flexes[j],
            child: Text(cells[j],
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: j == 0 ? FontWeight.w700 : FontWeight.w400,
                color: j == 0 ? Colors.white : Colors.white60)),
          ),
        ),
      ),
    );
  }

  Widget _hCell(String t, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(t, style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w700, color: Colors.white38)),
  );

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0F),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: _isRunning
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              Text('جاري المعالجة... $_doneCount / ${_rows.length}',
                style: TextStyle(fontSize: 11.sp, color: Colors.white54)),
              SizedBox(height: 1.h),
              LinearProgressIndicator(
                value: _rows.isEmpty ? 0 : _doneCount / _rows.length,
                color: const Color(0xFFFF3B30),
                backgroundColor: Colors.white12,
              ),
            ])
          : SizedBox(
              width: double.infinity, height: 6.h,
              child: ElevatedButton(
                onPressed: _run,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
                ),
                child: Text(
                  'معالجة ${_rows.length} سجل',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
    );
  }
}

// ─── Results Sheet ────────────────────────────────────────────────────────────

class _ResultsSheet extends StatelessWidget {
  final List<_RowResult> results;
  const _ResultsSheet({required this.results});

  @override
  Widget build(BuildContext context) {
    final created = results.where((r) => r.success && r.wasCreated).toList();
    final updated = results.where((r) => r.success && !r.wasCreated).toList();
    final failed  = results.where((r) => !r.success).toList();

    String buildCopyText() {
      final buf = StringBuffer();
      if (created.isNotEmpty) {
        buf.writeln('=== مضافون جدد ===');
        for (final r in created) buf.writeln('${r.name} | ${r.detail}');
        buf.writeln();
      }
      if (updated.isNotEmpty) {
        buf.writeln('=== تم تحديثهم ===');
        for (final r in updated) buf.writeln('${r.name} | ${r.detail}');
      }
      return buf.toString();
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 1.h, bottom: 1.5.h),
              width: 12.w, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('النتائج',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    Row(children: [
                      _tag('${created.length} جديد', const Color(0xFF34C759)),
                      SizedBox(width: 2.w),
                      _tag('${updated.length} محدّث', const Color(0xFF5BA8FF)),
                      SizedBox(width: 2.w),
                      if (failed.isNotEmpty) _tag('${failed.length} خطأ', const Color(0xFFFF3B30)),
                    ]),
                  ]),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: buildCopyText()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ ✅')));
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA8FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Row(children: [
                      Icon(Icons.copy_rounded, color: const Color(0xFF5BA8FF), size: 11.sp),
                      SizedBox(width: 1.5.w),
                      Text('نسخ', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: const Color(0xFF5BA8FF))),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          Container(
            color: Colors.white.withOpacity(0.04),
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.8.h),
            child: Row(children: [
              _th('الاسم', flex: 3),
              _th('الإيميل / الجوال', flex: 5),
              _th('', flex: 1),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 3.h),
              itemCount: results.length,
              itemBuilder: (ctx, i) {
                final r = results[i];
                Color leftColor = r.success
                    ? (r.wasCreated ? const Color(0xFF34C759) : const Color(0xFF5BA8FF))
                    : const Color(0xFFFF3B30);

                return Container(
                  decoration: BoxDecoration(
                    color: r.success ? Colors.transparent : Colors.red.withOpacity(0.06),
                    border: Border(
                      left: BorderSide(color: leftColor, width: 3),
                      bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  child: r.success
                      ? Row(children: [
                          _tdw(r.name, flex: 3, bold: true),
                          _tdw(r.detail, flex: 5, color: Colors.white60),
                          Expanded(
                            flex: 1,
                            child: Text(
                              r.wasCreated ? '✨' : '✏️',
                              style: TextStyle(fontSize: 11.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ])
                      : Row(children: [
                          _tdw(r.name, flex: 3, bold: true),
                          Expanded(
                            flex: 6,
                            child: Text('❌ ${r.error ?? 'خطأ'}',
                              style: TextStyle(fontSize: 8.sp, color: const Color(0xFFFF3B30)),
                              overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(t, style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w700, color: c)),
  );

  static Widget _th(String t, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(t, style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.w700, color: Colors.white30)),
  );

  static Widget _tdw(String t, {int flex = 1, bool bold = false, Color? color}) =>
      Expanded(
        flex: flex,
        child: Text(t,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? (bold ? Colors.white : Colors.white54))),
      );
}
