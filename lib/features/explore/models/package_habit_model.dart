import '../../arena/models/habit_model.dart';

// lib/features/explore/models/package_habit_model.dart

class PackageHabit {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final int iconColor;
  final int backgroundColor;
  final String frequencyType;
  final List<int>? weeklyDays;
  final List<int>? monthlyDays;
  final int? dailyIntervalDays;
  final String timeOfDay;
  final int xpReward;
  final List<String> subHabits;

  // ✅ فیلدهای جدید برای سطوح
  final String? fullDescription;
  final String? halfDescription;
  final String? basicDescription;
  final String? targetValue;

  PackageHabit({
    required this.id,
    required this.title,
    this.description = '',
    this.iconName = 'fitness_center',
    this.iconColor = 0xFF4A90E2,
    this.backgroundColor = 0xFFF5F5F5,
    this.frequencyType = 'daily',
    this.weeklyDays,
    this.monthlyDays,
    this.dailyIntervalDays,
    this.timeOfDay = 'morning',
    this.xpReward = 10,
    this.subHabits = const [],
    this.fullDescription,
    this.halfDescription,
    this.basicDescription,
    this.targetValue,
  });

  factory PackageHabit.fromMap(Map<String, dynamic> map) {
    return PackageHabit(
      id: map['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      iconName: map['icon_name']?.toString() ?? 'fitness_center',
      iconColor: map['icon_color'] ?? 0xFF4A90E2,
      backgroundColor: map['background_color'] ?? 0xFFF5F5F5,
      frequencyType: map['frequency_type']?.toString() ?? 'daily',
      weeklyDays: map['weekly_days'] != null
          ? List<int>.from(map['weekly_days'])
          : null,
      monthlyDays: map['monthly_days'] != null
          ? List<int>.from(map['monthly_days'])
          : null,
      dailyIntervalDays: map['daily_interval_days'],
      timeOfDay: map['time_of_day']?.toString() ?? 'morning',
      xpReward: map['xp_reward'] ?? 10,
      subHabits:
          map['sub_habits'] != null ? List<String>.from(map['sub_habits']) : [],
      fullDescription: map['full_description']?.toString(),
      halfDescription: map['half_description']?.toString(),
      basicDescription: map['basic_description']?.toString(),
      targetValue: map['target_value']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon_name': iconName,
      'icon_color': iconColor,
      'background_color': backgroundColor,
      'frequency_type': frequencyType,
      'weekly_days': weeklyDays,
      'monthly_days': monthlyDays,
      'daily_interval_days': dailyIntervalDays,
      'time_of_day': timeOfDay,
      'xp_reward': xpReward,
      'sub_habits': subHabits,
      'full_description': fullDescription,
      'half_description': halfDescription,
      'basic_description': basicDescription,
      'target_value': targetValue,
    };
  }

  Habit toHabit(String userId, String packageId) {
    return Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: '📦 $title',
      description: description,
      subHabits: subHabits,
      completedSubHabits: [],
      iconName: iconName,
      iconColor: iconColor,
      backgroundColor: backgroundColor,
      frequencyType: frequencyType,
      dailyIntervalDays:
          dailyIntervalDays != null ? [dailyIntervalDays!] : null,
      weeklyDays: weeklyDays,
      weeklyIntervalWeeks: 1,
      monthlyDays: monthlyDays,
      monthlyIntervalMonths: 1,
      timeOfDay: timeOfDay,
      reminders: [],
      xpReward: xpReward,
      currentStreak: 0,
      bestStreak: 0,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      groupId: null,
      startDate: null,
      endDate: null,
      challengeId: null,
      questId: null,
      // ✅ اضافه کردن فیلدهای سطح
      fullDescription: fullDescription ?? 'انجام کامل عادت',
      halfDescription: halfDescription ?? 'انجام نیمی از عادت',
      basicDescription: basicDescription ?? 'انجام حداقل عادت',
      targetValue: targetValue,
    );
  }
}
