import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';

import '../../../auth/data/auth_repository.dart';
import '../../data/super_admin_service.dart';
import 'create_gym_screen.dart';
import 'super_admin_gym_detail_screen.dart';
import 'super_admin_sent_messages_screen.dart';

class SuperAdminDashboardScreen extends ConsumerWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserModelProvider).asData?.value;
    final gymsAsync = ref.watch(allGymsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopbar(context, ref, user?.firstName ?? 'Super Admin'),
            Expanded(
              child: gymsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF3B30)),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'خطأ: $e',
                    style: TextStyle(color: Colors.white54, fontSize: 10.sp),
                  ),
                ),
                data: (gyms) => gyms.isEmpty
                    ? _buildEmpty(context)
                    : _buildGymList(context, ref, gyms),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF3B30),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateGymScreen()),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'نادي جديد',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Topbar ────────────────────────────────────────────────────────────────

  Widget _buildTopbar(BuildContext context, WidgetRef ref, String name) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 1.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUPER ADMIN',
                style: TextStyle(
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF3B30).withOpacity(0.7),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'App Control Center 🔑',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _showBroadcastSheet(context, ref),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.campaign_rounded,
                          color: const Color(0xFFFF9500),
                          size: 11.sp),
                      SizedBox(width: 1.w),
                      Text(
                        'إشعار عام',
                        style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFF9500)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SuperAdminSentMessagesScreen(),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5BA8FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.send_rounded,
                          color: const Color(0xFF5BA8FF),
                          size: 11.sp),
                      SizedBox(width: 1.w),
                      Text(
                        'الرسائل المرسلة',
                        style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF5BA8FF)),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              GestureDetector(
                onTap: () => ref.read(authRepositoryProvider).signOut(),
                child: Container(
                  padding: EdgeInsets.all(2.5.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    color: Colors.white54,
                    size: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Gym list ──────────────────────────────────────────────────────────────

  Widget _buildGymList(
      BuildContext context, WidgetRef ref, List<Map<String, dynamic>> gyms) {
    return ListView(
      padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 12.h),
      children: [
        _buildStatsStrip(gyms.length),
        SizedBox(height: 2.h),
        Text(
          'الأندية (${gyms.length})',
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white54,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 1.h),
        ...gyms.map((gym) => _buildGymCard(context, ref, gym)),
      ],
    );
  }

  Widget _buildStatsStrip(int total) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFC0392B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Row(
        children: [
          _stripStat(total.toString(), 'إجمالي الأندية'),
          _vDivider(),
          _stripStat('نشط', 'الحالة'),
          _vDivider(),
          _stripStat('∞', 'السعة'),
        ],
      ),
    );
  }

  Widget _stripStat(String val, String lbl) => Expanded(
        child: Column(
          children: [
            Text(
              val,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              lbl,
              style: TextStyle(
                fontSize: 7.sp,
                color: Colors.white60,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _vDivider() => Container(
        width: 0.5,
        height: 5.h,
        color: Colors.white24,
        margin: EdgeInsets.symmetric(horizontal: 2.w),
      );

  Widget _buildGymCard(
      BuildContext context, WidgetRef ref, Map<String, dynamic> gym) {
    final name     = gym['name'] as String? ?? 'Unknown';
    final id       = gym['id'] as String? ?? '';
    final city     = gym['city'] as String? ?? '';
    final isActive = gym['isActive'] as bool? ?? true;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SuperAdminGymDetailScreen(gym: gym),
        ),
      ),
      child: Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
        borderRadius: BorderRadius.circular(4.w),
      ),
      child: Row(
        children: [
          Container(
            width: 11.w,
            height: 11.w,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.15),
              borderRadius: BorderRadius.circular(3.w),
            ),
            alignment: Alignment.center,
            child: Text('🏋️', style: TextStyle(fontSize: 14.sp)),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  'ID: $id  •  $city',
                  style: TextStyle(
                    fontSize: 8.sp,
                    color: Colors.white38,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF34C759).withOpacity(0.15)
                  : Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'نشط' : 'موقوف',
              style: TextStyle(
                fontSize: 8.sp,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF3B30),
              ),
            ),
          ),
          SizedBox(width: 2.w),
          Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 16.sp),
        ],
      ),
      ),
    );
  }

  // ── Broadcast sheet ───────────────────────────────────────────────────────

  void _showBroadcastSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BroadcastSheet(),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏗️', style: TextStyle(fontSize: 40.sp)),
          SizedBox(height: 2.h),
          Text(
            'لا يوجد أندية بعد',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'اضغط + لإنشاء أول نادي',
            style: TextStyle(fontSize: 11.sp, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

// ─── Broadcast Sheet ──────────────────────────────────────────────────────────

class _BroadcastSheet extends StatefulWidget {
  const _BroadcastSheet();

  @override
  State<_BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends State<_BroadcastSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  bool _loading    = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء العنوان والنص')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('broadcastToAllUsers');
      final result = await fn.call({
        'title': title,
        'body':  body,
        'type':  'broadcast',
        'route': '/dashboard',
      });
      final sentCount = (result.data as Map?)?['sentCount'] ?? 0;
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم الإرسال إلى $sentCount مستخدم'),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: const Color(0xFFFF3B30),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 5.w,
        right: 5.w,
        top: 2.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 3.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 10.w,
              height: 0.4.h,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 2.h),

          // Header
          Row(children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500).withOpacity(0.12),
                borderRadius: BorderRadius.circular(2.w),
              ),
              child: Icon(Icons.campaign_rounded,
                  color: const Color(0xFFFF9500), size: 14.sp),
            ),
            SizedBox(width: 3.w),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('إشعار عام 📢',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800)),
              Text('سيصل لجميع مستخدمي التطبيق',
                  style: TextStyle(color: Colors.white38, fontSize: 9.sp)),
            ]),
          ]),
          SizedBox(height: 2.5.h),

          // Title field
          _label('العنوان'),
          SizedBox(height: 0.8.h),
          _field(_titleCtrl, 'مثال: تحديث جديد في التطبيق 🎉', maxLines: 1),
          SizedBox(height: 1.5.h),

          // Body field
          _label('النص'),
          SizedBox(height: 0.8.h),
          _field(_bodyCtrl, 'اكتب محتوى الإشعار هنا...', maxLines: 4),
          SizedBox(height: 2.h),

          // Warning banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.08),
              borderRadius: BorderRadius.circular(2.w),
              border: Border.all(
                  color: const Color(0xFFFF9500).withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: const Color(0xFFFF9500), size: 12.sp),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'سيتلقى هذا الإشعار جميع المدربين والمشرفين والمشتركين في جميع الأندية.',
                  style: TextStyle(
                      color: const Color(0xFFFF9500).withOpacity(0.8),
                      fontSize: 9.sp,
                      height: 1.4),
                ),
              ),
            ]),
          ),
          SizedBox(height: 2.h),

          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                disabledBackgroundColor: Colors.white12,
                padding: EdgeInsets.symmetric(vertical: 1.8.h),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3.w)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('إرسال للجميع',
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

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
            color: Colors.white54,
            fontSize: 9.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3),
      );

  Widget _field(TextEditingController ctrl, String hint,
      {required int maxLines}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(color: Colors.white, fontSize: 12.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white24, fontSize: 11.sp),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2.5.w),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2.5.w),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2.5.w),
            borderSide:
                const BorderSide(color: Color(0xFFFF9500), width: 1.2),
          ),
        ),
      );
}
