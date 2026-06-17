import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../../core/localization/app_localizations.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/models/user_model.dart';
import '../../data/repositories/community_repository.dart';
import '../../domain/models/challenge_model.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/models/post_model.dart';

// Basic state for the tabs
class CommunityTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) => state = index;
}

final communityTabProvider = NotifierProvider<CommunityTabNotifier, int>(
  CommunityTabNotifier.new,
);

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(communityTabProvider);
    final userModel = ref.watch(currentUserModelProvider).asData?.value;
    final canCreateChallenge = _canCreateChallenge(userModel?.role);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            _buildTabs(ref, context),
            Expanded(child: _buildFeed(context, ref)),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 9.h),
        child: FloatingActionButton(
          onPressed: () {
            if (currentTab == 2) {
              if (!canCreateChallenge) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('only_gym_owners_add_challenges'.tr(context)),
                  ),
                );
                return;
              }
              _showCreateChallengeBottomSheet(context, ref);
              return;
            }
            _showCreatePostBottomSheet(context, ref);
          },
          backgroundColor: const Color(0xFF1C1C1E),
          child: Icon(Icons.add_rounded, color: Colors.white, size: 22.sp),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "${'nav_community'.tr(context)} 🌍",
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1C1E),
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              _buildIconButton(Icons.search_rounded),
              SizedBox(width: 2.w),
              _buildIconButton(Icons.notifications_none_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon) {
    return Container(
      width: 10.w,
      height: 10.w,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Icon(icon, size: 16.sp, color: const Color(0xFF1C1C1E)),
    );
  }

  Widget _buildTabs(WidgetRef ref, BuildContext context) {
    final currentTab = ref.watch(communityTabProvider);
    return Builder(
      builder: (context) {
        final tabs = [
          'tab_all'.tr(context),
          'tab_following'.tr(context),
          'tab_challenges'.tr(context),
          'tab_rankings'.tr(context),
        ];
        return Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 1.h),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = currentTab == index;
                return GestureDetector(
                  onTap: () =>
                      ref.read(communityTabProvider.notifier).setTab(index),
                  child: Container(
                    margin: EdgeInsetsDirectional.only(end: 4.w),
                    padding: EdgeInsets.symmetric(
                      vertical: 1.h,
                      horizontal: 3.w,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? const Color(0xFF1C1C1E)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF1C1C1E)
                            : const Color(0xFF8E8E93),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeed(BuildContext context, WidgetRef ref) {
    final tabIndex = ref.watch(communityTabProvider);
    final userModel = ref.watch(currentUserModelProvider).asData?.value;
    final gymId = userModel?.gymId?.trim();

    if (gymId == null || gymId.isEmpty) {
      return Center(
        child: Text(
          'join_gym_community'.tr(context),
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
        ),
      );
    }

    if (tabIndex == 2) {
      return _buildChallenges(context, ref, gymId, userModel);
    }

    if (tabIndex == 3) {
      return _buildLeaderboard(context, ref, gymId, userModel);
    }

    if (tabIndex != 0) {
      return Center(
        child: Text(
          'feature_coming_soon'.tr(context),
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
        ),
      );
    }

    final postsAsync = ref.watch(postsStreamProvider(gymId));
    final challengesAsync = ref.watch(challengesStreamProvider(gymId));

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
      ),
      error: (e, st) =>
          Center(child: Text("${'error_loading_posts'.tr(context)}$e")),
      data: (posts) {
        Challenge? activeChallenge;
        final challenges = challengesAsync.asData?.value ?? const <Challenge>[];
        for (final challenge in challenges) {
          if (challenge.status == 'active') {
            activeChallenge = challenge;
            break;
          }
        }
        return CustomScrollView(
          slivers: [
            if (activeChallenge != null)
              SliverPadding(
                padding: EdgeInsets.only(top: 2.h, bottom: 2.h),
                sliver: SliverToBoxAdapter(
                  child: _buildFirebaseChallengeBanner(
                    activeChallenge,
                    context,
                  ),
                ),
              ),
            if (posts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.forum_rounded,
                        size: 40.sp,
                        color: const Color(0xFFD1D1D6),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'no_posts_yet'.tr(context),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        'be_first_share'.tr(context),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = posts[index];
                  return _buildPostCard(
                    context,
                    ref,
                    post,
                    userModel?.uid ?? '',
                  );
                }, childCount: posts.length),
              ),
            SliverPadding(padding: EdgeInsets.only(bottom: 12.h)),
          ],
        );
      },
    );
  }

  Widget _buildFirebaseChallengeBanner(
    Challenge challenge,
    BuildContext context,
  ) {
    final daysLeft = challenge.endDate
        ?.difference(DateTime.now())
        .inDays
        .clamp(0, 999);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(4.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2.w,
                height: 2.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 2.w),
              Text(
                daysLeft == null
                    ? 'active_challenge_upper'.tr(context)
                    : "${'active_challenge_upper'.tr(context)} · $daysLeft ${'days_left_upper'.tr(context)}",
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(
            challenge.title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            challenge.description,
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            height: 1.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.45,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(2.w),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallenges(
    BuildContext context,
    WidgetRef ref,
    String gymId,
    UserModel? userModel,
  ) {
    final challengesAsync = ref.watch(challengesStreamProvider(gymId));

    return challengesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
      ),
      error: (e, st) =>
          Center(child: Text("${'error_loading_challenges'.tr(context)}$e")),
      data: (challenges) {
        if (challenges.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 42.sp,
                    color: const Color(0xFFD1D1D6),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'no_challenges_yet'.tr(context),
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    _canCreateChallenge(userModel?.role)
                        ? 'use_add_to_create_challenge'.tr(context)
                        : 'gym_team_can_add_challenges'.tr(context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 12.h),
          itemCount: challenges.length,
          separatorBuilder: (context, separatorIndex) =>
              SizedBox(height: 1.5.h),
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            return Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3.w),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 18.sp,
                        color: const Color(0xFFFF9500),
                      ),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          challenge.title,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    challenge.description,
                    style: TextStyle(
                      fontSize: 13.sp,
                      height: 1.4,
                      color: const Color(0xFF3A3A3C),
                    ),
                  ),
                  SizedBox(height: 1.5.h),
                  Text(
                    "${'by_prefix'.tr(context)}${challenge.createdByName} · ${timeago.format(challenge.createdAt)}",
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF8E8E93),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLeaderboard(
    BuildContext context,
    WidgetRef ref,
    String gymId,
    UserModel? userModel,
  ) {
    final leaderboardAsync = ref.watch(leaderboardStreamProvider(gymId));

    return leaderboardAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
      ),
      error: (e, st) => Center(
        child: Text(
          'error_loading_rankings'.tr(context),
          style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
        ),
      ),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(
              'no_players_yet'.tr(context),
              style: TextStyle(fontSize: 14.sp, color: const Color(0xFF8E8E93)),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(5.w, 2.h, 5.w, 12.h),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final name = _displayUserName(user, context);
            final trophies = user.trophies;
            final isCurrentUser = user.uid == userModel?.uid;

            Color rankColor;
            String rankPrefix = '#${index + 1}';
            if (index == 0) {
              rankColor = const Color(0xFFFFD700);
              rankPrefix = '1';
            } else if (index == 1) {
              rankColor = const Color(0xFFC0C0C0);
              rankPrefix = '2';
            } else if (index == 2) {
              rankColor = const Color(0xFFCD7F32);
              rankPrefix = '3';
            } else {
              rankColor = const Color(0xFF1C1C1E);
            }

            return Container(
              margin: EdgeInsets.only(bottom: 1.5.h),
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: isCurrentUser ? const Color(0xFFFFF7E8) : Colors.white,
                borderRadius: BorderRadius.circular(3.w),
                border: Border.all(
                  color: isCurrentUser
                      ? const Color(0xFFFF9500)
                      : const Color(0xFFE5E5EA),
                  width: isCurrentUser ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 8.w,
                    child: Text(
                      rankPrefix,
                      style: TextStyle(
                        fontSize: index < 3 ? 18.sp : 14.sp,
                        fontWeight: FontWeight.w900,
                        color: rankColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  CircleAvatar(
                    radius: 5.w,
                    backgroundColor: const Color(0xFFE5E5EA),
                    backgroundImage:
                        user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? NetworkImage(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null || user.photoUrl!.isEmpty
                        ? Text(
                            name[0].toString().toUpperCase(),
                            style: const TextStyle(color: Colors.black),
                          )
                        : null,
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: isCurrentUser
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: const Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 0.8.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4.w),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$trophies',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFFF9500),
                          ),
                        ),
                        SizedBox(width: 1.w),
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 13.sp,
                          color: const Color(0xFFFF9500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _displayUserName(UserModel user, BuildContext context) {
    final fullName = [
      user.firstName,
      user.lastName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ');

    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (user.email.trim().isNotEmpty) return user.email.trim();
    return 'player_capital'.tr(context);
  }

  Widget buildActiveChallengeBanner() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      padding: EdgeInsets.all(4.5.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(4.5.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 2.w,
                height: 2.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 2.w),
              Text(
                'ACTIVE CHALLENGE · 3 DAYS LEFT',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.5.h),
          Text(
            '💪 30-Day Squat Challenge',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 0.5.h),
          Text(
            'Complete 100 squats every day. 847 members competing. Iron Peak Gym leads! 🏆',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            height: 1.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2.w),
            ),
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.73,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  borderRadius: BorderRadius.circular(2.w),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    WidgetRef ref,
    Post post,
    String currentUserId,
  ) {
    final isLiked = post.likedBy.contains(currentUserId);

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 6.w,
                  backgroundColor: const Color(0xFFE5E5EA),
                  backgroundImage: post.userAvatar.isNotEmpty
                      ? NetworkImage(post.userAvatar)
                      : null,
                  child: post.userAvatar.isEmpty
                      ? Text(
                          post.userName[0],
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.black,
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                      Text(
                        "${post.gymName != null ? '${post.gymName} · ' : ''}${timeago.format(post.createdAt)}",
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF8E8E93),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.userId == currentUserId)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: const Color(0xFF8E8E93),
                      size: 18.sp,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditPostBottomSheet(context, ref, post);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('edit_post'.tr(context)),
                      ),
                    ],
                  )
                else
                  Icon(
                    Icons.more_horiz_rounded,
                    color: const Color(0xFF8E8E93),
                    size: 18.sp,
                  ),
              ],
            ),
          ),

          // Caption
          if (post.content.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
              child: Text(
                post.content,
                style: TextStyle(
                  fontSize: 14.5.sp,
                  color: const Color(0xFF1C1C1E),
                  height: 1.4,
                ),
              ),
            ),

          SizedBox(height: 1.h),

          // Image (if any)
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 35.h,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                image: DecorationImage(
                  image: NetworkImage(post.imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Workout Summary Box (if applicable)
          if (post.isWorkout) _buildWorkoutSummaryBox(post, context),

          // Actions Row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Row(
              children: [
                _buildActionButton(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_outline_rounded,
                  color: isLiked
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF3A3A3C),
                  count: post.likesCount.toString(),
                  onTap: () {
                    if (currentUserId.isEmpty) return;
                    ref
                        .read(communityRepositoryProvider)
                        .toggleLike(post.id, currentUserId);
                  },
                ),
                SizedBox(width: 4.w),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  count: post.commentsCount.toString(),
                  onTap: () {
                    _showCommentsBottomSheet(context, ref, post);
                  },
                ),
                SizedBox(width: 4.w),
                _buildActionButton(
                  icon: Icons.ios_share_rounded,
                  count: '',
                  onTap: () {},
                ),
                const Spacer(),
                _buildActionButton(
                  icon: Icons.bookmark_border_rounded,
                  count: '',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F5), thickness: 1.5),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummaryBox(Post post, BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(3.w)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'completed_workout_upper'.tr(context),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 0.3.h),
                    Text(
                      post.workoutTitle ?? 'workout_capital'.tr(context),
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (post.formScore != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${post.formScore}',
                        style: TextStyle(
                          fontSize: 20.sp,
                          color: const Color(0xFF34C759),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'form_score_upper'.tr(context),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(3.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWorkoutStat(
                  '${post.durationMin ?? 0}m',
                  'duration_upper'.tr(context),
                ),
                _buildWorkoutStat(
                  '${post.setsCount ?? 0}',
                  'sets_upper'.tr(context),
                ),
                _buildWorkoutStat(
                  '${post.volume ?? 0}',
                  'volume_upper'.tr(context),
                ),
                _buildWorkoutStat(
                  '${post.calories ?? 0}',
                  'calories_upper'.tr(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutStat(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1C1C1E),
          ),
        ),
        SizedBox(height: 0.3.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
    Color color = const Color(0xFF3A3A3C),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: color),
          if (count.isNotEmpty) ...[
            SizedBox(width: 1.5.w),
            Text(
              count,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditPostBottomSheet(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) {
    final contentController = TextEditingController(text: post.content);
    String error = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 5.w,
                right: 5.w,
                top: 3.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'edit_post'.tr(context),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20.sp),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    style: TextStyle(fontSize: 15.sp),
                    decoration: InputDecoration(
                      hintText: 'whats_on_your_mind'.tr(context),
                      hintStyle: TextStyle(
                        color: const Color(0xFFC7C7CC),
                        fontSize: 15.sp,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    Text(
                      error,
                      style: TextStyle(
                        color: const Color(0xFFFF3B30),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  SizedBox(height: 2.h),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ElevatedButton(
                      onPressed: () async {
                        final content = contentController.text.trim();
                        if (content.isEmpty) {
                          setState(
                            () => error = 'post_cannot_be_empty'.tr(context),
                          );
                          return;
                        }

                        Navigator.pop(ctx);

                        try {
                          await ref
                              .read(communityRepositoryProvider)
                              .updatePostContent(post.id, content);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "${'failed_to_edit_post'.tr(context)}$e",
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 1.5.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                      ),
                      child: Text(
                        'save_capital'.tr(context),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCommentsBottomSheet(
    BuildContext context,
    WidgetRef ref,
    Post post,
  ) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, sheetRef, _) {
            final commentsAsync = sheetRef.watch(
              commentsStreamProvider(post.id),
            );

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SizedBox(
                height: 72.h,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(5.w, 2.h, 3.w, 1.h),
                      child: Row(
                        children: [
                          Text(
                            'comments_capital'.tr(context),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(Icons.close_rounded, size: 20.sp),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE5E5EA)),
                    Expanded(
                      child: commentsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                        error: (e, st) => Center(
                          child: Text(
                            "${'error_loading_comments'.tr(context)}$e",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: const Color(0xFF8E8E93),
                            ),
                          ),
                        ),
                        data: (comments) {
                          if (comments.isEmpty) {
                            return Center(
                              child: Text(
                                'no_comments_yet_capital'.tr(context),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: const Color(0xFF8E8E93),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 2.h,
                            ),
                            itemCount: comments.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: 1.5.h),
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 4.5.w,
                                    backgroundColor: const Color(0xFFE5E5EA),
                                    backgroundImage:
                                        comment.userAvatar.isNotEmpty
                                        ? NetworkImage(comment.userAvatar)
                                        : null,
                                    child: comment.userAvatar.isEmpty
                                        ? Text(
                                            comment.userName.isEmpty
                                                ? '?'
                                                : comment.userName[0],
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.black,
                                            ),
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 3.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              comment.userName,
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w900,
                                                color: const Color(0xFF1C1C1E),
                                              ),
                                            ),
                                            SizedBox(width: 2.w),
                                            Text(
                                              timeago.format(comment.createdAt),
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: const Color(0xFF8E8E93),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 0.4.h),
                                        Text(
                                          comment.content,
                                          style: TextStyle(
                                            fontSize: 13.5.sp,
                                            height: 1.35,
                                            color: const Color(0xFF3A3A3C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE5E5EA)),
                    Padding(
                      padding: EdgeInsets.fromLTRB(5.w, 1.h, 5.w, 2.h),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              minLines: 1,
                              maxLines: 3,
                              style: TextStyle(fontSize: 14.sp),
                              decoration: InputDecoration(
                                hintText: 'write_a_comment'.tr(context),
                                hintStyle: TextStyle(
                                  color: const Color(0xFFC7C7CC),
                                  fontSize: 14.sp,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF5F5F7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(5.w),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 1.3.h,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 2.w),
                          IconButton(
                            onPressed: () async {
                              final content = commentController.text.trim();
                              if (content.isEmpty) return;

                              final authUser = sheetRef
                                  .read(authStateProvider)
                                  .asData
                                  ?.value;
                              final userModel = sheetRef
                                  .read(currentUserModelProvider)
                                  .asData
                                  ?.value;
                              if (authUser == null || userModel == null) {
                                return;
                              }

                              final now = DateTime.now();
                              final comment = Comment(
                                id: now.millisecondsSinceEpoch.toString(),
                                gymId: post.gymId,
                                postId: post.id,
                                userId: authUser.uid,
                                userName: _displayName(userModel),
                                userAvatar: userModel.photoUrl ?? '',
                                content: content,
                                createdAt: now,
                              );

                              commentController.clear();

                              try {
                                await sheetRef
                                    .read(communityRepositoryProvider)
                                    .addComment(post.id, comment);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "${'failed_to_comment'.tr(context)}$e",
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              Icons.send_rounded,
                              size: 20.sp,
                              color: const Color(0xFF1C1C1E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePostBottomSheet(BuildContext context, WidgetRef ref) {
    final authUser = ref.read(authStateProvider).asData?.value;
    final userModel = ref.read(currentUserModelProvider).asData?.value;
    final gymId = userModel?.gymId?.trim();

    if (authUser == null ||
        userModel == null ||
        gymId == null ||
        gymId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('join_gym_before_posting'.tr(context))),
      );
      return;
    }

    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 5.w,
            right: 5.w,
            top: 3.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'create_post'.tr(context),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20.sp),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              TextField(
                controller: contentController,
                maxLines: 5,
                style: TextStyle(fontSize: 15.sp),
                decoration: InputDecoration(
                  hintText: 'whats_on_your_mind'.tr(context),
                  hintStyle: TextStyle(
                    color: const Color(0xFFC7C7CC),
                    fontSize: 15.sp,
                  ),
                  border: InputBorder.none,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    child: Icon(
                      Icons.image_rounded,
                      color: const Color(0xFF007AFF),
                      size: 20.sp,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      if (contentController.text.trim().isEmpty) return;

                      final post = Post(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        gymId: gymId,
                        userId: authUser.uid,
                        userName: _displayName(userModel),
                        userAvatar: userModel.photoUrl ?? '',
                        userRole: userModel.role,
                        content: contentController.text.trim(),
                        createdAt: DateTime.now(),
                      );

                      Navigator.pop(ctx);

                      // Show loading snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('posting_status'.tr(context)),
                          duration: const Duration(seconds: 1),
                        ),
                      );

                      try {
                        await ref
                            .read(communityRepositoryProvider)
                            .createPost(post);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${'failed_to_post'.tr(context)}$e",
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 1.5.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(3.w),
                      ),
                    ),
                    child: Text(
                      'post_capital'.tr(context),
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
            ],
          ),
        );
      },
    );
  }

  void _showCreateChallengeBottomSheet(BuildContext context, WidgetRef ref) {
    final authUser = ref.read(authStateProvider).asData?.value;
    final userModel = ref.read(currentUserModelProvider).asData?.value;
    final gymId = userModel?.gymId?.trim();

    if (authUser == null ||
        userModel == null ||
        gymId == null ||
        gymId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('join_gym_before_challenges'.tr(context))),
      );
      return;
    }
    if (!_canCreateChallenge(userModel.role)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('only_gym_owners_add_challenges'.tr(context))),
      );
      return;
    }

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String error = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 5.w,
                right: 5.w,
                top: 3.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'create_challenge'.tr(context),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20.sp),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  TextField(
                    controller: titleController,
                    style: TextStyle(fontSize: 15.sp),
                    decoration: InputDecoration(
                      hintText: 'challenge_title'.tr(context),
                      hintStyle: TextStyle(
                        color: const Color(0xFFC7C7CC),
                        fontSize: 15.sp,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 1.5.h),
                  TextField(
                    controller: descriptionController,
                    maxLines: 4,
                    style: TextStyle(fontSize: 15.sp),
                    decoration: InputDecoration(
                      hintText: 'challenge_details'.tr(context),
                      hintStyle: TextStyle(
                        color: const Color(0xFFC7C7CC),
                        fontSize: 15.sp,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    Text(
                      error,
                      style: TextStyle(
                        color: const Color(0xFFFF3B30),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  SizedBox(height: 2.h),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final description = descriptionController.text.trim();
                        if (title.isEmpty || description.isEmpty) {
                          setState(() {
                            error = 'fill_challenge_details'.tr(context);
                          });
                          return;
                        }

                        final now = DateTime.now();
                        final challenge = Challenge(
                          id: now.millisecondsSinceEpoch.toString(),
                          gymId: gymId,
                          createdByUid: authUser.uid,
                          createdByName: _displayName(userModel),
                          createdByRole: userModel.role,
                          title: title,
                          description: description,
                          createdAt: now,
                          startDate: now,
                          endDate: now.add(const Duration(days: 7)),
                        );

                        Navigator.pop(ctx);

                        try {
                          await ref
                              .read(communityRepositoryProvider)
                              .createChallenge(challenge);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "${'failed_to_create_challenge'.tr(context)}$e",
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 1.5.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3.w),
                        ),
                      ),
                      child: Text(
                        'create_capital'.tr(context),
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _canCreateChallenge(String? role) {
    final normalized = role?.trim().toLowerCase();
    return normalized == 'owner' ||
        normalized == 'admin' ||
        normalized == 'coach' ||
        normalized == 'superadmin';
  }

  String _displayName(UserModel user) {
    final name = [user.firstName, user.lastName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .map((part) => part!.trim())
        .join(' ');
    if (name.isNotEmpty) return name;
    if (user.email.trim().isNotEmpty) return user.email.split('@').first;
    return 'Player';
  }
}
