// lib/features/arena/models/habit_time_tracking.dart

class HabitTimeTracking {
  final String habitId;
  final DateTime date; // تاریخ انجام
  final int totalSeconds; // مجموع ثانیه‌های انجام شده
  final DateTime? lastUpdated;

  HabitTimeTracking({
    required this.habitId,
    required this.date,
    this.totalSeconds = 0,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'habit_id': habitId,
      'date': date.toIso8601String().split('T').first,
      'total_seconds': totalSeconds,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  factory HabitTimeTracking.fromMap(Map<String, dynamic> map) {
    return HabitTimeTracking(
      habitId: map['habit_id'] ?? '',
      date: DateTime.parse(map['date']),
      totalSeconds: map['total_seconds'] ?? 0,
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'])
          : null,
    );
  }

  // ✅ نمایش زمان به صورت خوانا
  String get formattedTime {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // ✅ نمایش زمان به صورت دقیقه و ثانیه
  String get formattedMinutesSeconds {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
