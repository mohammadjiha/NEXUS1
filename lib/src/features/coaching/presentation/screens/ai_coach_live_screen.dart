import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:sizer/sizer.dart';

import '../../../../../core/localization/app_localizations.dart';
import 'ai_coach_analyzing_screen.dart';

class AICoachLiveScreen extends StatefulWidget {
  final String exerciseName;
  const AICoachLiveScreen({super.key, this.exerciseName = 'Squat'});

  @override
  State<AICoachLiveScreen> createState() => _AICoachLiveScreenState();
}

class _AICoachLiveScreenState extends State<AICoachLiveScreen> {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  bool _isBusy = false;
  List<Pose> _poses = [];
  bool _isRecording = false;
  String _detectedExercise = 'Standing';
  DateTime? _recordingStartTime;
  CameraLensDirection _cameraDirection = CameraLensDirection.front;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  double _calculateAngle(
    PoseLandmark? first,
    PoseLandmark? middle,
    PoseLandmark? last,
  ) {
    if (first == null || middle == null || last == null) return 180.0;
    double result =
        math.atan2(last.y - middle.y, last.x - middle.x) -
        math.atan2(first.y - middle.y, first.x - middle.x);
    result = result.abs() * 180.0 / math.pi;
    if (result > 180.0) result = 360.0 - result;
    return result;
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final targetCamera = cameras.firstWhere(
      (c) => c.lensDirection == _cameraDirection,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      targetCamera,
      ResolutionPreset.medium, // high is overkill for ML Kit and strains lower-end devices
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();
    if (!mounted) return;

    _cameraController!.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final camera = _cameraController!.description;
      final imageRotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
      final poses = await _poseDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _poses = poses;
        });
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _toggleRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      // Stop recording
      setState(() => _isRecording = false);

