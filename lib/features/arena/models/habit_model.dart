import 'dart:convert';
import 'package:shamsi_date/shamsi_date.dart';

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
  });

  // بررسی اینکه عادت هنوز منقضی نشده است
  bool isNotExpired() {
    if (endDate == null) return true;
    return DateTime.now().isBefore(endDate!);
  }

  // محاسبه روز هفته شمسی
  int _getJalaliWeekday(DateTime date) {
    return date.weekday % 7;
  }

  // بررسی اینکه آیا عادت در تاریخ امروز باید انجام شود
  bool shouldDoToday() {
    return shouldDoOnDate(DateTime.now());
  }

  // بررسی اینکه آیا عادت در تاریخ مشخص شده باید انجام شود
  bool shouldDoOnDate(DateTime date) {
    if (!isActive) return false;

    // چک کردن تاریخ شروع
    if (startDate != null && date.isBefore(startDate!)) {
      return false;
    }

    // چک کردن تاریخ پایان (برای عادت‌های چالش)
    if (endDate != null && date.isAfter(endDate!)) {
      return false; // اگر تاریخ انتخاب شده بعد از تاریخ پایان باشد، عادت را نشان نده
    }

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
          final monthsSinceStart =
              (jalaliDate.year - jalaliStart.year) * 12 +
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
      'userId': userId,
      'title': title,
      'description': description,
      'subHabits': subHabits,
      'completedSubHabits': completedSubHabits,
      'iconName': iconName,
      'iconColor': iconColor,
      'backgroundColor': backgroundColor,
      'frequencyType': frequencyType,
      'dailyIntervalDays': dailyIntervalDays?.first,
      'weeklyDays': weeklyDays,
      'weeklyIntervalWeeks': weeklyIntervalWeeks,
      'monthlyDays': monthlyDays,
      'monthlyIntervalMonths': monthlyIntervalMonths,
      'timeOfDay': timeOfDay,
      'reminders': reminders.map((r) => jsonEncode(r.toMap())).toList(),
      'xpReward': xpReward,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'groupId': groupId,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'challengeId': challengeId,
    };
  }

  factory Habit.fromMap(String id, Map<String, dynamic> map) {
    return Habit(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subHabits: map['subHabits'] != null
          ? List<String>.from(map['subHabits'])
          : [],
      completedSubHabits: map['completedSubHabits'] != null
          ? List<String>.from(map['completedSubHabits'])
          : [],
      iconName: map['iconName'] ?? 'fitness_center',
      iconColor: map['iconColor'] ?? 0xFF4A90E2,
      backgroundColor: map['backgroundColor'] ?? 0xFFF5F5F5,
      frequencyType: map['frequencyType'] ?? 'daily',
      dailyIntervalDays: map['dailyIntervalDays'] != null
          ? [map['dailyIntervalDays']]
          : null,
      weeklyDays: map['weeklyDays'] != null
          ? List<int>.from(map['weeklyDays'])
          : null,
      weeklyIntervalWeeks: map['weeklyIntervalWeeks'] ?? 1,
      monthlyDays: map['monthlyDays'] != null
          ? List<int>.from(map['monthlyDays'])
          : null,
      monthlyIntervalMonths: map['monthlyIntervalMonths'] ?? 1,
      timeOfDay: map['timeOfDay'] ?? 'morning',
      reminders:
          (map['reminders'] as List?)
              ?.map(
                (r) => Reminder.fromMap(jsonDecode(r) as Map<String, dynamic>),
              )
              .toList() ??
          [],
      xpReward: map['xpReward'] ?? 10,
      currentStreak: map['currentStreak'] ?? 0,
      bestStreak: map['bestStreak'] ?? 0,
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      groupId: map['groupId'],
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'])
          : null,
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      challengeId: map['challengeId'],
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
