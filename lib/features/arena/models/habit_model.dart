import 'dart:convert';
import 'package:shamsi_date/shamsi_date.dart';
import 'timer_setting.dart'; // یا مسیر درست

class Habit {
  String id;
  String userId;
  String title;
  String description;
  List<String> subHabits;
  List<String> completedSubHabits;

  String iconName;
  int iconColor;
  int backgroundColor;

  String frequencyType;
  List<int>? dailyIntervalDays;
  List<int>? weeklyDays;
  int? weeklyIntervalWeeks;
  List<int>? monthlyDays;
  int? monthlyIntervalMonths;

  String timeOfDay;
  List<Reminder> reminders;

  int xpReward;
  int currentStreak;
  int bestStreak;
  bool isActive;
  DateTime createdAt;
  DateTime updatedAt;
  String? groupId;
  DateTime? startDate;
  DateTime? endDate;
  String? challengeId;
  String? questId;

  TimerSetting? timerSetting;
  String? fullDescription;
  String? halfDescription;
  String? basicDescription;
  String? targetValue;

  Habit({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.subHabits = const [],
    this.completedSubHabits = const [],
    this.iconName = 'fitness_center',
    this.iconColor = 0xFF4A90E2,
    this.backgroundColor = 0xFFF5F5F5,
    this.frequencyType = 'daily',
    this.dailyIntervalDays,
    this.weeklyDays,
    this.weeklyIntervalWeeks = 1,
    this.monthlyDays,
    this.monthlyIntervalMonths = 1,
    this.timeOfDay = 'morning',
    this.reminders = const [],
    this.xpReward = 10,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.groupId,
    this.startDate,
    this.endDate,
    this.challengeId,
    this.questId,
    this.timerSetting,
    this.fullDescription,
    this.halfDescription,
    this.basicDescription,
    this.targetValue,
  });

  // بررسی اینکه عادت هنوز منقضی نشده است
  bool isNotExpired() {
    // اگر ماموریت است (questId دارد)، تاریخ انقضا ندارد
    if (questId != null) {
      return true; // ماموریت‌ها همیشه فعال هستند تا زمانی که کامل شوند
    }

    // برای چالش‌ها
    if (endDate == null) return true;
    return DateTime.now().isBefore(endDate!);
  }

// lib/features/arena/models/habit_model.dart

  bool shouldShowQuestOnDate(DateTime date) {
    if (questId == null) return shouldDoOnDate(date);

    // ✅ اگر ماموریت است
    if (!isActive) return false;

    // ✅ اگر تاریخ شروع مشخص شده، قبل از آن را نمایش نده
    if (startDate != null) {
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final checkDate = DateTime(date.year, date.month, date.day);
      if (checkDate.isBefore(start)) {
        return false;
      }
    }

    // ✅ برای ماموریت‌ها، هر روز را نمایش بده (تا زمانی که کامل نشده باشد)
    return true;
  }

  // محاسبه روز هفته شمسی
  int _getJalaliWeekday(DateTime date) {
    return date.weekday % 7;
  }

  // بررسی اینکه آیا عادت در تاریخ امروز باید انجام شود
  bool shouldDoToday() {
    return shouldDoOnDate(DateTime.now());
  }

// lib/features/arena/models/habit_model.dart

  bool shouldDoOnDate(DateTime date) {
    if (!isActive) return false;

    // ✅ چک کردن تاریخ شروع
    if (startDate != null) {
      final start = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final checkDate = DateTime(date.year, date.month, date.day);
      if (checkDate.isBefore(start)) {
        return false;
      }
    }

    // ✅ چک کردن تاریخ پایان - برای چالش‌ها
    if (challengeId != null && endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      final checkDate = DateTime(date.year, date.month, date.day);
      if (checkDate.isAfter(end)) {
        return false;
      }
    }

    // ✅ برای ماموریت‌ها (questId دارد)
    if (questId != null) {
      // ✅ اگر تاریخ شروع مشخص شده، قبل از آن را نمایش نده
      if (startDate != null) {
        final start =
            DateTime(startDate!.year, startDate!.month, startDate!.day);
        final checkDate = DateTime(date.year, date.month, date.day);
        if (checkDate.isBefore(start)) {
          return false;
        }
      }
      // ✅ ماموریت‌ها تاریخ پایان ندارند (همیشه فعال هستند تا زمانی که کامل شوند)
      return true;
    }

    // ✅ ادامه کد برای عادت‌های معمولی
    switch (frequencyType) {
      case 'daily':
        if (dailyIntervalDays != null && dailyIntervalDays!.isNotEmpty) {
          final start = startDate ?? createdAt;
          final dayDiff = date.difference(start).inDays;
          return dayDiff % dailyIntervalDays!.first == 0;
        }
        return true;

      case 'weekly':
        if (weeklyDays == null || weeklyDays!.isEmpty) return false;

        final dateWeekday = _getJalaliWeekday(date);
        final isCorrectDay = weeklyDays!.contains(dateWeekday);
        if (!isCorrectDay) return false;

        if (weeklyIntervalWeeks != null && weeklyIntervalWeeks! > 1) {
          final start = startDate ?? createdAt;
          final weeksSinceStart = date.difference(start).inDays ~/ 7;
          return weeksSinceStart % weeklyIntervalWeeks! == 0;
        }
        return true;

      case 'monthly':
        if (monthlyDays == null || monthlyDays!.isEmpty) return false;

        final jalaliDate = Jalali.fromDateTime(date);
        final todayDay = jalaliDate.day;

        final isCorrectDay = monthlyDays!.contains(todayDay);
        if (!isCorrectDay) return false;

        if (monthlyIntervalMonths != null && monthlyIntervalMonths! > 1) {
          final jalaliStart = Jalali.fromDateTime(startDate ?? createdAt);
          final monthsSinceStart = (jalaliDate.year - jalaliStart.year) * 12 +
              (jalaliDate.month - jalaliStart.month);
          return monthsSinceStart % monthlyIntervalMonths! == 0;
        }
        return true;

      default:
        return true;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'sub_habits': subHabits,
      'completed_sub_habits': completedSubHabits,
      'icon_name': iconName,
      'icon_color': iconColor,
      'background_color': backgroundColor,
      'frequency_type': frequencyType,
      'daily_interval_days': dailyIntervalDays?.first,
      'weekly_days': weeklyDays,
      'weekly_interval_weeks': weeklyIntervalWeeks,
      'monthly_days': monthlyDays,
      'monthly_interval_months': monthlyIntervalMonths,
      'time_of_day': timeOfDay,
      'reminders': reminders.map((r) => jsonEncode(r.toMap())).toList(),
      'xp_reward': xpReward,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'group_id': groupId,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'challenge_id': challengeId,
      'quest_id': questId,
      // ✅ اضافه کردن timer_setting
      'timer_setting': timerSetting?.toMap(),
      'target_value': targetValue,
      'full_description': fullDescription ?? 'انجام کامل عادت',
      'half_description': halfDescription ?? 'انجام نیمی از عادت',
      'basic_description': basicDescription ?? 'انجام حداقل عادت',
    };
  }

