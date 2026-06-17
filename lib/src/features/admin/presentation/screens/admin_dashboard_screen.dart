import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/role_utils.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/models/user_model.dart';
import '../views/admin_overview_view.dart';
import '../views/admin_players_view.dart';
import '../views/admin_finance_view.dart';
import '../views/admin_notifications_view.dart';
import '../views/admin_more_view.dart';

class AdminBottomNavNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final adminBottomNavProvider = NotifierProvider<AdminBottomNavNotifier, int>(
  AdminBottomNavNotifier.new,
);

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(adminBottomNavProvider);

    // Guard: Only admins/owners/gymAdmins can stay here
    ref.listen<AsyncValue<UserModel?>>(currentUserModelProvider, (_, next) {
      final role = next.asData?.value?.role?.toLowerCase();
      if (next.hasValue && role != AppRole.admin && role != AppRole.owner && role != AppRole.gymAdmin) {
        context.go('/dashboard');
      }
    });

    final userModel = ref.watch(currentUserModelProvider).asData?.value;
    final userRole = userModel?.role?.toLowerCase();
    if (userModel != null && userRole != AppRole.admin && userRole != AppRole.owner && userRole != AppRole.gymAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: const [
              AdminOverviewView(),
              AdminPlayersView(),
              AdminFinanceView(),
              AdminNotificationsView(),
              AdminMoreView(),
            ],
          ),
          _buildBottomNav(context, ref, currentIndex),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, WidgetRef ref, int currentIndex) {
    return PositionedDirectional(
      bottom: 0,
      start: 0,
      end: 0,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0F).withOpacity(0.95),
          border: const Border(top: BorderSide(color: Colors.white12, width: 0.5)),
        ),
        padding: EdgeInsets.only(
            bottom: 1.5.h +
                (Theme.of(context).platform == TargetPlatform.android
                    ? MediaQuery.of(context).padding.bottom * 0.5
                    : 0),
            top: 1.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(ref: ref, index: 0, currentIndex: currentIndex, icon: Icons.dashboard_rounded, label: 'Overview'),
            _buildNavItem(ref: ref, index: 1, currentIndex: currentIndex, icon: Icons.people_alt_rounded, label: 'Players'),
            _buildNavItem(ref: ref, index: 2, currentIndex: currentIndex, icon: Icons.account_balance_wallet_rounded, label: 'Finance'),
            _buildNavItem(ref: ref, index: 3, currentIndex: currentIndex, icon: Icons.notifications_rounded, label: 'Notifs'),
            _buildNavItem(ref: ref, index: 4, currentIndex: currentIndex, icon: Icons.grid_view_rounded, label: 'More'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required WidgetRef ref,
    required int index,
    required int currentIndex,
    required IconData icon,
    required String label,
  }) {
    final isSelected = index == currentIndex;
    final color = isSelected ? const Color(0xFFFF3B30) : Colors.white30;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(adminBottomNavProvider.notifier).setIndex(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22.sp),
          SizedBox(height: 0.5.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (isSelected) ...[
            SizedBox(height: 0.5.h),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle)),
          ] else
            SizedBox(height: 0.5.h + 4),
        ],
      ),
    );
  }
}
