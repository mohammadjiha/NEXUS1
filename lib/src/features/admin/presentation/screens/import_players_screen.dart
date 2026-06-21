import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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
  final String detail;       // email/phone when created; email when updated
  final bool success;
  final bool wasCreated;     // true = new player, false = existed before
  final bool wasUpdated;     // true = fields changed, false = data identical (موجود)
  final bool isPendingEdit;  // edited locally, waiting for user to press upload
  final String? error;
  final String? playerId;    // Firestore uid (available on success)
  final _UpsertRow? row;     // original row — for retry after edit

  const _RowResult({
    required this.name,
    required this.detail,
    required this.success,
    this.wasCreated     = false,
    this.wasUpdated     = false,
    this.isPendingEdit  = false,
    this.error,
    this.playerId,
    this.row,
  });
}

// ─── Preview Row ─────────────────────────────────────────────────────────────
// Wraps an _UpsertRow with the check result (new vs existing) and edit state.

class _PreviewRow {
  _UpsertRow row;          // current (possibly edited) row data
  bool checked   = false;  // has Firestore check completed?
  bool exists    = false;  // player already in Firestore?
  String uid     = '';     // Firestore uid if exists
  String existingName = '';

  _PreviewRow({required this.row});

  String get displayName => row.firstName.isNotEmpty
      ? '${row.firstName} ${row.lastName}'.trim()
      : row.displayId;
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ImportPlayersScreen extends ConsumerStatefulWidget {
  final String? overrideGymId;
  const ImportPlayersScreen({super.key, this.overrideGymId});

  @override
  ConsumerState<ImportPlayersScreen> createState() => _ImportPlayersScreenState();
}

class _ImportPlayersScreenState extends ConsumerState<ImportPlayersScreen> {
  List<_UpsertRow> _rows         = [];
  bool             _isParsing    = false;
  bool             _isMerging    = false;
  bool             _isMigrating  = false;
  String?          _fileName;

  // ── Backfill payment records ─────────────────────────────────────────────
  Future<void> _backfillPayments() async {
    final user  = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) return;
    final gymId = widget.overrideGymId ?? user.gymId ?? '';
    if (gymId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('إصلاح الإيرادات', style: TextStyle(color: Colors.white)),
        content: const Text(
          'سيتم إنشاء سجلات دفع للاعبين الذين لديهم مبالغ مدفوعة ولا يظهرون في تقرير الإيرادات.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('إصلاح', style: TextStyle(color: Color(0xFF34C759)))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isMigrating = true);
    try {
      final result = await ref.read(adminRepositoryProvider).backfillPaymentRecords(gymId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✅ تم إنشاء ${result['created']} سجل دفع · تخطّى ${result['skipped']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF34C759),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ));
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  // ── Migrate old .nexus emails ───────────────────────────────────────────
  Future<void> _migrateEmails() async {
    final user  = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) return;
    final gymId = widget.overrideGymId ?? user.gymId ?? '';
    if (gymId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('تحديث الإيميلات', style: TextStyle(color: Colors.white)),
        content: const Text(
          'سيتم تحويل الإيميلات القديمة (gym.nexus) إلى صيغة\nfirstname.lastname.xxxx@gmail.com\n\nفقط اللاعبين الذين لديهم كلمة مرور مؤقتة سيُحدَّثون.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('تحديث', style: TextStyle(color: Color(0xFF5BA8FF)))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isMigrating = true);
    try {
      final result = await ref.read(adminRepositoryProvider).migratePlayerEmails(gymId);
      ref.invalidate(adminPlayersProvider(gymId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✅ تم تحديث ${result['migrated']} إيميل · تخطّى ${result['skipped']} · فشل ${result['failed']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: const Color(0xFF34C759),
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ));
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  // ── Merge duplicates ────────────────────────────────────────────────────
  Future<void> _showMergePreview() async {
    final user  = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) return;
    final gymId = widget.overrideGymId ?? user.gymId ?? '';
    if (gymId.isEmpty) return;

    setState(() => _isMerging = true);
    try {
      final repo   = ref.read(adminRepositoryProvider);
      final groups = await repo.getDuplicateGroups(gymId);
      if (!mounted) return;
      setState(() => _isMerging = false);

      if (groups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ لا توجد أسماء مكررة'),
          backgroundColor: Color(0xFF34C759),
        ));
        return;
      }

      // Show preview sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MergePreviewSheet(
          groups: groups,
          gymId:  gymId,
          onMerged: () => ref.invalidate(adminPlayersProvider(gymId)),
        ),
      );
    } catch (e) {
      setState(() => _isMerging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ));
      }
    }
  }

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
    // Yield so the loading spinner renders before heavy parsing begins
    await Future.delayed(const Duration(milliseconds: 80));

