import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../gym/data/exercises_repository.dart';
import '../../../gym/models/exercise_model.dart';

class ExerciseVideoSheet extends ConsumerStatefulWidget {
  final String exerciseName;
  const ExerciseVideoSheet({super.key, required this.exerciseName});

  static void show(BuildContext context, String exerciseName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExerciseVideoSheet(exerciseName: exerciseName),
    );
  }

  @override
  ConsumerState<ExerciseVideoSheet> createState() => _ExerciseVideoSheetState();
}

class _ExerciseVideoSheetState extends ConsumerState<ExerciseVideoSheet> {
  YoutubePlayerController? _ytController;
  bool _isYouTube = false;
  bool _isWebViewSupported = false;
  bool _isVideoVisible = false;
  ExerciseModel? _foundExercise;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _isWebViewSupported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _initPlayer(ExerciseModel exercise) {
    if (_ytController != null) return;

    final videoId = YoutubePlayer.convertUrlToId(exercise.videoLink);
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
    final allExercisesAsync = ref.watch(allExercisesProvider);

    return Container(
      height: 70.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(5.w)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 1.5.h, bottom: 2.h),
              width: 12.w,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'exercise_video'.tr(context),
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1C1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14.sp,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                widget.exerciseName,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF007AFF),
                ),
              ),
            ),
          ),
          SizedBox(height: 3.h),

          // Content
          Expanded(
            child: allExercisesAsync.when(
              data: (muscleGroups) {
                if (!_searched) {
                  // Find the exercise
                  final searchName = widget.exerciseName.toLowerCase();
                  for (var mg in muscleGroups) {
                    for (var ex in mg.exercises) {
                      if (ex.name.toLowerCase().contains(searchName) ||
                          searchName.contains(ex.name.toLowerCase())) {
                        _foundExercise = ex;
                        break;
                      }
                    }
                    if (_foundExercise != null) break;
                  }

                  if (_foundExercise != null &&
                      _foundExercise!.videoLink.isNotEmpty &&
                      _foundExercise!.videoLink != 'None') {
                    _initPlayer(_foundExercise!);
                  }
                  _searched = true;
                }

                if (_foundExercise == null) {
                  return _buildNotFound(context);
                }

                if (_foundExercise!.videoLink.isEmpty ||
                    _foundExercise!.videoLink == 'None') {
                  return _buildNoVideo(context);
                }

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Video Player
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.w),
                        child: Container(
                          width: double.infinity,
                          height: 25.h,
                          color: const Color(0xFF0A0A0E),
                          child: _isYouTube && _ytController != null
                              ? (!_isVideoVisible
                                    ? GestureDetector(
                                        onTap: () => setState(
                                          () => _isVideoVisible = true,
                                        ),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              YoutubePlayer.getThumbnail(
                                                videoId: _ytController!
                                                    .initialVideoId,
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                            Center(
                                              child: Container(
                                                padding: EdgeInsets.all(3.w),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
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
                                        progressIndicatorColor: const Color(
                                          0xFF8CFB17,
                                        ),
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
                                        'video_preview_not_supported'.tr(
                                          context,
                                        ),
                                        style: TextStyle(
                                          color: const Color(0xFF8E8E93),
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                      SizedBox(height: 1.5.h),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final url = Uri.parse(
                                            _foundExercise!.videoLink,
                                          );
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          }
                                        },
                                        icon: const Icon(Icons.open_in_browser),
                                        label: Text(
                                          'watch_in_browser'.tr(context),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF2C2C2E,
                                          ),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 5.w,
                                            vertical: 1.5.h,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              3.w,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'tips'.tr(context).toUpperCase(),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF8E8E93),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 1.5.h),
                      Text(
                        _foundExercise!.warnings != 'None'
                            ? _foundExercise!.warnings
                            : 'Focus on proper form and controlled movement.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: const Color(0xFF3A3A3C),
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 4.h),
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF1C1C1E)),
              ),
              error: (e, st) => Center(
                child: Text(
                  'error_loading_data'.tr(context),
                  style: TextStyle(color: Colors.red, fontSize: 13.sp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 40.sp,
            color: const Color(0xFFD1D1D6),
          ),
          SizedBox(height: 2.h),
          Text(
            'video_not_found'.tr(context).tr(context),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3A3A3C),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'could_not_find_video'.tr(context).tr(context),
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoVideo(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_rounded,
            size: 40.sp,
            color: const Color(0xFFD1D1D6),
          ),
          SizedBox(height: 2.h),
          Text(
            'no_video_available'.tr(context).tr(context),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF3A3A3C),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'no_attached_video'.tr(context).tr(context),
            style: TextStyle(fontSize: 13.sp, color: const Color(0xFF8E8E93)),
          ),
        ],
      ),
    );
  }
}
