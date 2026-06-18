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