  factory Habit.fromMap(String id, Map<String, dynamic> map) {
    // ✅ خواندن timer_setting
    TimerSetting? timerSetting;
    if (map['timer_setting'] != null) {
      try {
        timerSetting = TimerSetting.fromMap(map['timer_setting']);
      } catch (e) {
        print('⚠️ Error parsing timer_setting: $e');
      }
    }

    DateTime parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        print('⚠️ Error parsing date: $dateStr');
        return DateTime.now();
      }
    }

    return Habit(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subHabits:
          map['subHabits'] != null ? List<String>.from(map['subHabits']) : [],
      completedSubHabits: map['completedSubHabits'] != null
          ? List<String>.from(map['completedSubHabits'])
          : [],
      iconName: map['iconName'] ?? 'fitness_center',
      iconColor: map['iconColor'] ?? 0xFF4A90E2,
      backgroundColor: map['backgroundColor'] ?? 0xFFF5F5F5,
      frequencyType: map['frequencyType'] ?? 'daily',
      dailyIntervalDays:
          map['dailyIntervalDays'] != null ? [map['dailyIntervalDays']] : null,
      weeklyDays:
          map['weeklyDays'] != null ? List<int>.from(map['weeklyDays']) : null,
      weeklyIntervalWeeks: map['weeklyIntervalWeeks'] ?? 1,
      monthlyDays: map['monthlyDays'] != null
          ? List<int>.from(map['monthlyDays'])
          : null,
      monthlyIntervalMonths: map['monthlyIntervalMonths'] ?? 1,
      timeOfDay: map['timeOfDay'] ?? 'morning',
      reminders: (map['reminders'] as List?)?.map((r) {
            if (r is String) {
              try {
                return Reminder.fromMap(jsonDecode(r) as Map<String, dynamic>);
              } catch (e) {
                return Reminder(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  hour: 8,
                  minute: 0,
                );
              }
            }
            return Reminder(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              hour: 8,
              minute: 0,
            );
          }).toList() ??
          [],
      xpReward: map['xpReward'] ?? 10,
      currentStreak: map['currentStreak'] ?? 0,
      bestStreak: map['bestStreak'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
      groupId: map['groupId'],
      startDate: map['startDate'] != null ? parseDate(map['startDate']) : null,
      endDate: map['endDate'] != null ? parseDate(map['endDate']) : null,
      challengeId: map['challengeId'],
      questId: map['questId'],
      timerSetting: timerSetting,
      targetValue: map['targetValue'] ?? map['target_value'],
      fullDescription: map['fullDescription'] ?? map['full_description'],
      halfDescription: map['halfDescription'] ?? map['half_description'],
      basicDescription: map['basicDescription'] ?? map['basic_description'],
    );
  }

  int get completedCount => completedSubHabits.length;

  double get progressPercent =>
      subHabits.isEmpty ? 0 : completedCount / subHabits.length;
}

class Reminder {
  String id;
  int hour;
  int minute;
  bool isEnabled;

  Reminder({
    required this.id,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'hour': hour, 'minute': minute, 'isEnabled': isEnabled};
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      hour: map['hour'] ?? 0,
      minute: map['minute'] ?? 0,
      isEnabled: map['isEnabled'] ?? true,
    );
  }

  String getTimeString() {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