    try {
      final ext = file.extension?.toLowerCase() ?? '';
      List<_UpsertRow> parsed = [];
      if (ext == 'csv') {
        final content = String.fromCharCodes(bytes);
        parsed = _parseCsv(content);
      } else if (ext == 'xlsx' || ext == 'xls') {
        parsed = _parseExcel(bytes);
      }
      if (mounted) {
        setState(() => _rows = parsed);
        if (parsed.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لم يتم العثور على بيانات — تحقق من أعمدة الملف'),
            backgroundColor: Color(0xFFFF9500),
          ));
        } else {
          // Open preview sheet — user reviews/edits before uploading
          setState(() => _isParsing = false);
          _showPreview(parsed);
          return; // skip finally setState since we already set it
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ في قراءة الملف: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ));
      }
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  // ── Excel parser (manual XML — avoids excel package's XFD column bug) ────

  /// Convert Excel column letters to 0-based index  (A→0, B→1, AA→26 …)
  int _colLetterIdx(String col) {
    int v = 0;
    for (final ch in col.codeUnits) v = v * 26 + (ch - 64);
    return v - 1;
  }

  String _xmlUnescape(String s) => s
      .replaceAll('&amp;',  '&')
      .replaceAll('&lt;',   '<')
      .replaceAll('&gt;',   '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");

  List<_UpsertRow> _parseExcel(Uint8List bytes) {
    final arc = ZipDecoder().decodeBytes(bytes, verify: false);

    // ── Shared strings ─────────────────────────────────────────────────────
    final sharedStrings = <String>[];
    final ssFile = arc.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      final xml = utf8.decode(ssFile.content as List<int>, allowMalformed: true);
      final siRe = RegExp(r'<si>(.*?)</si>', dotAll: true);
      final tRe  = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
      for (final si in siRe.allMatches(xml)) {
        final buf = StringBuffer();
        for (final t in tRe.allMatches(si.group(1)!)) {
          buf.write(_xmlUnescape(t.group(1)!));
        }
        sharedStrings.add(buf.toString());
      }
    }

    // ── Date style detection ───────────────────────────────────────────────
    final dateStyleIdx = <int>{};
    final stylesFile = arc.findFile('xl/styles.xml');
    if (stylesFile != null) {
      final xml = utf8.decode(stylesFile.content as List<int>, allowMalformed: true);
      final customDate = <int>{};
      for (final m in RegExp(r'numFmtId="(\d+)" formatCode="([^"]*)"').allMatches(xml)) {
        final code = m.group(2)!.toLowerCase();
        if (code.contains('y') || (code.contains('d') && code.contains('m'))) {
          customDate.add(int.parse(m.group(1)!));
        }
      }
      const stdDate = {14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47};
      final xfsMatch = RegExp(r'<cellXfs>(.*?)</cellXfs>', dotAll: true).firstMatch(xml);
      if (xfsMatch != null) {
        int idx = 0;
        for (final m in RegExp(r'<xf\b[^>]*numFmtId="(\d+)"').allMatches(xfsMatch.group(1)!)) {
          final fmtId = int.parse(m.group(1)!);
          if (stdDate.contains(fmtId) || customDate.contains(fmtId)) dateStyleIdx.add(idx);
          idx++;
        }
      }
    }

    // ── Sheet XML ──────────────────────────────────────────────────────────
    ArchiveFile? sheetFile;
    for (final f in arc.files) {
      if (f.isFile && f.name.contains('worksheets/') && f.name.endsWith('.xml')) {
        sheetFile = f; break;
      }
    }
    if (sheetFile == null) return [];

    final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);

    // ── Fast string-split parser (avoids catastrophic regex backtracking) ──
    // Split by '<row ' — each chunk[i≥1] starts with row attributes.
    final grid = <int, Map<int, String>>{};

    // Small helpers — only used on short per-cell strings, so regex is fine.
    String _attrVal(String attrs, String name) {
      final i = attrs.indexOf('$name="');
      if (i < 0) return '';
      final start = i + name.length + 2;
      final end   = attrs.indexOf('"', start);
      return end < 0 ? '' : attrs.substring(start, end);
    }

    String _between(String s, String open, String close) {
      final i = s.indexOf(open);
      if (i < 0) return '';
      final j = s.indexOf(close, i + open.length);
      return j < 0 ? '' : s.substring(i + open.length, j);
    }

    final rowChunks = sheetXml.split('<row ');
    for (int ri = 1; ri < rowChunks.length; ri++) {
      final chunk = rowChunks[ri];
      // Row attrs end at the first '>'
      final gtIdx = chunk.indexOf('>');
      if (gtIdx < 0) continue;
      final rowAttrs  = chunk.substring(0, gtIdx);
      final rowEndIdx = chunk.indexOf('</row>');
      final rowBody   = rowEndIdx < 0
          ? chunk.substring(gtIdx + 1)
          : chunk.substring(gtIdx + 1, rowEndIdx);

      final rStr = _attrVal(rowAttrs, 'r');
      final rowNum = int.tryParse(rStr);
      if (rowNum == null) continue;
      final rowIdx = rowNum - 1; // 0-based
      final cells  = grid.putIfAbsent(rowIdx, () => {});

      // Split row body by '<c ' to get per-cell chunks
      final cellChunks = rowBody.split('<c ');
      for (int ci = 1; ci < cellChunks.length; ci++) {
        final cc = cellChunks[ci];
        // Cell attrs end at first '>'
        final cgt = cc.indexOf('>');
        if (cgt < 0) continue;
        final cAttrs = cc.substring(0, cgt);

        // Cell ref like r="B3"
        final ref = _attrVal(cAttrs, 'r');
        if (ref.isEmpty) continue;
        // Extract column letters (leading alpha chars)
        int alphaEnd = 0;
        while (alphaEnd < ref.length && ref.codeUnitAt(alphaEnd) >= 65) alphaEnd++;
        if (alphaEnd == 0) continue;
        final colIdx = _colLetterIdx(ref.substring(0, alphaEnd));

        final type     = _attrVal(cAttrs, 't');
        final styleStr = _attrVal(cAttrs, 's');
        final styleNum = int.tryParse(styleStr);

        // Value between <v>…</v>
        final raw = _between(cc, '<v>', '</v>');
        if (raw.isEmpty) continue;

        String val;
        if (type == 's') {
          final idx = int.tryParse(raw) ?? -1;
          val = (idx >= 0 && idx < sharedStrings.length) ? sharedStrings[idx] : '';
        } else if (type == 'str' || type == 'inlineStr') {
          val = _xmlUnescape(raw);
        } else if (type == 'b') {
          val = raw == '1' ? 'true' : 'false';
        } else {
          if (styleNum != null && dateStyleIdx.contains(styleNum)) {
            final serial = double.tryParse(raw);
            if (serial != null) {
              final dt = DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
              val = DateFormat('dd/MM/yyyy').format(dt);
            } else {
              val = raw;
            }
          } else {
            val = raw;
          }
        }
        cells[colIdx] = val;
      }
    }

    if (grid.length < 2) return [];

    // ── Column mapping ─────────────────────────────────────────────────────
    final hRow    = grid[0] ?? {};
    final maxHCol = hRow.isEmpty ? 0 : hRow.keys.reduce((a, b) => a > b ? a : b) + 1;
    final headers = List.generate(maxHCol, (c) => (hRow[c] ?? '').trim().toLowerCase());

    String gc(int r, int c) => c < 0 ? '' : (grid[r]?[c] ?? '').trim();

    final iEmail   = _col(headers, ['email', 'ايميل', 'البريد']);
    final iPhone   = _col(headers, ['phone', 'هاتف', 'جوال', 'mobile', 'الجوال']);
    final iFirst   = _col(headers, ['first', 'fname', 'الاسم_الأول', 'الاسم الاول']);
    final iLast    = _col(headers, ['last',  'lname', 'الاسم_الاخير', 'الاسم الاخير']);
    final iName    = _col(headers, ['name', 'player', 'الاسم', 'اسم']);
    final iPlan    = _col(headers, ['plan', 'خطة', 'الخطة', 'اشتراك']);
    final iStart   = _col(headers, ['start', 'بداية', 'البداية', 'تاريخ']);
    final iEnd     = _col(headers, ['end', 'نهاية', 'انتهاء', 'النهاية']);
    final iTotal   = _col(headers, ['total', 'إجمالي', 'المبلغ', 'مجموع']);
    final iPaid    = _col(headers, ['paid', 'مدفوع', 'المدفوع']);
    final iRemain  = _col(headers, ['remain', 'متبقي', 'المتبقي', 'باقي']);
    final iDisc    = _col(headers, ['disc', 'خصم', 'discount', 'الخصم']);
    final iPayment = _col(headers, ['payment', 'طريقة', 'الطريقة']);
    final iWeight  = _col(headers, ['weight', 'وزن', 'الوزن']);
    final iHeight  = _col(headers, ['height', 'طول', 'الطول']);
    final iMuscle  = _col(headers, ['muscle', 'عضلي', 'كتلة']);
    final iFat     = _col(headers, ['fat', 'دهون']);

    final result = <_UpsertRow>[];
    final maxRow = grid.keys.reduce((a, b) => a > b ? a : b);
    for (int r = 1; r <= maxRow; r++) {
      final name  = gc(r, iName);
      final email = gc(r, iEmail);
      final phone = gc(r, iPhone);
      if (name.isEmpty && email.isEmpty && phone.isEmpty) continue;

      final paid   = double.tryParse(gc(r, iPaid));
      final remain = double.tryParse(gc(r, iRemain));
      final total  = double.tryParse(gc(r, iTotal)) ??
          (paid != null && remain != null ? paid + remain : null);

      String first = '', last = '';
      if (iFirst >= 0) {
        first = gc(r, iFirst);
        last  = gc(r, iLast);
      } else if (name.isNotEmpty) {
        final parts = name.split(' ');
        first = parts.first;
        last  = parts.length > 1 ? parts.skip(1).join(' ') : '';
      }

      result.add(_UpsertRow(
        email:             email,
        phone:             phone,
        firstName:         first,
        lastName:          last,
        subscriptionPlan:  gc(r, iPlan).isEmpty    ? null : gc(r, iPlan),
        subscriptionStart: _parseDate(gc(r, iStart)),
        subscriptionEnd:   _parseDate(gc(r, iEnd)),
        totalAmount:       total,
        amountPaid:        paid,
        discount:          double.tryParse(gc(r, iDisc)),
        paymentMethod:     gc(r, iPayment).isEmpty ? null : gc(r, iPayment),
        weight:            double.tryParse(gc(r, iWeight)),
        height:            double.tryParse(gc(r, iHeight)),
        muscleMass:        double.tryParse(gc(r, iMuscle)),
        fatPercentage:     double.tryParse(gc(r, iFat)),
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

  void _showPreview(List<_UpsertRow> parsed) {
    final user  = ref.read(currentUserModelProvider).asData?.value;
    if (user == null) return;
    final gymId = widget.overrideGymId ?? user.gymId ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreviewSheet(
        rows:       parsed,
        gymId:      gymId,
        addedByUid: user.uid,
        fileName:   _fileName ?? 'ملف غير معروف',
        onUploaded: (results) => _showResults(results, gymId: gymId, addedByUid: user.uid),
      ),
    );
  }

  void _showResults(List<_RowResult> results, {required String gymId, required String addedByUid}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultsSheet(results: results, gymId: gymId, addedByUid: addedByUid),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user   = ref.watch(currentUserModelProvider).asData?.value;
    final gymId  = widget.overrideGymId ?? user?.gymId ?? '';
    final history = ref.watch(importHistoryProvider(gymId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(),
            _buildFormatHint(),
            Expanded(
              child: _isParsing
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(color: Color(0xFFFF3B30)),
                        SizedBox(height: 2.h),
                        Text('جاري قراءة الملف...',
                            style: TextStyle(fontSize: 11.sp, color: Colors.white54)),
                      ]),
                    )
                  : history.when(
                      loading: () => _buildEmpty(),
                      error:   (_, __) => _buildEmpty(),
                      data: (entries) => entries.isEmpty
                          ? _buildEmpty()
                          : _buildHistoryBody(entries),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopbar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 0.5.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (_fileName != null)
                      Text(_fileName!, style: TextStyle(fontSize: 11.sp, color: Colors.white38)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Backfill payments button
                GestureDetector(
                  onTap: _isMigrating ? null : _backfillPayments,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: _isMigrating
                        ? SizedBox(width: 6.w, height: 6.w,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34C759)))
                        : Row(children: [
                            Icon(Icons.attach_money_rounded, color: const Color(0xFF34C759), size: 18.sp),
                            SizedBox(width: 1.5.w),
                            Text('إصلاح', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF34C759))),
                          ]),
                  ),
                ),
                SizedBox(width: 2.w),
                // Migrate emails button
                GestureDetector(
                  onTap: _isMigrating ? null : _migrateEmails,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA8FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: _isMigrating
                        ? SizedBox(width: 6.w, height: 6.w,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5BA8FF)))
                        : Row(children: [
                            Icon(Icons.alternate_email_rounded, color: const Color(0xFF5BA8FF), size: 18.sp),
                            SizedBox(width: 1.5.w),
                            Text('إيميلات', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFF5BA8FF))),
                          ]),
                  ),
                ),
                SizedBox(width: 2.w),
                // Merge duplicates button
                GestureDetector(
                  onTap: _isMerging ? null : _showMergePreview,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: _isMerging
                        ? SizedBox(width: 6.w, height: 6.w,
                            child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF9500)))
                        : Row(children: [
                            Icon(Icons.merge_rounded, color: const Color(0xFFFF9500), size: 18.sp),
                            SizedBox(width: 1.5.w),
                            Text('دمج نسخ', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFFFF9500))),
                          ]),
                  ),
                ),
                SizedBox(width: 2.w),
                // Upload button
                GestureDetector(
                  onTap: _pickFile,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2.w),
                    ),
                    child: Row(children: [
                      Icon(Icons.upload_file_rounded, color: const Color(0xFFFF3B30), size: 18.sp),
                      SizedBox(width: 1.5.w),
                      Text('رفع ملف', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: const Color(0xFFFF3B30))),
                    ]),
                  ),
                ),
              ],
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
              Icon(Icons.info_outline_rounded, color: Colors.white30, size: 18.sp),
              SizedBox(width: 2.w),
              Text('الأعمدة المتاحة (CSV / Excel)', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white38)),
            ]),
            SizedBox(height: 1.h),
            Text(
              'مطلوب: email أو phone\n'
              'اختياري: first/last/name · plan · start · end · total · paid · discount · payment\n'
              'جسدي: weight · height · muscle · fat',
              style: TextStyle(fontSize: 14.sp, color: Colors.white24, height: 1.5),
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
    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(3.w),
      border: Border.all(color: c.withOpacity(0.3)),
    ),
    child: Text(t, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: c)),
  );

  Widget _fileTypeBadge(String ext, Color c) => Container(
    padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.8.h),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(2.w),
      border: Border.all(color: c.withOpacity(0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.description_outlined, size: 12.sp, color: c),
        SizedBox(width: 1.5.w),
        Text(ext, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: c)),
      ],
    ),
  );

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📂', style: TextStyle(fontSize: 60.sp)),
          SizedBox(height: 2.5.h),
          Text('ارفع ملف CSV أو Excel',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white)),
          SizedBox(height: 1.h),
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
          SizedBox(height: 1.5.h),
          Text('لاعبين موجودين → تحديث  |  جدد → إضافة تلقائي',
            style: TextStyle(fontSize: 13.sp, color: Colors.white38)),
          SizedBox(height: 4.h),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 1.8.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(3.w),
              ),
              child: Text('اختر ملف',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHistoryBody(List<ImportHistoryEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload button row
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0.5.h),
          child: Row(children: [
            Expanded(
              child: Text('سجل الرفعات',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30),
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.upload_file_rounded, color: Colors.white, size: 14.sp),
                  SizedBox(width: 1.5.w),
                  Text('رفع ملف جديد',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
          ]),
        ),
        // History list
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(4.w, 0.5.h, 4.w, 4.h),
            itemCount: entries.length,
            itemBuilder: (ctx, i) => _buildHistoryCard(entries[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(ImportHistoryEntry e) {
    final now  = DateTime.now();
    final diff = now.difference(e.uploadedAt);
    String timeAgo;
    if (diff.inMinutes < 1)       timeAgo = 'الآن';
    else if (diff.inMinutes < 60) timeAgo = 'منذ ${diff.inMinutes} دقيقة';
    else if (diff.inHours < 24)   timeAgo = 'منذ ${diff.inHours} ساعة';
    else if (diff.inDays == 1)     timeAgo = 'أمس';
    else                           timeAgo = 'منذ ${diff.inDays} يوم';

    final hasFailed = e.failedCount > 0;

    return Container(
      margin: EdgeInsets.only(bottom: 1.2.h),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(
          color: hasFailed
              ? const Color(0xFFFF3B30).withOpacity(0.25)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // File name + time
        Row(children: [
          Icon(Icons.description_rounded,
            color: e.fileName.endsWith('.xlsx') || e.fileName.endsWith('.xls')
                ? const Color(0xFF34C759)
                : const Color(0xFF5BA8FF),
            size: 20.sp),
          SizedBox(width: 3.w),
          Expanded(child: Text(e.fileName,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text(timeAgo, style: TextStyle(fontSize: 12.sp, color: Colors.white38)),
        ]),
        SizedBox(height: 1.h),
        // Stats row
        Wrap(spacing: 6, runSpacing: 4, children: [
          if (e.newCount > 0)
            _histTag('✨ ${e.newCount} جديد', const Color(0xFF34C759)),
          if (e.updatedCount > 0)
            _histTag('✏️ ${e.updatedCount} محدّث', const Color(0xFF5BA8FF)),
          if (e.existingCount > 0)
            _histTag('✓ ${e.existingCount} موجود', Colors.white38),
          if (e.failedCount > 0)
            _histTag('❌ ${e.failedCount} فاشل', const Color(0xFFFF3B30)),
        ]),
        SizedBox(height: 1.h),
        Text('إجمالي: ${e.totalCount} سجل',
          style: TextStyle(fontSize: 13.sp, color: Colors.white30)),
      ]),
    );
  }

  static Widget _histTag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(t, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: c)),
  );

}

// ─── Merge Preview Sheet ──────────────────────────────────────────────────────

class _MergePreviewSheet extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> groups;
  final String gymId;
  final VoidCallback onMerged;

  const _MergePreviewSheet({
    required this.groups,
    required this.gymId,
    required this.onMerged,
  });

  @override
  ConsumerState<_MergePreviewSheet> createState() => _MergePreviewSheetState();
}

