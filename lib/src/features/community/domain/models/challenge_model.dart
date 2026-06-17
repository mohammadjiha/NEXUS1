import 'package:cloud_firestore/cloud_firestore.dart';

class Challenge {
  final String id;
  final String gymId;
  final String createdByUid;
  final String createdByName;
  final String? createdByRole;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final int participantsCount;

  Challenge({
    required this.id,
    required this.gymId,
    required this.createdByUid,
    required this.createdByName,
    this.createdByRole,
    required this.title,
    required this.description,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.participantsCount = 0,
  });

  factory Challenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Challenge(
      id: doc.id,
      gymId: data['gymId'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      createdByName: data['createdByName'] ?? 'Unknown',
      createdByRole: data['createdByRole'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'active',
      participantsCount: data['participantsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'gymId': gymId,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'status': status,
      'participantsCount': participantsCount,
    };
  }
}
