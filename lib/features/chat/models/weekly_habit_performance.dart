// lib/features/chat/models/weekly_habit_performance.dart

class WeeklyHabitPerformance {
  final String userId;
  final String userName;
  final List<HabitPerformanceItem> habits;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalHabits;
  final int completedHabits;
  final double successRate;

  WeeklyHabitPerformance({
    required this.userId,
    required this.userName,
    required this.habits,
    required this.weekStart,
    required this.weekEnd,
    required this.totalHabits,
    required this.completedHabits,
    required this.successRate,
  });

  Map<String, dynamic> toMetadata() {
    return {
      'userId': userId,
      'userName': userName,
      'habits': habits.map((h) => h.toMap()).toList(),
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'totalHabits': totalHabits,
      'completedHabits': completedHabits,
      'successRate': successRate,
      'type': 'weekly_performance',
    };
  }

  factory WeeklyHabitPerformance.fromMetadata(Map<String, dynamic> metadata) {
    return WeeklyHabitPerformance(
      userId: metadata['userId'] ?? '',
      userName: metadata['userName'] ?? 'کاربر',
      habits: (metadata['habits'] as List? ?? [])
          .map((h) => HabitPerformanceItem.fromMap(h))
          .toList(),
      weekStart: DateTime.parse(metadata['weekStart']),
      weekEnd: DateTime.parse(metadata['weekEnd']),
      totalHabits: metadata['totalHabits'] ?? 0,
      completedHabits: metadata['completedHabits'] ?? 0,
      successRate: metadata['successRate'] ?? 0.0,
    );
  }

  String getMotivationalMessage() {
    if (successRate >= 0.9) return '🔥 فوق‌العاده! هفته‌ای عالی داشتی!';
    if (successRate >= 0.7) return '💪 عالی! ادامه بده!';
    if (successRate >= 0.5) return '📈 خوب پیش می‌ری!';
    if (successRate >= 0.3) return '🌱 هر روز بهتر از دیروز!';
    return '🚀 امروز رو شروع کن!';
  }
}

class HabitPerformanceItem {
  final String habitId;
  final String habitTitle;
  final String iconName;
  final int iconColor;
  final List<bool> weekStatus; // 7 روز

  HabitPerformanceItem({
    required this.habitId,
    required this.habitTitle,
    required this.iconName,
    required this.iconColor,
    required this.weekStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'habitId': habitId,
      'habitTitle': habitTitle,
      'iconName': iconName,
      'iconColor': iconColor,
      'weekStatus': weekStatus,
    };
  }

  factory HabitPerformanceItem.fromMap(Map<String, dynamic> map) {
    return HabitPerformanceItem(
      habitId: map['habitId'] ?? '',
      habitTitle: map['habitTitle'] ?? '',
      iconName: map['iconName'] ?? 'fitness_center',
      iconColor: map['iconColor'] ?? 0xFF4A90E2,
      weekStatus: List<bool>.from(map['weekStatus'] ?? List.filled(7, false)),
    );
  }

  int get completedDays => weekStatus.where((s) => s).length;
}