class _MergePreviewSheetState extends ConsumerState<_MergePreviewSheet> {
  bool _isMerging = false;

  Future<void> _doMerge() async {
    setState(() => _isMerging = true);
    try {
      final deleted = await ref.read(adminRepositoryProvider)
          .deduplicatePlayers(widget.gymId);
      widget.onMerged();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ تم دمج وحذف $deleted سجل مكرر'),
          backgroundColor: const Color(0xFF34C759),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      setState(() => _isMerging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: const Color(0xFFFF3B30),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDupes = widget.groups.fold<int>(
        0, (sum, g) => sum + ((g['count'] as int) - 1));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(
          margin: EdgeInsets.only(top: 1.h, bottom: 1.5.h),
          width: 12.w, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
        )),
        // Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أسماء مكررة', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('${widget.groups.length} اسم · $totalDupes سجل سيُحذف',
                style: TextStyle(fontSize: 10.sp, color: Colors.white38)),
            ])),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, color: Colors.white54, size: 14.sp),
              ),
            ),
          ]),
        ),
        // Info banner
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 0),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.1),
              borderRadius: BorderRadius.circular(2.w),
              border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFFF9500), size: 16),
              SizedBox(width: 2.w),
              Expanded(child: Text(
                'سيتم الإبقاء على الأحدث ودمج بياناته، وحذف الباقي نهائياً',
                style: TextStyle(fontSize: 10.sp, color: const Color(0xFFFF9500)),
              )),
            ]),
          ),
        ),
        SizedBox(height: 1.h),
        // List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: widget.groups.length,
            itemBuilder: (ctx, i) {
              final g    = widget.groups[i];
              final name  = g['name'] as String;
              final count = g['count'] as int;
              final docs  = g['docs'] as List;
              return Container(
                margin: EdgeInsets.only(bottom: 1.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(3.w),
                  border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Name row
                  Padding(
                    padding: EdgeInsets.fromLTRB(3.w, 1.2.h, 3.w, 0.5.h),
                    child: Row(children: [
                      Expanded(child: Text(name,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: Colors.white))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('$count نسخ', style: TextStyle(fontSize: 9.sp, color: const Color(0xFFFF3B30), fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),
                  // Entries
                  ...docs.asMap().entries.map((e) {
                    final isKeep = e.key == 0;
                    final d = e.value as Map;
                    final ts = d['updatedAt'] as Timestamp?;
                    final date = ts != null
                        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                        : '—';
                    final phone = (d['phone'] as String? ?? '').isNotEmpty ? d['phone'] : null;
                    final plan  = (d['subscriptionPlan'] as String? ?? '').isNotEmpty ? d['subscriptionPlan'] : null;
                    return Container(
                      margin: EdgeInsets.fromLTRB(3.w, 0, 3.w, 0.6.h),
                      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.8.h),
                      decoration: BoxDecoration(
                        color: isKeep
                            ? const Color(0xFF34C759).withOpacity(0.07)
                            : const Color(0xFFFF3B30).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(2.w),
                        border: Border(left: BorderSide(
                          color: isKeep ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                          width: 3,
                        )),
                      ),
                      child: Row(children: [
                        Text(isKeep ? '✅ يُبقى' : '🗑 يُحذف',
                          style: TextStyle(fontSize: 9.sp, color: isKeep ? const Color(0xFF34C759) : const Color(0xFFFF3B30))),
                        SizedBox(width: 2.w),
                        Expanded(child: Text(
                          [if (phone != null) phone, if (plan != null) plan, date]
                              .join(' · '),
                          style: TextStyle(fontSize: 9.sp, color: Colors.white54),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        )),
                      ]),
                    );
                  }),
                  SizedBox(height: 0.5.h),
                ]),
              );
            },
          ),
        ),
        // Merge button
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 3.h),
          child: SizedBox(
            width: double.infinity, height: 6.h,
            child: ElevatedButton.icon(
              onPressed: _isMerging ? null : _doMerge,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
              ),
              icon: _isMerging
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.merge_rounded, color: Colors.white, size: 16.sp),
              label: Text(
                _isMerging ? 'جاري الدمج...' : 'دمج وحذف $totalDupes سجل مكرر',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Preview Sheet ────────────────────────────────────────────────────────────
// Shows parsed rows with Firestore check results (new/existing).
// User can edit any row, then press "رفع" to actually write to Firebase.

class _PreviewSheet extends ConsumerStatefulWidget {
  final List<_UpsertRow> rows;
  final String gymId;
  final String addedByUid;
  final String fileName;
  final void Function(List<_RowResult>) onUploaded;

  const _PreviewSheet({
    required this.rows,
    required this.gymId,
    required this.addedByUid,
    required this.fileName,
    required this.onUploaded,
  });

  @override
  ConsumerState<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends ConsumerState<_PreviewSheet> {
  late List<_PreviewRow> _pRows;
  int _checkedCount = 0;
  bool _isUploading = false;
  int  _uploadedCount = 0;

  @override
  void initState() {
    super.initState();
    _pRows = widget.rows.map((r) => _PreviewRow(row: r)).toList();
    _runChecks();
  }

  // ── Check all rows against Firestore (read-only) ─────────────────────────
  Future<void> _runChecks() async {
    final repo = ref.read(adminRepositoryProvider);
    for (int i = 0; i < _pRows.length; i++) {
      final pr = _pRows[i];
      final r  = pr.row;
      try {
        final res = await repo.checkPlayerExists(
          gymId:     widget.gymId,
          email:     r.email.isEmpty     ? null : r.email,
          phone:     r.phone.isEmpty     ? null : r.phone,
          firstName: r.firstName.isEmpty ? null : r.firstName,
          lastName:  r.lastName.isEmpty  ? null : r.lastName,
        );
        if (mounted) setState(() {
          _pRows[i].checked      = true;
          _pRows[i].exists       = res.exists;
          _pRows[i].uid          = res.uid;
          _pRows[i].existingName = res.existingName;
          _checkedCount++;
        });
      } catch (_) {
        if (mounted) setState(() {
          _pRows[i].checked = true;
          _checkedCount++;
        });
      }
    }
  }

  // ── Upload all rows to Firebase ──────────────────────────────────────────
  Future<void> _upload() async {
    setState(() { _isUploading = true; _uploadedCount = 0; });
    final repo    = ref.read(adminRepositoryProvider);
    final results = <_RowResult>[];

    for (final pr in _pRows) {
      final row = pr.row;
      try {
        final res = await repo.upsertPlayerFromCsv(
          gymId:             widget.gymId,
          addedByUid:        widget.addedByUid,
          email:             row.email.isEmpty     ? null : row.email,
          phone:             row.phone.isEmpty     ? null : row.phone,
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
          wasUpdated: res.wasUpdated,
          playerId:   res.uid,
          row:        row,
        ));
      } catch (e) {
        results.add(_RowResult(
          name:    pr.displayName,
          detail:  '',
          success: false,
          error:   e.toString(),
          row:     row,
        ));
      }
      if (mounted) setState(() => _uploadedCount++);
    }

    if (mounted) {
      setState(() => _isUploading = false);
      ref.invalidate(adminPlayersProvider(widget.gymId));

      // ── Summary snackbar ─────────────────────────────────────────────────
      final successCount = results.where((r) => r.success).length;
      final failedCount  = results.where((r) => !r.success).length;
      final newCount     = results.where((r) => r.success && r.wasCreated).length;
      final updCount     = results.where((r) => r.success && !r.wasCreated && r.wasUpdated).length;
      final existCount   = results.where((r) => r.success && !r.wasCreated && !r.wasUpdated).length;
      final msg = failedCount == 0
          ? '✅ تم رفع $successCount سجل — $newCount جديد · $updCount محدّث · $existCount موجود'
          : '⚠️ $successCount ناجح · $failedCount فاشل — اضغط لرؤية التفاصيل';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: failedCount == 0 ? const Color(0xFF34C759) : const Color(0xFFFF9500),
        duration: const Duration(seconds: 5),
      ));

      // ── Save to history (only if something actually changed) ─────────────
      if (newCount > 0 || updCount > 0 || failedCount > 0) {
        try {
          await ref.read(adminRepositoryProvider).saveImportHistory(
            gymId:         widget.gymId,
            addedByUid:    widget.addedByUid,
            fileName:      widget.fileName,
            newCount:      newCount,
            updatedCount:  updCount,
            existingCount: existCount,
            failedCount:   failedCount,
          );
        } catch (_) { /* non-critical — don't block UX */ }
      }

      Navigator.pop(context);
      widget.onUploaded(results);
    }
  }

  // ── Edit dialog for one row ──────────────────────────────────────────────
  Future<void> _openEdit(int idx) async {
    final pr = _pRows[idx];
    final r  = pr.row;

    final firstCtrl  = TextEditingController(text: r.firstName);
    final lastCtrl   = TextEditingController(text: r.lastName);
    final phoneCtrl  = TextEditingController(text: r.phone);
    final planCtrl   = TextEditingController(text: r.subscriptionPlan ?? '');
    final totalCtrl  = TextEditingController(text: r.totalAmount?.toStringAsFixed(0) ?? '');
    final paidCtrl   = TextEditingController(text: r.amountPaid?.toStringAsFixed(0)  ?? '');
    final weightCtrl = TextEditingController(text: r.weight?.toStringAsFixed(1) ?? '');
    final heightCtrl = TextEditingController(text: r.height?.toStringAsFixed(1) ?? '');
    DateTime? subStart = r.subscriptionStart;
    DateTime? subEnd   = r.subscriptionEnd;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          Widget field(String label, TextEditingController ctrl, {TextInputType? type}) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: ctrl,
                keyboardType: type,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            );

          Widget dateRow(String label, DateTime? dt, ValueChanged<DateTime?> onPicked) =>
            GestureDetector(
              onTap: () async {
                final p = await showDatePicker(
                  context: ctx,
                  initialDate: dt ?? DateTime.now(),
                  firstDate: DateTime(2000), lastDate: DateTime(2100),
                );
                if (p != null) onPicked(p);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.white38, size: 14),
                  const SizedBox(width: 8),
                  Text(dt != null ? '${dt.day}/${dt.month}/${dt.year}' : label,
                    style: TextStyle(color: dt != null ? Colors.white : Colors.white38, fontSize: 13)),
                ]),
              ),
            );

          return Dialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('تعديل السجل',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 14),
                field('الاسم الأول', firstCtrl),
                field('الاسم الأخير', lastCtrl),
                field('الهاتف', phoneCtrl, type: TextInputType.phone),
                field('الخطة', planCtrl),
                field('المبلغ الكلي', totalCtrl, type: TextInputType.number),
                field('المدفوع', paidCtrl, type: TextInputType.number),
                field('الوزن', weightCtrl, type: TextInputType.number),
                field('الطول', heightCtrl, type: TextInputType.number),
                dateRow('تاريخ البداية', subStart, (d) => setSt(() => subStart = d)),
                dateRow('تاريخ الانتهاء', subEnd,   (d) => setSt(() => subEnd   = d)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء', style: TextStyle(color: Colors.white38)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _pRows[idx].row = _UpsertRow(
                          email:             r.email,
                          phone:             phoneCtrl.text.trim(),
                          firstName:         firstCtrl.text.trim(),
                          lastName:          lastCtrl.text.trim(),
                          subscriptionPlan:  planCtrl.text.trim().isEmpty ? null : planCtrl.text.trim(),
                          totalAmount:       double.tryParse(totalCtrl.text),
                          amountPaid:        double.tryParse(paidCtrl.text),
                          weight:            double.tryParse(weightCtrl.text),
                          height:            double.tryParse(heightCtrl.text),
                          subscriptionStart: subStart,
                          subscriptionEnd:   subEnd,
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5BA8FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  )),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newCount      = _pRows.where((r) => r.checked && !r.exists).length;
    final updateCount   = _pRows.where((r) => r.checked &&  r.exists).length;
    final pendingCount  = _pRows.where((r) => !r.checked).length;
    final allChecked    = _checkedCount >= _pRows.length;

    // Column widths for horizontal scroll
    const double wName   = 160;
    const double wPhone  = 120;
    const double wPlan   = 100;
    const double wStart  = 90;
    const double wEnd    = 90;
    const double wTotal  = 70;
    const double wPaid   = 70;
    const double wStatus = 60;
    const double wEdit   = 44;
    const double rowH    = 44.0;
    const double totalW  = wName + wPhone + wPlan + wStart + wEnd + wTotal + wPaid + wStatus + wEdit;

    Widget hCell(String t, double w) => SizedBox(
      width: w,
      child: Text(t, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: Colors.white30),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    Widget cell(String t, double w, {bool bold = false, Color? color}) => SizedBox(
      width: w,
      child: Text(t,
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? (bold ? Colors.white : Colors.white60))),
    );

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(
          margin: EdgeInsets.only(top: 1.h, bottom: 1.h),
          width: 12.w, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
        )),

        // Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مراجعة البيانات',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white)),
              SizedBox(height: 0.4.h),
              Row(children: [
                if (pendingCount > 0) ...[
                  _stag('جاري الفحص... $pendingCount', const Color(0xFFFF9500)),
                  SizedBox(width: 2.w),
                ],
                if (newCount > 0) ...[
                  _stag('$newCount جديد ✨', const Color(0xFF34C759)),
                  SizedBox(width: 2.w),
                ],
                if (updateCount > 0)
                  _stag('$updateCount موجود ✏️', const Color(0xFF5BA8FF)),
              ]),
            ])),
            // Check progress
            if (!allChecked)
              SizedBox(
                width: 8.w, height: 8.w,
                child: CircularProgressIndicator(
                  value: _pRows.isEmpty ? 0 : _checkedCount / _pRows.length,
                  color: const Color(0xFFFF9500),
                  strokeWidth: 2.5,
                ),
              ),
          ]),
        ),

        SizedBox(height: 1.h),

        // ── Horizontal-scrollable table ──────────────────────────────────
        // Header row
        Container(
          color: Colors.white.withOpacity(0.05),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              child: Row(children: [
                hCell('الاسم',    wName),
                hCell('الهاتف',   wPhone),
                hCell('الخطة',   wPlan),
                hCell('بداية',   wStart),
                hCell('نهاية',   wEnd),
                hCell('الكلي',   wTotal),
                hCell('دفع',     wPaid),
                hCell('الحالة',  wStatus),
                SizedBox(width: wEdit),
              ]),
            ),
          ),
        ),

        // Data rows
        Expanded(
          child: ListView.builder(
            itemCount: _pRows.length,
            itemExtent: rowH,
            itemBuilder: (ctx, i) {
              final pr = _pRows[i];
              final r  = pr.row;
              final df = DateFormat('dd/MM/yy');

              Color statusColor = pr.checked
                  ? (pr.exists ? const Color(0xFF5BA8FF) : const Color(0xFF34C759))
                  : Colors.white24;
              String statusLabel = pr.checked
                  ? (pr.exists ? '✏️' : '✨')
                  : '⏳';

              return Container(
                decoration: BoxDecoration(
                  color: i.isOdd ? Colors.white.withOpacity(0.02) : Colors.transparent,
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalW,
                    child: Row(children: [
                      cell('${r.firstName} ${r.lastName}'.trim(), wName, bold: true),
                      cell(r.phone.isEmpty ? '—' : r.phone, wPhone),
                      cell(r.subscriptionPlan ?? '—', wPlan),
                      cell(r.subscriptionStart != null ? df.format(r.subscriptionStart!) : '—', wStart),
                      cell(r.subscriptionEnd   != null ? df.format(r.subscriptionEnd!)   : '—', wEnd),
                      cell(r.totalAmount != null ? r.totalAmount!.toStringAsFixed(0) : '—', wTotal),
                      cell(r.amountPaid  != null ? r.amountPaid!.toStringAsFixed(0)  : '—', wPaid),
                      SizedBox(
                        width: wStatus,
                        child: Text(statusLabel,
                          style: TextStyle(fontSize: 16.sp, color: statusColor),
                          textAlign: TextAlign.center),
                      ),
                      // Edit button
                      GestureDetector(
                        onTap: () => _openEdit(i),
                        child: Container(
                          width: wEdit,
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.edit_rounded, size: 13.sp, color: Colors.white38),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Upload button ────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(4.w, 1.2.h, 4.w, 3.h),
          decoration: const BoxDecoration(
            color: Color(0xFF0A0A0F),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: _isUploading
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('جاري الرفع... $_uploadedCount / ${_pRows.length}',
                    style: TextStyle(fontSize: 11.sp, color: Colors.white54)),
                  SizedBox(height: 1.h),
                  LinearProgressIndicator(
                    value: _pRows.isEmpty ? 0 : _uploadedCount / _pRows.length,
                    color: const Color(0xFFFF3B30),
                    backgroundColor: Colors.white12,
                  ),
                ])
              : SizedBox(
                  width: double.infinity, height: 6.h,
                  child: ElevatedButton.icon(
                    onPressed: allChecked ? _upload : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      disabledBackgroundColor: Colors.white12,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
                    ),
                    icon: Icon(Icons.cloud_upload_rounded, size: 16.sp, color: Colors.white),
                    label: Text(
                      allChecked
                          ? 'رفع ${_pRows.length} سجل للفايربيس ($newCount جديد · $updateCount تحديث)'
                          : 'جاري الفحص...',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
        ),
      ]),
    );
  }

  static Widget _stag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: c.withOpacity(0.13), borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: c)),
  );
}

