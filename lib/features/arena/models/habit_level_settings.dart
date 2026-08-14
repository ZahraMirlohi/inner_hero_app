// lib/features/arena/models/habit_level_settings.dart

import 'habit_completion.dart';

class HabitLevelSettings {
  final String habitId;
  final String userId;
  final String fullDescription;
  final String halfDescription;
  final String basicDescription;
  final String? fullValue;
  final String? halfValue;
  final String? basicValue;

  HabitLevelSettings({
    required this.habitId,
    required this.userId,
    this.fullDescription = 'انجام کامل عادت',
    this.halfDescription = 'انجام نیمی از عادت',
    this.basicDescription = 'انجام حداقل عادت',
    this.fullValue,
    this.halfValue,
    this.basicValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'habit_id': habitId,
      'user_id': userId,
      'full_description': fullDescription,
      'half_description': halfDescription,
      'basic_description': basicDescription,
      'full_value': fullValue,
      'half_value': halfValue,
      'basic_value': basicValue,
    };
  }

  factory HabitLevelSettings.fromMap(Map<String, dynamic> map) {
    return HabitLevelSettings(
      habitId: map['habit_id'] ?? '',
      userId: map['user_id'] ?? '',
      fullDescription: map['full_description'] ?? 'انجام کامل عادت',
      halfDescription: map['half_description'] ?? 'انجام نیمی از عادت',
      basicDescription: map['basic_description'] ?? 'انجام حداقل عادت',
      fullValue: map['full_value'],
      halfValue: map['half_value'],
      basicValue: map['basic_value'],
    );
  }

  String getDescriptionForLevel(CompletionLevel level) {
    switch (level) {
      case CompletionLevel.full:
        return fullDescription;
      case CompletionLevel.half:
        return halfDescription;
      case CompletionLevel.basic:
        return basicDescription;
    }
  }

  String? getValueForLevel(CompletionLevel level) {
    switch (level) {
      case CompletionLevel.full:
        return fullValue;
      case CompletionLevel.half:
        return halfValue;
      case CompletionLevel.basic:
        return basicValue;
    }
  }
}