      final file = await _cameraController!.stopVideoRecording();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AICoachAnalyzingScreen(
              videoPath: file.path,
              exerciseName: _detectedExercise == 'Standing'
                  ? widget.exerciseName
                  : _detectedExercise,
            ),
          ),
        );
      }
    } else {
      // Start recording a REAL video for maximum accuracy
      setState(() {
        _isRecording = true;
        _recordingStartTime = DateTime.now();
      });

      // Stop the image stream to allow video recording
      await _cameraController!.stopImageStream();
      setState(() {
        _poses.clear(); // Hide skeleton while recording
      });

      await _cameraController!.startVideoRecording();
    }
  }

  Future<void> _flipCamera() async {
    if (_isRecording || _cameraController == null) return;

    setState(() {
      _isBusy = true; // prevent image stream processing while switching
      _cameraDirection = _cameraDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });

    await _cameraController!.dispose();
    await _initializeCamera();

    setState(() {
      _isBusy = false;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Determine form status based on poses using real math
    bool goodForm = true;
    double leftKneeAngle = 180;
    double rightKneeAngle = 180;
    double backAngle = 180;
    String feedbackMsg = 'Great form, keep going!';

    if (_poses.isNotEmpty) {
      final pose = _poses.first;

      leftKneeAngle = _calculateAngle(
        pose.landmarks[PoseLandmarkType.leftHip],
        pose.landmarks[PoseLandmarkType.leftKnee],
        pose.landmarks[PoseLandmarkType.leftAnkle],
      );
      rightKneeAngle = _calculateAngle(
        pose.landmarks[PoseLandmarkType.rightHip],
        pose.landmarks[PoseLandmarkType.rightKnee],
        pose.landmarks[PoseLandmarkType.rightAnkle],
      );

      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

      if (leftShoulder != null && leftHip != null) {
        // Calculate back angle relative to vertical (vertical y-axis)
        double dx = (leftShoulder.x - leftHip.x).abs();
        double dy = (leftShoulder.y - leftHip.y).abs();
        backAngle = 180 - (math.atan2(dx, dy) * 180.0 / math.pi);
      }

      if (leftWrist != null && leftShoulder != null && leftHip != null) {
        if (leftWrist.y < leftShoulder.y - 20) {
          _detectedExercise = 'Shoulder Press';
          if (backAngle < 160) {
            goodForm = false;
            feedbackMsg = 'Arching back too much! Keep core tight.';
          }
        } else if (leftKneeAngle < 150) {
          _detectedExercise = 'Squat';
          if (leftKneeAngle < 70) {
            goodForm = false;
            feedbackMsg = 'Going too deep! Watch your knees.';
          } else if (backAngle < 130) {
            goodForm = false;
            feedbackMsg = 'Leaning forward too much! Keep chest up.';
          }
        } else if (leftWrist.y > leftHip.y + 20 && backAngle < 150) {
          _detectedExercise = 'Deadlift';
        } else {
          _detectedExercise = 'Standing';
          feedbackMsg = 'Ready for the next rep.';
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview & Painter
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraController!.value.previewSize!.height,
                height: _cameraController!.value.previewSize!.width,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_cameraController!),
                    if (_poses.isNotEmpty)
                      CustomPaint(
                        painter: PosePainter(
                          _poses,
                          _cameraController!.value.previewSize!,
                          goodForm,
                          _cameraDirection == CameraLensDirection.front,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Top Bar
          PositionedDirectional(
            top: 6.h,
            start: 4.w,
            end: 4.w,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.close, color: Colors.white, size: 16.sp),
                  ),
                ),
                if (_isRecording)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 2.5.w,
                          height: 2.5.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF3B30),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          'rec'.tr(context),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.w,
                      vertical: 1.5.h,
                    ),
                    decoration: BoxDecoration(
                      color: goodForm
                          ? const Color(0xFF34C759).withValues(alpha: 0.9)
                          : const Color(0xFFFF3B30).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          goodForm ? Icons.check : Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                        SizedBox(width: 1.5.w),
                        Text(
                          (goodForm ? 'good_form' : 'fix_form')
                              .tr(context)
                              .toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Live Angles (Only show when NOT recording to avoid clutter)
          if (!_isRecording)
            PositionedDirectional(
              top: 15.h,
              start: 4.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAngleBox(
                    'KNEE L',
                    '${leftKneeAngle.toInt()}°',
                    goodForm
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                  ),
                  SizedBox(height: 1.5.h),
                  _buildAngleBox(
                    'KNEE R',
                    '${rightKneeAngle.toInt()}°',
                    goodForm
                        ? const Color(0xFF34C759)
                        : const Color(0xFFFF3B30),
                  ),
                  SizedBox(height: 1.5.h),
                  _buildAngleBox(
                    'BACK',
                    '${backAngle.toInt()}°',
                    backAngle < 130
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF34C759),
                  ),
                ],
              ),
            ),

          // Bottom Info
          if (!_isRecording)
            PositionedDirectional(
              bottom: 14.h,
              start: 4.w,
              end: 4.w,
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4.w),
                  border: Border.all(
                    color: goodForm
                        ? Colors.transparent
                        : const Color(0xFFFF3B30).withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.smart_toy_rounded,
                          color: const Color(0xFF007AFF),
                          size: 18.sp,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          '$_detectedExercise — AI Analysis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      feedbackMsg,
                      style: TextStyle(
                        color: goodForm
                            ? Colors.white.withValues(alpha: 0.9)
                            : const Color(0xFFFF3B30),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Controls
          PositionedDirectional(
            bottom: 4.h,
            start: 0,
            end: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _flipCamera,
                  child: Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cameraswitch, color: Colors.white),
                  ),
                ),
                SizedBox(width: 6.w),
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 3,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: _isRecording ? 8.w : 14.w,
                      height: _isRecording ? 8.w : 14.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(
                          _isRecording ? 2.w : 7.w,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flash_off, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAngleBox(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(2.w),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 0.2.h),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool goodForm;
  final bool isFrontCamera;

  PosePainter(this.poses, this.imageSize, this.goodForm, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = goodForm
          ? const Color(0xFF34C759).withValues(alpha: 0.9)
          : const Color(0xFFFF9500).withValues(alpha: 0.9);

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = goodForm
          ? const Color(0xFF34C759).withValues(alpha: 0.9)
          : const Color(0xFFFF3B30).withValues(alpha: 0.9);

    for (final pose in poses) {
      void paintLine(PoseLandmarkType type1, PoseLandmarkType type2, Paint p) {
        final lm1 = pose.landmarks[type1];
        final lm2 = pose.landmarks[type2];
        if (lm1 != null && lm2 != null) {
          // Scale coordinates
          final xRatio1 = lm1.x / imageSize.height;
          final x1 = isFrontCamera
              ? (size.width - xRatio1 * size.width)
              : (xRatio1 * size.width);
          final y1 = (lm1.y / imageSize.width) * size.height;

          final xRatio2 = lm2.x / imageSize.height;
          final x2 = isFrontCamera
              ? (size.width - xRatio2 * size.width)
              : (xRatio2 * size.width);
          final y2 = (lm2.y / imageSize.width) * size.height;

          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);
          canvas.drawCircle(Offset(x1, y1), 4, p..style = PaintingStyle.fill);
        }
      }

      // Torso
      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        paint,
      );
      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip,
        leftPaint,
      );
      paintLine(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip,
        paint,
      );
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, paint);

      // Legs
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
        leftPaint,
      );
      paintLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, paint);
      paintLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, paint);

      // Arms
      paintLine(
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        paint,
      );
      paintLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, paint);
      paintLine(
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        paint,
      );
      paintLine(
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
        paint,
      );
    }
  }

  @override
  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses || oldDelegate.imageSize != imageSize;
  }
}
