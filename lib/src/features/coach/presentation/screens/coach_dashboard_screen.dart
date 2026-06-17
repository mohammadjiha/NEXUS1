import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/role_utils.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/models/user_model.dart';
import 'coach_home_view.dart';
import 'coach_messages_view.dart';
import 'coach_players_view.dart';

class CoachBottomNavNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final coachBottomNavProvider = NotifierProvider<CoachBottomNavNotifier, int>(
  CoachBottomNavNotifier.new,
);

class CoachDashboardScreen extends ConsumerWidget {
  const CoachDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(coachBottomNavProvider);

    // ── Backend role guard ────────────────────────────────────────────────────
    // GoRouter redirect is client-side only. We re-validate the role from the
    // live Firestore stream so a downgraded account is ejected immediately,
    // even if the user is already on this screen.
    ref.listen<AsyncValue<UserModel?>>(currentUserModelProvider, (_, next) {
      final role = next.asData?.value?.role;
      if (next.hasValue && !AppRole.isPrivileged(role)) {
        context.go('/dashboard');
      }
    });

    // Synchronous guard for initial render (stream already resolved)
    final userModel = ref.watch(currentUserModelProvider).asData?.value;
    if (userModel != null && !AppRole.isPrivileged(userModel.role)) {
      // Role was revoked — redirect on next frame to avoid build-phase navigation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F7),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    // ─────────────────────────────────────────────────────────────────────────

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5EA), // Light grey background like HTML
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: const [
              CoachHomeView(),
              CoachPlayersView(),
              CoachMessagesView(),
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
          color: const Color(0xFFF5F5F7).withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
        ),
        padding: EdgeInsets.only(bottom: 1.5.h + (Theme.of(context).platform == TargetPlatform.android ? MediaQuery.of(context).padding.bottom * 0.5 : 0), top: 0.5.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              ref: ref,
              index: 0,
              currentIndex: currentIndex,
              icon: Icons.home_rounded,
              label: 'nav_home'.tr(context),
            ),
            _buildNavItem(
              ref: ref,
              index: 1,
              currentIndex: currentIndex,
              icon: Icons.people_alt_rounded,
              label: 'coach_players'.tr(context),
            ),
            _buildNavItem(
              ref: ref,
              index: 2,
              currentIndex: currentIndex,
              icon: Icons.chat_bubble_rounded,
              label: 'coach_messages'.tr(context),
            ),
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
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(coachBottomNavProvider.notifier).setIndex(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 1.h),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20.sp,
              color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
            ),
            SizedBox(height: 0.5.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}
