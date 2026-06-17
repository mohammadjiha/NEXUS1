import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String gymId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String? userRole;
  final String? gymName;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final List<String> likedBy;

  // Optional Workout Data
  final bool isWorkout;
  final String? workoutTitle;
  final String? workoutSubtitle;
  final int? formScore;
  final int? durationMin;
  final int? setsCount;
  final int? volume;
  final int? calories;

  // Optional PR Badge
  final bool hasPR;
  final String? prTitle;
  final String? prSubtitle;

  Post({
    required this.id,
    required this.gymId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.userRole,
    this.gymName,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedBy = const [],
    this.isWorkout = false,
    this.workoutTitle,
    this.workoutSubtitle,
    this.formScore,
    this.durationMin,
    this.setsCount,
    this.volume,
    this.calories,
    this.hasPR = false,
    this.prTitle,
    this.prSubtitle,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      gymId: data['gymId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userAvatar: data['userAvatar'] ?? '',
      userRole: data['userRole'],
      gymName: data['gymName'],
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      isWorkout: data['isWorkout'] ?? false,
      workoutTitle: data['workoutTitle'],
      workoutSubtitle: data['workoutSubtitle'],
      formScore: data['formScore'],
      durationMin: data['durationMin'],
      setsCount: data['setsCount'],
      volume: data['volume'],
      calories: data['calories'],
      hasPR: data['hasPR'] ?? false,
      prTitle: data['prTitle'],
      prSubtitle: data['prSubtitle'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gymId': gymId,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'userRole': userRole,
      'gymName': gymName,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'likedBy': likedBy,
      'isWorkout': isWorkout,
      'workoutTitle': workoutTitle,
      'workoutSubtitle': workoutSubtitle,
      'formScore': formScore,
      'durationMin': durationMin,
      'setsCount': setsCount,
      'volume': volume,
      'calories': calories,
      'hasPR': hasPR,
      'prTitle': prTitle,
      'prSubtitle': prSubtitle,
    };
  }

  Post copyWith({
    String? id,
    String? gymId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userRole,
    String? gymName,
    String? content,
    String? imageUrl,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    List<String>? likedBy,
    bool? isWorkout,
    String? workoutTitle,
    String? workoutSubtitle,
    int? formScore,
    int? durationMin,
    int? setsCount,
    int? volume,
    int? calories,
    bool? hasPR,
    String? prTitle,
    String? prSubtitle,
  }) {
    return Post(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userRole: userRole ?? this.userRole,
      gymName: gymName ?? this.gymName,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedBy: likedBy ?? this.likedBy,
      isWorkout: isWorkout ?? this.isWorkout,
      workoutTitle: workoutTitle ?? this.workoutTitle,
      workoutSubtitle: workoutSubtitle ?? this.workoutSubtitle,
      formScore: formScore ?? this.formScore,
      durationMin: durationMin ?? this.durationMin,
      setsCount: setsCount ?? this.setsCount,
      volume: volume ?? this.volume,
      calories: calories ?? this.calories,
      hasPR: hasPR ?? this.hasPR,
      prTitle: prTitle ?? this.prTitle,
      prSubtitle: prSubtitle ?? this.prSubtitle,
    );
  }
}
