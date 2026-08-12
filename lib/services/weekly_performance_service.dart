// lib/services/weekly_performance_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../features/arena/models/habit_model.dart';
import '../features/chat/models/weekly_habit_performance.dart';

class WeeklyPerformanceService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<WeeklyHabitPerformance?> getUserWeeklyPerformance(
    String userId,
  ) async {
    try {
      // 1. دریافت عادت‌های کاربر
      final habitsResponse = await _client
          .from('habits')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

      if (habitsResponse.isEmpty) return null;

      final habits = habitsResponse
          .map((h) => Habit.fromMap(h['id'], _convertKeys(h)))
          .toList();

      // 2. محاسبه شروع و پایان هفته (شمسی)
      final now = DateTime.now();
      final jalaliNow = Jalali.fromDateTime(now);
      final daysToSubtract = jalaliNow.weekDay - 1;
      final weekStart = now.subtract(Duration(days: daysToSubtract));
      final weekEnd = weekStart.add(const Duration(days: 6));

      // 3. دریافت تکمیل‌های هفته
      final weekDates = List.generate(7, (i) {
        final date = weekStart.add(Duration(days: i));
        return date.toIso8601String().split('T').first;
      });

      final habitIds = habits.map((h) => h.id).toList();

      final completionsResponse = await _client
          .from('habit_completions')
          .select('habit_id, date')
          .eq('user_id', userId)
          .inFilter('habit_id', habitIds)
          .inFilter('date', weekDates);

      // 4. ساخت Set از ترکیب habit_id|date برای جستجوی سریع
      final completionSet = completionsResponse
          .map((c) => '${c['habit_id']}|${c['date']}')
          .toSet();

      // 5. ساخت لیست عملکرد هر عادت
      final performanceItems = habits.map((habit) {
        final weekStatus = List.generate(7, (index) {
          final date = weekStart.add(Duration(days: index));
          final dateStr = date.toIso8601String().split('T').first;
          final key = '${habit.id}|$dateStr';
          return completionSet.contains(key);
        });

        return HabitPerformanceItem(
          habitId: habit.id,
          habitTitle: habit.title,
          iconName: habit.iconName,
          iconColor: habit.iconColor,
          weekStatus: weekStatus,
        );
      }).toList();

      // 6. محاسبه آمار
      int totalHabits = 0;
      int completedHabits = 0;

      for (var habit in habits) {
        for (int i = 0; i < 7; i++) {
          final date = weekStart.add(Duration(days: i));
          if (habit.shouldDoOnDate(date)) {
            totalHabits++;
            final dateStr = date.toIso8601String().split('T').first;
            final key = '${habit.id}|$dateStr';
            if (completionSet.contains(key)) {
              completedHabits++;
            }
          }
        }
      }

      final successRate = totalHabits > 0 ? completedHabits / totalHabits : 0.0;

      // 7. دریافت نام کاربر
      final profile = await _client
          .from('profiles')
          .select('name')
          .eq('user_id', userId)
          .maybeSingle();

      return WeeklyHabitPerformance(
        userId: userId,
        userName: profile?['name'] ?? 'کاربر',
        habits: performanceItems,
        weekStart: weekStart,
        weekEnd: weekEnd,
        totalHabits: totalHabits,
        completedHabits: completedHabits,
        successRate: successRate,
      );
    } catch (e) {
      print('❌ Error getting weekly performance: $e');
      return null;
    }
  }

  Map<String, dynamic> _convertKeys(Map<String, dynamic> data) {
    return data.map((key, value) {
      String newKey = key;
      switch (key) {
        case 'user_id':
          newKey = 'userId';
          break;
        case 'sub_habits':
          newKey = 'subHabits';
          break;
        case 'completed_sub_habits':
          newKey = 'completedSubHabits';
          break;
        case 'icon_name':
          newKey = 'iconName';
          break;
        case 'icon_color':
          newKey = 'iconColor';
          break;
        case 'background_color':
          newKey = 'backgroundColor';
          break;
        case 'frequency_type':
          newKey = 'frequencyType';
          break;
        case 'daily_interval_days':
          newKey = 'dailyIntervalDays';
          break;
        case 'weekly_days':
          newKey = 'weeklyDays';
          break;
        case 'weekly_interval_weeks':
          newKey = 'weeklyIntervalWeeks';
          break;
        case 'monthly_days':
          newKey = 'monthlyDays';
          break;
        case 'monthly_interval_months':
          newKey = 'monthlyIntervalMonths';
          break;
        case 'time_of_day':
          newKey = 'timeOfDay';
          break;
        case 'xp_reward':
          newKey = 'xpReward';
          break;
        case 'current_streak':
          newKey = 'currentStreak';
          break;
        case 'best_streak':
          newKey = 'bestStreak';
          break;
        case 'is_active':
          newKey = 'isActive';
          break;
        case 'group_id':
          newKey = 'groupId';
          break;
        case 'start_date':
          newKey = 'startDate';
          break;
        case 'end_date':
          newKey = 'endDate';
          break;
        case 'challenge_id':
          newKey = 'challengeId';
          break;
        case 'created_at':
          newKey = 'createdAt';
          break;
        case 'updated_at':
          newKey = 'updatedAt';
          break;
        default:
          newKey = key;
      }
      return MapEntry(newKey, value);
    });
  }
}
