import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../features/coaching/presentation/screens/ai_coach_live_screen.dart';
import '../../../../features/plan/providers/my_plan_provider.dart';
import '../../models/exercise_model.dart';

class ExerciseDetailsScreen extends ConsumerStatefulWidget {
  final ExerciseModel exercise;

  const ExerciseDetailsScreen({super.key, required this.exercise});

  @override
  ConsumerState<ExerciseDetailsScreen> createState() =>
      _ExerciseDetailsScreenState();
}

class _ExerciseDetailsScreenState extends ConsumerState<ExerciseDetailsScreen> {
  YoutubePlayerController? _ytController;
  bool _isWebViewSupported = false;
  bool _isYouTube = false;
  bool _isVideoVisible = false;

  @override
  void initState() {
    super.initState();

    _isWebViewSupported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    final videoId = YoutubePlayer.convertUrlToId(widget.exercise.videoLink);
    if (videoId != null && _isWebViewSupported) {
      _isYouTube = true;
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
      );
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final locale = Localizations.localeOf(context).languageCode;
    final name = exercise.localizedName(locale);
    final targetMuscle = exercise.localizedTargetMuscleGroup(locale);
    final exerciseType = exercise.localizedExerciseType(locale);
    final equipment = exercise.localizedEquipmentRequired(locale);
    final mechanics = exercise.localizedMechanics(locale);
    final forceType = exercise.localizedForceType(locale);
    final experienceLevel = exercise.localizedExperienceLevel(locale);
    final secondaryMuscles = exercise.localizedSecondaryMuscles(locale);
    final warnings = exercise.localizedWarnings(locale);
    final steps = exercise.localizedSteps(locale);
    final isSaved = ref
        .watch(myPlanProvider.notifier)
        .isFavorite(exercise.name);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1C1C1E),
            size: 24,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isSaved
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF1C1C1E),
              size: 26,
            ),
            onPressed: () {
              ref.read(myPlanProvider.notifier).toggleFavorite(exercise);
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: Color(0xFF1C1C1E),
              size: 26,
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // VIDEO AREA (Padded and curved)
          if (exercise.videoLink.isNotEmpty && exercise.videoLink != 'None')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4.w),
                child: Container(
                  width: double.infinity,
                  height: 25.h,
                  color: const Color(0xFF0A0A0E),
                  child: _isYouTube && _ytController != null
                      ? (!_isVideoVisible
                            ? GestureDetector(
                                onTap: () =>
                                    setState(() => _isVideoVisible = true),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      YoutubePlayer.getThumbnail(
                                        videoId: _ytController!.initialVideoId,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: const Color(0xFF1C1C1E),
                                              child: Center(
                                                child: Icon(
                                                  Icons.ondemand_video_rounded,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  size: 40.sp,
                                                ),
                                              ),
                                            );
                                          },
                                    ),
                                    Center(
                                      child: Container(
                                        padding: EdgeInsets.all(3.w),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          color: Colors.white,
                                          size: 30.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : YoutubePlayer(
                                controller: _ytController!,
                                showVideoProgressIndicator: true,
                                progressIndicatorColor: const Color(0xFF8CFB17),
                                progressColors: const ProgressBarColors(
                                  playedColor: Color(0xFF8CFB17),
                                  handleColor: Color(0xFF8CFB17),
                                ),
                              ))
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.ondemand_video_rounded,
                                color: Colors.white54,
                                size: 30.sp,
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'video_preview_not_supported'.tr(context),
                                style: TextStyle(
                                  color: const Color(0xFF8E8E93),
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(height: 1.5.h),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final url = Uri.parse(exercise.videoLink);
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  }
                                },
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'watch_in_browser'.tr(context),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C2C2E),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 5.w,
                                    vertical: 1.5.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(3.w),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NAME + SUBTITLE
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.4,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: 0.8.h),
                  Text(
                    "$targetMuscle • ${'exercise_guide'.tr(context)}",
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: const Color(0xFF8E8E93),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.5.h),

                  // TAG CHIPS
                  Wrap(
                    spacing: 2.5.w,
                    runSpacing: 1.5.h,
                    children: [
                      _buildTagChip(
                        label: targetMuscle,
                        bgColor: const Color(0xFFEBF5FF),
                        textColor: const Color(0xFF0A64B0),
                        borderColor: const Color(0xFFC5DFFF),
                        dotColor: const Color(0xFF0A64B0),
                      ),
                      _buildTagChip(
                        label: equipment,
                        bgColor: const Color(0xFFF0FFF4),
                        textColor: const Color(0xFF1A7A30),
                        borderColor: const Color(0xFFB8EFC8),
                        dotColor: const Color(0xFF1A7A30),
                      ),
                      _buildTagChip(
                        label: exerciseType,
                        bgColor: const Color(0xFFF5F5F7),
                        textColor: const Color(0xFF3A3A3C),
                        borderColor: const Color(0xFFD1D1D6),
                        isSquare: true,
                      ),
                      _buildTagChip(
                        label: forceType,
                        bgColor: const Color(0xFFFFF8E8),
                        textColor: const Color(0xFF7A4D0A),
                        borderColor: const Color(0xFFFADDAD),
                        isSquare: true,
                      ),
                      _buildTagChip(
                        label: experienceLevel,
                        bgColor: const Color(0xFFFFF5F5),
                        textColor: const Color(0xFFA0220A),
                        borderColor: const Color(0xFFFFBFB0),
                        isSquare: true,
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),

                  // AI FORM CHECK BTN
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AICoachLiveScreen(exerciseName: exercise.name),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 5.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                        ),
                        borderRadius: BorderRadius.circular(4.w),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF8E2DE2,
                            ).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 22.sp,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            'check_form_with_ai'.tr(context),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),

                  // INFO GRID
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 3.w,
                    mainAxisSpacing: 1.5.h,
                    children: [
                      _buildInfoCard('mechanics'.tr(context), mechanics),
                      _buildInfoCard('force_type'.tr(context), forceType),
                      _buildInfoCard('level'.tr(context), experienceLevel),
                      _buildInfoCard(
                        'secondary_muscles'.tr(context),
                        secondaryMuscles.isEmpty || secondaryMuscles == 'None'
                            ? 'None'
                            : secondaryMuscles,
                        isFaded:
                            secondaryMuscles.isEmpty ||
                            secondaryMuscles == 'None',
                      ),
                    ],
                  ),
                  // DIVIDER
                  Container(height: 0.5, color: const Color(0xFFD1D1D6)),
                  SizedBox(height: 3.h),

                  // STEPS
                  if (steps.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F0F5),
                            borderRadius: BorderRadius.circular(2.w),
                          ),
                          child: Icon(
                            Icons.format_list_numbered_rounded,
                            size: 16.sp,
                            color: const Color(0xFF3A3A3C),
                          ),
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          'steps'.tr(context).toUpperCase(),
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF3A3A3C),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.5.h),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: steps.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Color(0xFFF5F5F7), height: 1),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8.w,
                                height: 8.w,
                                margin: EdgeInsets.only(top: 0.2.h),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD1D1D6),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3A3A3C),
                                  ),
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Expanded(
                                child: Text(
                                  steps[index],
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: const Color(0xFF1C1C1E),
                                    height: 1.6,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Container(height: 0.5, color: const Color(0xFFD1D1D6)),
                    SizedBox(height: 3.h),
                  ],

                  // WARNING BOX
                  if (warnings.isNotEmpty && warnings != 'None') ...[
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF9EC),
                        borderRadius: BorderRadius.circular(4.w),
                        border: Border.all(
                          color: const Color(0xFFF5D78E),
                        ),
                      ),
                      padding: EdgeInsets.all(5.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: const Color(0xFFB07D10),
                                size: 16.sp,
                              ),
                              SizedBox(width: 2.w),
                              Text(
                                'tips_warnings'.tr(context).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFB07D10),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.5.h),
                          Text(
                            warnings,
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: const Color(0xFF7A5C0A),
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 5.h),
                  ],

                  // ADD TO PLAN BTN
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref
                            .read(myPlanProvider.notifier)
                            .toggleFavorite(exercise);
                        setState(() {});
                      },
                      icon: Icon(
                        isSaved ? Icons.check_rounded : Icons.add_rounded,
                        size: 22,
                      ),
                      label: Text(
                        isSaved
                            ? 'added_to_plan'.tr(context)
                            : 'add_to_my_plan'.tr(context),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSaved
                            ? const Color(0xFF34C759)
                            : const Color(0xFF1C1C1E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.w),
                        ),
                        textStyle: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip({
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color borderColor,
    Color? dotColor,
    bool isSquare = false,
  }) {
    if (label.isEmpty || label == 'None') return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5.w),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 1.8.w,
              height: 1.8.w,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 1.5.w),
          ] else if (isSquare) ...[
            Container(
              width: 2.2.w,
              height: 2.2.w,
              decoration: BoxDecoration(
                border: Border.all(color: textColor, width: 1.2),
                borderRadius: BorderRadius.circular(0.5.w),
              ),
            ),
            SizedBox(width: 1.5.w),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, {bool isFaded = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: const Color(0xFFEBEBF0), width: 0.8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8E8E93),
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 0.8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: isFaded
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF1C1C1E),
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
