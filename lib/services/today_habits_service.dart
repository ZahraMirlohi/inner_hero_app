// lib/services/today_habits_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../features/arena/models/habit_model.dart';
import '../features/arena/models/task_model.dart';
import '../features/chat/models/today_habits_list.dart';

class TodayHabitsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<TodayHabitsList?> getUserTodayHabits(String userId) async {
    try {
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T').first;

      // 1. دریافت عادت‌های کاربر
      final habitsResponse = await _client
          .from('habits')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

      final habits = habitsResponse
          .map((h) => Habit.fromMap(h['id'], _convertKeys(h)))
          .toList();

      // 2. دریافت تکمیل‌های امروز
      final completionsResponse = await _client
          .from('habit_completions')
          .select('habit_id')
          .eq('user_id', userId)
          .eq('date', todayStr);

      final completedHabitIds = completionsResponse
          .map((c) => c['habit_id'] as String)
          .toSet();

      // 3. دریافت تسک‌های امروز
      final tasksResponse = await _client
          .from('tasks')
          .select()
          .eq('user_id', userId);

      final tasks = tasksResponse
          .map((t) => Task.fromMap(t['id'], _convertKeys(t)))
          .toList();

      // ============================================================
      // ✅ اصلاح: دریافت چالش‌های فعال کاربر (بدون join)
      // ============================================================
      List<TodayChallengeItem> challengeItems = [];

      try {
        // 4. دریافت user_challenges
        final userChallengesResponse = await _client
            .from('user_challenges')
            .select('*')
            .eq('user_id', userId)
            .eq('is_active', true);

        // 5. برای هر user_challenge، اطلاعات چالش رو جداگانه بگیر
        for (var uc in userChallengesResponse) {
          final challengeId = uc['challenge_id'];
          if (challengeId == null) continue;

          final challengeResponse = await _client
              .from('challenges')
              .select('title, challenge_duration')
              .eq('id', challengeId)
              .maybeSingle();

          if (challengeResponse != null) {
            challengeItems.add(
              TodayChallengeItem(
                id: challengeId,
                title: challengeResponse['title'] ?? 'چالش',
                progress: uc['progress'] ?? 0,
                totalDays: challengeResponse['challenge_duration'] ?? 7,
                isCompleted: uc['is_completed'] ?? false,
              ),
            );
          }
        }
      } catch (e) {
        print('⚠️ Error loading challenges: $e');
        // ادامه بده، خطا نادیده گرفته بشه
      }

      // ============================================================
      // ✅ اصلاح: دریافت ماموریت‌های فعال کاربر (بدون join)
      // ============================================================
      List<TodayQuestItem> questItems = [];

      try {
        // 6. دریافت user_quests
        final userQuestsResponse = await _client
            .from('user_quests')
            .select('*')
            .eq('user_id', userId)
            .eq('is_active', true);

        // 7. برای هر user_quest، اطلاعات ماموریت رو جداگانه بگیر
        for (var uq in userQuestsResponse) {
          final questId = uq['quest_id'];
          if (questId == null) continue;

          final questResponse = await _client
              .from('quests')
              .select('title, target_count')
              .eq('id', questId)
              .maybeSingle();

          if (questResponse != null) {
            questItems.add(
              TodayQuestItem(
                id: questId,
                title: questResponse['title'] ?? 'ماموریت',
                progress: uq['progress'] ?? 0,
                targetCount: questResponse['target_count'] ?? 7,
                isCompleted: uq['is_completed'] ?? false,
              ),
            );
          }
        }
      } catch (e) {
        print('⚠️ Error loading quests: $e');
        // ادامه بده، خطا نادیده گرفته بشه
      }

      // ============================================================
      // 8. ساخت لیست عادت‌های امروز
      // ============================================================
      List<TodayHabitItem> habitItems = [];
      for (var habit in habits) {
        if (!habit.shouldDoOnDate(today)) continue;

        final isCompleted = completedHabitIds.contains(habit.id);
        habitItems.add(
          TodayHabitItem(
            id: habit.id,
            title: habit.title,
            iconName: habit.iconName,
            iconColor: habit.iconColor,
            isCompleted: isCompleted,
            challengeId: habit.challengeId,
            questId: habit.questId,
          ),
        );
      }

      // 9. ساخت لیست تسک‌های امروز
      List<TodayTaskItem> taskItems = [];
      for (var task in tasks) {
        if (task.dueDate == null) continue;
        if (!task.isForDate(today)) continue;

        taskItems.add(
          TodayTaskItem(
            id: task.id,
            title: task.title,
            isCompleted: task.isCompleted,
          ),
        );
      }

      // 10. محاسبه آمار
      int totalItems =
          habitItems.length +
          taskItems.length +
          challengeItems.length +
          questItems.length;
      int completedItems =
          habitItems.where((h) => h.isCompleted).length +
          taskItems.where((t) => t.isCompleted).length +
          challengeItems.where((c) => c.isCompleted).length +
          questItems.where((q) => q.isCompleted).length;

      // 11. دریافت نام کاربر
      final profile = await _client
          .from('profiles')
          .select('name')
          .eq('user_id', userId)
          .maybeSingle();

      return TodayHabitsList(
        userId: userId,
        userName: profile?['name'] ?? 'کاربر',
        date: today,
        habits: habitItems,
        tasks: taskItems,
        challenges: challengeItems,
        quests: questItems,
        totalItems: totalItems,
        completedItems: completedItems,
      );
    } catch (e) {
      print('❌ Error getting today habits: $e');
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
        case 'sub_tasks':
          newKey = 'subTasks';
          break;
        case 'completed_sub_tasks':
          newKey = 'completedSubTasks';
          break;
        case 'due_date':
          newKey = 'dueDate';
          break;
        case 'is_completed':
          newKey = 'isCompleted';
          break;
        case 'xp_reward':
          newKey = 'xpReward';
          break;
        default:
          newKey = key;
      }
      return MapEntry(newKey, value);
    });
  }
}
