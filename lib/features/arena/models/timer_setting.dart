// lib/features/arena/models/timer_setting.dart

class TimerSetting {
  final String habitId;
  final int minutes; // دقیقه
  final int seconds; // ثانیه
  final bool isCountdown;
  final String sound;
  final bool isEnabled;

  TimerSetting({
    required this.habitId,
    this.minutes = 10,
    this.seconds = 0,
    this.isCountdown = true,
    this.sound = 'default',
    this.isEnabled = false,
  });

  // ✅ مدت زمان کل به ثانیه
  int get totalSeconds => (minutes * 60) + seconds;

  Map<String, dynamic> toMap() {
    return {
      'habit_id': habitId,
      'minutes': minutes,
      'seconds': seconds,
      'total_seconds': totalSeconds,
      'is_countdown': isCountdown,
      'sound': sound,
      'is_enabled': isEnabled,
    };
  }

  factory TimerSetting.fromMap(Map<String, dynamic> map) {
    // ✅ پشتیبانی از فرمت قدیمی (duration) و جدید (minutes, seconds)
    int minutes = map['minutes'] ?? 10;
    int seconds = map['seconds'] ?? 0;

    // اگر مقدار duration وجود داشت، به minutes و seconds تبدیل کن
    if (map['duration'] != null) {
      final totalSeconds = map['duration'] as int;
      minutes = totalSeconds ~/ 60;
      seconds = totalSeconds % 60;
    }

    return TimerSetting(
      habitId: map['habit_id'] ?? '',
      minutes: minutes,
      seconds: seconds,
      isCountdown: map['is_countdown'] ?? true,
      sound: map['sound'] ?? 'default',
      isEnabled: map['is_enabled'] ?? false,
    );
  }
}
