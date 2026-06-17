

enum SupplementTiming {
  morning,
  preWorkout,
  postWorkout,
  beforeSleep,
  anytime;

  String get translationKey {
    switch (this) {
      case SupplementTiming.morning:
        return 'morning_upper';
      case SupplementTiming.preWorkout:
        return 'pre_workout_today';
      case SupplementTiming.postWorkout:
        return 'post_workout';
      case SupplementTiming.beforeSleep:
        return 'before_sleep';
      case SupplementTiming.anytime:
        return 'anytime';
    }
  }
}

class SupplementItem {
  final String id;
  final String name;
  final String details;
  final SupplementTiming timing;
  final String emoji;
  final int iconBgColor;

  SupplementItem({
    required this.id,
    required this.name,
    required this.details,
    required this.timing,
    required this.emoji,
    required this.iconBgColor,
  });

  factory SupplementItem.fromMap(Map<String, dynamic> map, String id) {
    return SupplementItem(
      id: id,
      name: map['name'] ?? '',
      details: map['details'] ?? '',
      timing: SupplementTiming.values.firstWhere(
        (e) => e.name == map['timing'],
        orElse: () => SupplementTiming.anytime,
      ),
      emoji: map['emoji'] ?? '💊',
      iconBgColor: map['iconBgColor'] ?? 0xFFE5E5EA,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'details': details,
      'timing': timing.name,
      'emoji': emoji,
      'iconBgColor': iconBgColor,
    };
  }

  SupplementItem copyWith({
    String? id,
    String? name,
    String? details,
    SupplementTiming? timing,
    String? emoji,
    int? iconBgColor,
  }) {
    return SupplementItem(
      id: id ?? this.id,
      name: name ?? this.name,
      details: details ?? this.details,
      timing: timing ?? this.timing,
      emoji: emoji ?? this.emoji,
      iconBgColor: iconBgColor ?? this.iconBgColor,
    );
  }
}

class SupplementDailyLog {
  final String date;
  final List<String> takenIds;

  SupplementDailyLog({
    required this.date,
    required this.takenIds,
  });

  factory SupplementDailyLog.fromMap(Map<String, dynamic> map, String id) {
    return SupplementDailyLog(
      date: id,
      takenIds: List<String>.from(map['takenIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'takenIds': takenIds,
    };
  }
}