// ─── Results Sheet ────────────────────────────────────────────────────────────

class _ResultsSheet extends ConsumerStatefulWidget {
  final List<_RowResult> results;
  final String gymId;
  final String addedByUid;
  const _ResultsSheet({required this.results, required this.gymId, required this.addedByUid});

  @override
  ConsumerState<_ResultsSheet> createState() => _ResultsSheetState();
}

class _ResultsSheetState extends ConsumerState<_ResultsSheet> {
  late List<_RowResult> _results;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _results = List.of(widget.results);
  }

  String _buildCopyText() {
    final created  = _results.where((r) => r.success && r.wasCreated);
    final updated  = _results.where((r) => r.success && !r.wasCreated && r.wasUpdated);
    final existing = _results.where((r) => r.success && !r.wasCreated && !r.wasUpdated);
    final failed   = _results.where((r) => !r.success);
    final buf = StringBuffer();
    if (created.isNotEmpty) {
      buf.writeln('=== مضافون جدد ===');
      for (final r in created) buf.writeln('${r.name} | ${r.detail}');
      buf.writeln();
    }
    if (updated.isNotEmpty) {
      buf.writeln('=== تم تحديثهم ===');
      for (final r in updated) buf.writeln('${r.name} | ${r.detail}');
      buf.writeln();
    }
    if (existing.isNotEmpty) {
      buf.writeln('=== موجودون (بدون تغيير) ===');
      for (final r in existing) buf.writeln('${r.name}');
      buf.writeln();
    }
    if (failed.isNotEmpty) {
      buf.writeln('=== فاشلون ===');
      for (final r in failed) buf.writeln('${r.name} | ${r.error}');
    }
    return buf.toString();
  }

  // ── Retry ONLY failed rows ────────────────────────────────────────────────
  Future<void> _retryFailed() async {
    setState(() => _isRetrying = true);
    final repo = ref.read(adminRepositoryProvider);
    for (int i = 0; i < _results.length; i++) {
      final r = _results[i];
      if (r.success || r.row == null) continue; // skip successful rows
      final row = r.row!;
      try {
        final res = await repo.upsertPlayerFromCsv(
          gymId:             widget.gymId,
          addedByUid:        widget.addedByUid,
          email:             row.email.isEmpty     ? null : row.email,
          phone:             row.phone.isEmpty     ? null : row.phone,
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
        setState(() {
          _results[i] = _RowResult(
            name:       res.name,
            detail:     row.displayId,
            success:    true,
            wasCreated: res.wasCreated,
            wasUpdated: res.wasUpdated,
            playerId:   res.uid,
            row:        row,
          );
        });
      } catch (e) {
        setState(() {
          _results[i] = _RowResult(
            name:    r.name,
            detail:  '',
            success: false,
            error:   e.toString(),
            row:     row,
          );
        });
      }
    }
    if (mounted) {
      setState(() => _isRetrying = false);
      ref.invalidate(adminPlayersProvider(widget.gymId));
    }
  }

  // ── Edit dialog — saves locally only, upload happens via _uploadPendingEdits ─
  Future<void> _openEditDialog(int idx) async {
    final r   = _results[idx];
    final row = r.row;

    final firstCtrl  = TextEditingController(text: row?.firstName ?? r.name.split(' ').first);
    final lastCtrl   = TextEditingController(text: row?.lastName  ?? (r.name.split(' ')..removeAt(0)).join(' '));
    final phoneCtrl  = TextEditingController(text: row?.phone     ?? r.detail);
    final planCtrl   = TextEditingController(text: row?.subscriptionPlan ?? '');
    final totalCtrl  = TextEditingController(text: row?.totalAmount?.toStringAsFixed(0) ?? '');
    final paidCtrl   = TextEditingController(text: row?.amountPaid?.toStringAsFixed(0)  ?? '');
    final weightCtrl = TextEditingController(text: row?.weight?.toStringAsFixed(1) ?? '');
    final heightCtrl = TextEditingController(text: row?.height?.toStringAsFixed(1) ?? '');
    DateTime? subStart = row?.subscriptionStart;
    DateTime? subEnd   = row?.subscriptionEnd;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          Widget field(String label, TextEditingController ctrl, {TextInputType? type}) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: ctrl,
                keyboardType: type,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            );

          Widget dateRow(String label, DateTime? dt, ValueChanged<DateTime?> onPicked) =>
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: dt ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) onPicked(picked);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.white38, size: 16),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    dt != null ? '${dt.day}/${dt.month}/${dt.year}' : label,
                    style: TextStyle(color: dt != null ? Colors.white : Colors.white38, fontSize: 14),
                  )),
                ]),
              ),
            );

          return Dialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('تعديل بيانات اللاعب',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(r.name, style: TextStyle(fontSize: 12.sp, color: Colors.white38)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('سيتم الرفع عند الضغط على زر "رفع المعدّلين"',
                    style: TextStyle(fontSize: 10.sp, color: const Color(0xFFFF9500))),
                ),
                const SizedBox(height: 14),
                field('الاسم الأول', firstCtrl),
                field('الاسم الأخير', lastCtrl),
                field('رقم الهاتف', phoneCtrl, type: TextInputType.phone),
                field('الخطة', planCtrl),
                field('المبلغ الكلي', totalCtrl, type: TextInputType.number),
                field('المبلغ المدفوع', paidCtrl, type: TextInputType.number),
                field('الوزن (kg)', weightCtrl, type: TextInputType.number),
                field('الطول (cm)', heightCtrl, type: TextInputType.number),
                dateRow('تاريخ البداية', subStart, (d) => setSt(() => subStart = d)),
                dateRow('تاريخ الانتهاء', subEnd,   (d) => setSt(() => subEnd   = d)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء', style: TextStyle(color: Colors.white38)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Save locally only — no Firebase call here
                        final newRow = _UpsertRow(
                          firstName:         firstCtrl.text.trim(),
                          lastName:          lastCtrl.text.trim(),
                          phone:             phoneCtrl.text.trim(),
                          subscriptionPlan:  planCtrl.text.trim().isEmpty ? null : planCtrl.text.trim(),
                          totalAmount:       double.tryParse(totalCtrl.text),
                          amountPaid:        double.tryParse(paidCtrl.text),
                          weight:            double.tryParse(weightCtrl.text),
                          height:            double.tryParse(heightCtrl.text),
                          subscriptionStart: subStart,
                          subscriptionEnd:   subEnd,
                          email:             row?.email ?? '',
                        );
                        setState(() {
                          _results[idx] = _RowResult(
                            name:          '${newRow.firstName} ${newRow.lastName}'.trim(),
                            detail:        newRow.phone.isNotEmpty ? newRow.phone : r.detail,
                            success:       r.success,
                            wasCreated:    r.wasCreated,
                            wasUpdated:    r.wasUpdated,
                            error:         r.error,
                            playerId:      r.playerId,
                            row:           newRow,
                            isPendingEdit: true,
                          );
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9500),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('حفظ محلياً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Upload all locally-edited rows to Firebase ───────────────────────────
  Future<void> _uploadPendingEdits() async {
    final pendingIdx = _results.asMap().entries
        .where((e) => e.value.isPendingEdit)
        .map((e) => e.key)
        .toList();
    if (pendingIdx.isEmpty) return;

    setState(() => _isRetrying = true);
    final repo = ref.read(adminRepositoryProvider);

    for (final idx in pendingIdx) {
      final r   = _results[idx];
      final row = r.row;
      if (row == null) continue;
      try {
        if (r.playerId != null && r.playerId!.isNotEmpty) {
          // Existing player → update directly
          final fields = <String, dynamic>{
            'firstName': row.firstName,
            'lastName':  row.lastName,
            'phone':     row.phone,
            if (row.subscriptionPlan  != null) 'subscriptionPlan':  row.subscriptionPlan,
            if (row.totalAmount       != null) 'totalAmount':       row.totalAmount,
            if (row.amountPaid        != null) 'amountPaid':        row.amountPaid,
            if (row.weight            != null) 'weight':            row.weight,
            if (row.height            != null) 'height':            row.height,
            if (row.subscriptionStart != null) 'subscriptionStart': Timestamp.fromDate(row.subscriptionStart!),
            if (row.subscriptionEnd   != null) 'subscriptionEnd':   Timestamp.fromDate(row.subscriptionEnd!),
          };
          await repo.updatePlayerFields(r.playerId!, fields);
          setState(() {
            _results[idx] = _RowResult(
              name:       r.name,
              detail:     r.detail,
              success:    true,
              wasCreated: r.wasCreated,
              wasUpdated: true,
              playerId:   r.playerId,
              row:        row,
            );
          });
        } else {
          // Failed row → upsert
          final res = await repo.upsertPlayerFromCsv(
            gymId:             widget.gymId,
            addedByUid:        widget.addedByUid,
            email:             row.email.isEmpty     ? null : row.email,
            phone:             row.phone.isEmpty     ? null : row.phone,
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
          setState(() {
            _results[idx] = _RowResult(
              name:       res.name,
              detail:     row.displayId,
              success:    true,
              wasCreated: res.wasCreated,
              wasUpdated: true,
              playerId:   res.uid,
              row:        row,
            );
          });
        }
      } catch (e) {
        setState(() {
          _results[idx] = _RowResult(
            name:          r.name,
            detail:        r.detail,
            success:       false,
            error:         e.toString(),
            row:           row,
            isPendingEdit: true, // keep pending — let user fix and retry
          );
        });
      }
    }

    if (mounted) {
      setState(() => _isRetrying = false);
      ref.invalidate(adminPlayersProvider(widget.gymId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '✅ تم رفع ${pendingIdx.length} لاعب معدّل',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: const Color(0xFF34C759),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final created      = _results.where((r) => r.success && r.wasCreated && !r.isPendingEdit).toList();
    final updated      = _results.where((r) => r.success && !r.wasCreated && r.wasUpdated && !r.isPendingEdit).toList();
    final existing     = _results.where((r) => r.success && !r.wasCreated && !r.wasUpdated && !r.isPendingEdit).toList();
    final failed       = _results.where((r) => !r.success && !r.isPendingEdit).toList();
    final pendingEdits = _results.where((r) => r.isPendingEdit).toList();
    final pendingCount = pendingEdits.length;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 1.h, bottom: 1.5.h),
              width: 12.w, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('النتائج',
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white)),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (created.isNotEmpty)      _tag('${created.length} جديد',        const Color(0xFF34C759)),
                      if (updated.isNotEmpty)      _tag('${updated.length} محدّث',       const Color(0xFF5BA8FF)),
                      if (existing.isNotEmpty)     _tag('${existing.length} موجود',      Colors.white38),
                      if (failed.isNotEmpty)       _tag('${failed.length} خطأ',          const Color(0xFFFF3B30)),
                      if (pendingCount > 0)        _tag('⏳ $pendingCount معدّل محلياً', const Color(0xFFFF9500)),
                    ]),
                  ]),
                ),
                // Share
                _iconBtn(
                  icon: Icons.share_rounded,
                  color: const Color(0xFF34C759),
                  label: 'مشاركة',
                  onTap: () => SharePlus.instance.share(
                    ShareParams(text: _buildCopyText(), subject: 'نتائج الاستيراد'),
                  ),
                ),
                SizedBox(width: 2.w),
                // Copy
                _iconBtn(
                  icon: Icons.copy_rounded,
                  color: const Color(0xFF5BA8FF),
                  label: 'نسخ',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _buildCopyText()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم النسخ ✅')));
                  },
                ),
              ],
            ),
          ),
          // ── Upload pending edits button ────────────────────────────────────
          if (pendingCount > 0) Padding(
            padding: EdgeInsets.fromLTRB(4.w, 1.2.h, 4.w, 0),
            child: SizedBox(
              width: double.infinity, height: 5.5.h,
              child: ElevatedButton.icon(
                onPressed: _isRetrying ? null : _uploadPendingEdits,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5BA8FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
                ),
                icon: _isRetrying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.cloud_upload_rounded, size: 16.sp, color: Colors.white),
                label: Text(
                  _isRetrying ? 'جاري الرفع...' : 'رفع $pendingCount لاعب معدّل',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
          // ── Retry failed rows (only shown when there are failures) ─────────
          if (failed.isNotEmpty) Padding(
            padding: EdgeInsets.fromLTRB(4.w, 0.8.h, 4.w, 0),
            child: SizedBox(
              width: double.infinity, height: 5.5.h,
              child: ElevatedButton.icon(
                onPressed: _isRetrying ? null : _retryFailed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3.w)),
                ),
                icon: _isRetrying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.cloud_upload_rounded, size: 16.sp, color: Colors.white),
                label: Text(
                  _isRetrying
                      ? 'جاري الرفع...'
                      : 'إعادة رفع الفاشلين (${failed.length} سجل)',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),
          SizedBox(height: 1.h),
          // ── Table header ─────────────────────────────────────────────────
          Container(
            color: Colors.white.withOpacity(0.04),
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 0.8.h),
            child: Row(children: [
              _th('الاسم', flex: 3),
              _th('الجوال / البريد', flex: 4),
              _th('', flex: 2),
            ]),
          ),
          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(bottom: 3.h),
              itemCount: _results.length,
              itemBuilder: (ctx, i) {
                final r = _results[i];
                Color leftColor = r.isPendingEdit
                    ? const Color(0xFFFF9500)            // معدّل محلياً → برتقالي
                    : r.success
                        ? (r.wasCreated
                            ? const Color(0xFF34C759)    // جديد → أخضر
                            : (r.wasUpdated
                                ? const Color(0xFF5BA8FF)// محدّث → أزرق
                                : Colors.white24))       // موجود → رمادي
                        : const Color(0xFFFF3B30);       // خطأ → أحمر

                return Container(
                  decoration: BoxDecoration(
                    color: r.isPendingEdit
                        ? const Color(0xFFFF9500).withOpacity(0.06)
                        : r.success ? Colors.transparent : Colors.red.withOpacity(0.06),
                    border: Border(
                      left: BorderSide(color: leftColor, width: 3),
                      bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                  child: Row(children: [
                    _tdw(r.name, flex: 3, bold: true),
                    if (r.isPendingEdit) ...[
                      _tdw(r.detail, flex: 4, color: Colors.white60),
                      Expanded(
                        flex: 2,
                        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text('⏳', style: TextStyle(fontSize: 14.sp)),
                          SizedBox(width: 2.w),
                          GestureDetector(
                            onTap: () => _openEditDialog(i),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit_rounded, size: 14.sp, color: const Color(0xFFFF9500)),
                            ),
                          ),
                        ]),
                      ),
                    ] else if (r.success) ...[
                      _tdw(r.detail, flex: 4, color: Colors.white60),
                      Expanded(
                        flex: 2,
                        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text(r.wasCreated ? '✨' : (r.wasUpdated ? '✏️' : '✓'),
                              style: TextStyle(fontSize: 14.sp, color: r.wasUpdated ? null : Colors.white38)),
                          SizedBox(width: 2.w),
                          GestureDetector(
                            onTap: () => _openEditDialog(i),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit_rounded, size: 14.sp, color: Colors.white54),
                            ),
                          ),
                        ]),
                      ),
                    ] else ...[
                      Expanded(
                        flex: 5,
                        child: Row(children: [
                          Expanded(
                            child: Text('❌ ${r.error ?? 'خطأ'}',
                              style: TextStyle(fontSize: 10.sp, color: const Color(0xFFFF3B30)),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ),
                          GestureDetector(
                            onTap: () => _openEditDialog(i),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5BA8FF).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit_rounded, size: 14.sp, color: const Color(0xFF5BA8FF)),
                            ),
                          ),
                        ]),
                      ),
                    ],
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: c)),
  );

  static Widget _iconBtn({required IconData icon, required Color color, required String label, required VoidCallback onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, color: color, size: 13.sp),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );

  static Widget _th(String t, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(t, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: Colors.white30)),
  );

  static Widget _tdw(String t, {int flex = 1, bool bold = false, Color? color}) => Expanded(
    flex: flex,
    child: Text(t,
      maxLines: 1, overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? (bold ? Colors.white : Colors.white54))),
  );
}
