// lib/features/arena/models/habit_completion.dart

import 'package:flutter/material.dart';

enum CompletionLevel {
  full, // کامل 🌟
  half, // نیمه ⭐
  basic, // پایه ✨
}

extension CompletionLevelExtension on CompletionLevel {
  String get displayName {
    switch (this) {
      case CompletionLevel.full:
        return 'کامل';
      case CompletionLevel.half:
        return 'نیمه';
      case CompletionLevel.basic:
        return 'پایه';
    }
  }

  String get emoji {
    switch (this) {
      case CompletionLevel.full:
        return '🌟';
      case CompletionLevel.half:
        return '⭐';
      case CompletionLevel.basic:
        return '✨';
    }
  }

  int get xpMultiplier {
    switch (this) {
      case CompletionLevel.full:
        return 100; // ۱۰۰٪ XP
      case CompletionLevel.half:
        return 50; // ۵۰٪ XP
      case CompletionLevel.basic:
        return 25; // ۲۵٪ XP
    }
  }

  String get description {
    switch (this) {
      case CompletionLevel.full:
        return 'عادت را کامل انجام دادم';
      case CompletionLevel.half:
        return 'نیمی از عادت را انجام دادم';
      case CompletionLevel.basic:
        return 'حداقل مقدار را انجام دادم';
    }
  }

  Color get color {
    switch (this) {
      case CompletionLevel.full:
        return const Color(0xFF2ECC71); // سبز
      case CompletionLevel.half:
        return const Color(0xFFFFA500); // نارنجی
      case CompletionLevel.basic:
        return const Color(0xFF3498DB); // آبی
    }
  }

  // تبدیل از String به Enum
  static CompletionLevel fromString(String value) {
    switch (value) {
      case 'full':
        return CompletionLevel.full;
      case 'half':
        return CompletionLevel.half;
      case 'basic':
        return CompletionLevel.basic;
      default:
        return CompletionLevel.full;
    }
  }
}

class HabitCompletion {
  final String id;
  final String habitId;
  final String userId;
  final DateTime date;
  final CompletionLevel level;
  final DateTime completedAt;
  final DateTime createdAt;

  HabitCompletion({
    required this.id,
    required this.habitId,
    required this.userId,
    required this.date,
    required this.level,
    required this.completedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'user_id': userId,
      'date': date.toIso8601String().split('T').first,
      'completion_level': level.toString().split('.').last,
      'completed_at': completedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HabitCompletion.fromMap(Map<String, dynamic> map) {
    return HabitCompletion(
      id: map['id'] ?? '',
      habitId: map['habit_id'] ?? '',
      userId: map['user_id'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      level: CompletionLevelExtension.fromString(
          map['completion_level'] ?? 'full'),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'])
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}
